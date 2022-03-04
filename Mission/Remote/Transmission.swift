//
//  Transmission.swift
//  Mission
//
//  Created by Joe Diragi on 2/24/22.
//

import Foundation

let TOKEN_HEAD = "X-Transmission-Session-Id"
public typealias TransmissionConfig = URLComponents
var lastSessionToken: String?
var url: TransmissionConfig?

struct TransmissionRemoveArgs: Codable {
    var ids: [Int]
    var deleteLocalData: Bool
    
    enum CodingKeys: String, CodingKey {
        case ids
        case deleteLocalData = "delete-local-data"
    }
}

public enum TorrentStatus {
    case stopped
    case checkingWait
    case checking
    case downloadWait
    case downloading
    case seedWait
    case seeding
}

struct TransmissionRemoveRequest: Codable {
    var method: String
    var arguments: TransmissionRemoveArgs
}

struct TransmissionRequest: Codable {
    let method: String
    let arguments: [String: String]
}

struct TransmissionListRequest: Codable {
    let method: String
    let arguments: [String: [String]]
}

struct TransmissionListResponse: Codable {
    let arguments: [String: [Torrent]]
}

public struct TransmissionAuth {
    let username: String
    let password: String
}

public struct Torrent: Codable, Hashable {
    let id: Int
    let name: String
    let totalSize: Int
    let percentDone: Double
    let status: Int
    let sendingToUs: Int
    let peersConnected: Int
}

public enum TransmissionResponse {
    case success
    case forbidden
    case configError
    case failed
}

/// Makes a request to the server for a list of the currently running torrents
///
/// ```
/// getTorrents(config: config, auth: auth, onReceived: { torrents in
///         // Receive the [Torrent] array and do something with it
/// }
/// ```
/// - Parameter config: A `TransmissionConfig` with the servers address and port
/// - Parameter auth: A `TransmissionAuth` with authorization parameters ie. username and password
/// - Parameter onReceived: An escaping function that receives a list of `Torrent`s
public func getTorrents(config: TransmissionConfig, auth: TransmissionAuth, onReceived: @escaping ([Torrent]?) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    let listReq = TransmissionListRequest(
        method: "torrent-get",
        arguments: [
            "fields": [ "id", "name", "totalSize", "percentDone", "status", "sendingToUs", "peersConnected" ]
        ]
    )
    
    // Create request and authorization headers
    var req = URLRequest(url: url!.url!)
    let loginString = String(format: "%@:%@", auth.username, auth.password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    req.httpMethod = "POST"
    req.httpBody = try? JSONEncoder().encode(listReq)
    req.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(lastSessionToken, forHTTPHeaderField: TOKEN_HEAD)
    
    // Send the request
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onReceived(nil)
        }
        let httpResp = resp as? HTTPURLResponse
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the session token and try again
            authorize(httpResp: httpResp)
            getTorrents(config: config, auth: auth, onReceived: onReceived)
            return
        case 200?:            
            let response = try? JSONDecoder().decode(TransmissionListResponse.self, from: data!)
            let torrents = response?.arguments["torrents"]
            
            return onReceived(torrents)
        default:
            return
        }
    }
    task.resume()
}

/// Makes a request to the server containing either a base64 representation of a .torrent file or a magnet link
///
/// ```
/// addTorrent(fileURL: `magnet or base64 file`, auth: `TransmissionAuth`, file: `True for file or False for magnet`, config: `TransmissionConfig`, onAdd: { response in
///     // Receive the server response and do something
/// })
/// ```
/// - Parameter fileUrl: Either a magnet link or base64 encoded file
/// - Parameter auth: A `TransmissionAuth` containing username and password for the server
/// - Parameter file: A boolean value; true if `fileUrl` is a base64 encoded file and false if `fileUrl` is a magnet link
/// - Parameter config: A `TransmissionConfig` containing the server's address and port
/// - Parameter onAdd: An escaping function that receives the servers response code represented as a `TransmissionResponse`
public func addTorrent(fileUrl: String, saveLocation: String, auth: TransmissionAuth, file: Bool, config: TransmissionConfig, onAdd: @escaping (TransmissionResponse) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    // Create the torrent body based on the value of `fileUrl` and `file`
    var torrentBody: TransmissionRequest? = nil
    
    if (file) {
        torrentBody = TransmissionRequest (
            method: "torrent-add",
            arguments: ["metainfo": fileUrl, "download-dir": saveLocation]
        )
    } else {
        torrentBody = TransmissionRequest(
            method: "torrent-add",
            arguments: ["filename": fileUrl, "download-dir": saveLocation]
        )
    }
    
    // Create the request with auth values
    var req: URLRequest = makeRequest(setTorrentBody: torrentBody!)
    let loginString = String(format: "%@:%@", auth.username, auth.password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    req.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    
    // Send request to server
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onAdd(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            addTorrent(fileUrl: fileUrl, saveLocation: saveLocation, auth: auth, file: file, config: config, onAdd: onAdd)
            return
        case 401?:
            return onAdd(TransmissionResponse.forbidden)
        case 200?:
            return onAdd(TransmissionResponse.success)
        default:
            return onAdd(TransmissionResponse.failed)
        }
    }
    task.resume()
}

/// Deletes a torrent from the queue
///
/// ```
/// // Delete a torrent from the queue along with it's data on the server
/// deleteTorrent(torrent: torrentToDelete, erase: true, onDel: { response in
///     // Receive the response and do something with it
/// })
/// ```
///
/// - Parameter torrent: The `Torrent` to be deleted
/// - Parameter erase: Whether or not to delete the downloaded data from the server along with the transfer in Transmssion
/// - Parameter config: A `TransmissionConfig` containing the server's address and port
/// - Parameter auth: A `TransmissionAuth` containing username and password for the server
/// - Parameter onDel: An escaping function that receives the server's response code as a `TransmissionResponse`
public func deleteTorrent(torrent: Torrent, erase: Bool, config: TransmissionConfig, auth: TransmissionAuth, onDel: @escaping (TransmissionResponse) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    let torrentBody = TransmissionRemoveRequest(
        method: "torrent-remove",
        arguments: TransmissionRemoveArgs(
            ids: [torrent.id],
            deleteLocalData: erase
        )
    )
    
    // Create the request with auth values
    var req = URLRequest(url: url!.url!)
    req.httpMethod = "POST"
    req.httpBody = try? JSONEncoder().encode(torrentBody)
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(lastSessionToken, forHTTPHeaderField: TOKEN_HEAD)
    let loginString = String(format: "%@:%@", auth.username, auth.password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    req.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    
    // Send request to server
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onDel(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            deleteTorrent(torrent: torrent, erase: erase, config: config, auth: auth, onDel: onDel)
            return
        case 401?:
            return onDel(TransmissionResponse.forbidden)
        case 200?:
            return onDel(TransmissionResponse.success)
        default:
            return onDel(TransmissionResponse.failed)
        }
    }
    task.resume()
}

public func authorize(httpResp: HTTPURLResponse?) {
    let mixedHeaders = httpResp?.allHeaderFields as! [String: Any]
    lastSessionToken = mixedHeaders[TOKEN_HEAD] as? String
}

private func makeRequest(setTorrentBody: TransmissionRequest) -> URLRequest {
    var req = URLRequest(url: url!.url!)
    req.httpMethod = "POST"
    req.httpBody = try? JSONEncoder().encode(setTorrentBody)
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(lastSessionToken, forHTTPHeaderField: TOKEN_HEAD)
    
    return req
}
