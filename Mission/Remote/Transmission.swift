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

/// The rpc-spec represents the status of a torrent using an integer value. We use
/// this enum to improve readability and make things a little easier for poor ol' Joe
public enum TorrentStatus: Int {
    case stopped = 0
    case checkingWait = 1
    case checking = 2
    case downloadWait = 3
    case downloading = 4
    case seedWait = 5
    case seeding = 6
}

public enum TorrentPriority: String {
    case high = "priority-high"
    case normal = "priority-normal"
    case low = "priority-low"
}

/// The remove body is weird and the delete-local-data argument has hyphens in it
/// so we need **another** dictionary with `CodingKeys` to make it work
struct TransmissionRemoveArgs: Codable {
    var ids: [Int]
    var deleteLocalData: Bool
    
    enum CodingKeys: String, CodingKey {
        case ids
        case deleteLocalData = "delete-local-data"
    }
}

struct TransmissionRemoveRequest: Codable {
    var method: String
    var arguments: TransmissionRemoveArgs
}

/// A standard request containing a list of string-only arguments.
struct TransmissionRequest: Codable {
    let method: String
    let arguments: [String: String]
}

/// A request sent to the server asking for a list of torrents and certain properties
/// - Parameter method: Should always be "torrent-get"
/// - Parameter arguments: Takes a list of properties we are interested in called "fields". See RPC-Spec
struct TransmissionListRequest: Codable {
    let method: String
    let arguments: [String: [String]]
}

/// A response from the server sent after a torrent-get request
/// - Parameter arguments: A list containing the torrents we asked for and their properties
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
public func getTorrents(config: TransmissionConfig, auth: TransmissionAuth, onReceived: @escaping ([Torrent]?, String?) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    let requestBody = TransmissionListRequest(
        method: "torrent-get",
        arguments: [
            "fields": [ "id", "name", "totalSize", "percentDone", "status", "sendingToUs", "peersConnected" ]
        ]
    )
    
    // Create the request with auth values
    let req = makeRequest(requestBody: requestBody, auth: auth)
    
    // Send the request
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onReceived(nil, error.debugDescription)
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
            
            return onReceived(torrents, nil)
        default:
            return onReceived(nil, String(decoding: data!, as: UTF8.self))
        }
    }
    task.resume()
}

struct TorrentAdded: Codable {
    var hashString: String
    var id: Int
    var name: String
}

struct TorrentAddResponse: Codable {
    var arguments: [String: TorrentAdded]
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
public func addTorrent(fileUrl: String, saveLocation: String, auth: TransmissionAuth, file: Bool, config: TransmissionConfig, onAdd: @escaping ((response: TransmissionResponse, transferId: Int)) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    // Create the torrent body based on the value of `fileUrl` and `file`
    var requestBody: TransmissionRequest? = nil
    
    if (file) {
        requestBody = TransmissionRequest (
            method: "torrent-add",
            arguments: ["metainfo": fileUrl, "download-dir": saveLocation]
        )
    } else {
        requestBody = TransmissionRequest(
            method: "torrent-add",
            arguments: ["filename": fileUrl, "download-dir": saveLocation]
        )
    }
    
    // Create the request with auth values
    let req: URLRequest = makeRequest(requestBody: requestBody!, auth: auth)
    
    // Send request to server
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onAdd((TransmissionResponse.configError, 0))
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            addTorrent(fileUrl: fileUrl, saveLocation: saveLocation, auth: auth, file: file, config: config, onAdd: onAdd)
            return
        case 401?:
            return onAdd((TransmissionResponse.forbidden, 0))
        case 200?:
            let response = try? JSONDecoder().decode(TorrentAddResponse.self, from: data!)
            let transferId: Int = response!.arguments["torrent-added"]!.id
            
            return onAdd((TransmissionResponse.success, transferId))
        default:
            return onAdd((TransmissionResponse.failed, 0))
        }
    }
    task.resume()
}

struct TorrentFilesArgs: Codable {
    var fields: [String]
    var ids: [Int]
}

struct TorrentFilesRequest: Codable {
    var method: String
    var arguments: TorrentFilesArgs
}

struct TorrentFilesResponseFiles: Codable {
    let files: [File]
}

struct TorrentFilesResponseTorrents: Codable {
    let torrents: [TorrentFilesResponseFiles]
}

struct TorrentFilesResponse: Codable {
    let arguments: TorrentFilesResponseTorrents
}

public struct File: Codable {
    var bytesCompleted: Int
    var length: Int
    var name: String
}

public func getTransferFiles(transferId: Int, info: (config: TransmissionConfig, auth: TransmissionAuth), onReceived: @escaping ([File])->(Void)) {
    url = info.config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = info.config.port ?? 443
    
    let request = TorrentFilesRequest(
        method: "torrent-get",
        arguments: TorrentFilesArgs(
            fields: ["files"],
            ids: [transferId]
        )
    )
    
    let req = makeRequest(requestBody: request, auth: info.auth)
    
    // Send the request
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onReceived([])
        }
        let httpResp = resp as? HTTPURLResponse
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the session token and try again
            authorize(httpResp: httpResp)
            getTransferFiles(transferId: transferId, info: info, onReceived: onReceived)
            return
        case 200?:
            print(String(decoding: data!, as: UTF8.self))
            let response = try? JSONDecoder().decode(TorrentFilesResponse.self, from: data!)
            let torrents = response?.arguments.torrents[0].files
            
            return onReceived(torrents!)
        default:
            return
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
    
    let requestBody = TransmissionRemoveRequest(
        method: "torrent-remove",
        arguments: TransmissionRemoveArgs(
            ids: [torrent.id],
            deleteLocalData: erase
        )
    )
    
    // Create the request with auth values
    let req = makeRequest(requestBody: requestBody, auth: auth)
    
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

/* The transmission-session response is a disaster that can only
 handle returning every single property of the session all at once.
 There doesn't appear to be any way to only receive a single or set of
 properties. Luckily we can just add the properties we want to this
 struct, we'll just need to add on any other arguments we might want to
 use in the future. */
struct TransmissionSessionArguments: Codable {
    let downloadDir: String
    
    enum CodingKeys: String, CodingKey {
        case downloadDir = "download-dir"
    }
}

struct TransmissionSessionResponse: Codable {
    let arguments: TransmissionSessionArguments
}

/// Get the server's default download directory
///
/// ```
/// getDefaultDownloadDir(config: config, auth: auth, { response in
///   // Do something with `response`
/// }
/// ```
/// - Parameter config: The server's config
/// - Parameter auth: The username and password for the server
/// - Parameter onResponse: An escaping function that receives the response from the server
public func getDefaultDownloadDir(config: TransmissionConfig, auth: TransmissionAuth, onResponse: @escaping (String) -> Void) {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    let requestBody = TransmissionRequest(
        method: "session-get",
        arguments: [:]
    )
    
    let req = makeRequest(requestBody: requestBody, auth: auth)
    
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onResponse("CONFIG_ERR")
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            getDefaultDownloadDir(config: config, auth: auth, onResponse: onResponse)
            return
        case 401?:
            return onResponse("FORBIDDEN")
        case 200?:
            let response = try? JSONDecoder().decode(TransmissionSessionResponse.self, from: data!)
            let downloadDir = response?.arguments.downloadDir
            return onResponse(downloadDir!)
        default:
            return onResponse("DEFAULT")
        }
    }
    task.resume()
}

/// A torrent action request (see rpc-spec)
///
/// - Parameter method: One of [torrent-start, torrent-stop]. See RPC-Spec
/// - Parameter arguments: A list of torrent ids to perform the action on
struct TorrentActionRequest: Codable {
    let method: String
    let arguments: [String: [Int]]
}

public func playPause(torrent: Torrent, config: TransmissionConfig, auth: TransmissionAuth, onResponse: @escaping (TransmissionResponse) -> Void) {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    // If the torrent already has `stopped` status, start it. Otherwise, stop it.
    let requestBody = torrent.status == TorrentStatus.stopped.rawValue ? TorrentActionRequest(
        method: "torrent-start",
        arguments: ["ids": [torrent.id]]
    ) : TorrentActionRequest(
        method: "torrent-stop",
        arguments: ["ids": [torrent.id]]
    )
    
    let req = makeRequest(requestBody: requestBody, auth: auth)
    
    let task = URLSession.shared.dataTask(with: req) { (data, resp, err) in
        if err != nil {
            onResponse(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            playPause(torrent: torrent, config: config, auth: auth, onResponse: onResponse)
            return
        case 401?:
            return onResponse(TransmissionResponse.forbidden)
        case 200?:
            return onResponse(TransmissionResponse.success)
        default:
            return onResponse(TransmissionResponse.failed)
        }
    }
    task.resume()
}

/// Play/Pause all active transfers
///
/// - Parameter start: True if we are starting all transfers, false if we are stopping them
/// - Parameter info: An info struct generated from makeConfig
/// - Parameter onResponse: Called when the request is complete
public func playPauseAll(start: Bool, info: (config: TransmissionConfig, auth: TransmissionAuth), onResponse: @escaping (TransmissionResponse) -> Void) {
    url = info.config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = info.config.port ?? 443
    
    // If the torrent already has `stopped` status, start it. Otherwise, stop it.
    let requestBody = start ? TransmissionRequest(
        method: "torrent-start",
        arguments: [:]
    ) : TransmissionRequest(
        method: "torrent-stop",
        arguments: [:]
    )
    
    let req = makeRequest(requestBody: requestBody, auth: info.auth)
    
    let task = URLSession.shared.dataTask(with: req) { (data, resp, err) in
        if err != nil {
            onResponse(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            playPauseAll(start: start, info: info, onResponse: onResponse)
            return
        case 401?:
            return onResponse(TransmissionResponse.forbidden)
        case 200?:
            return onResponse(TransmissionResponse.success)
        default:
            return onResponse(TransmissionResponse.failed)
        }
    }
    task.resume()
}

/// Set a transfers priority
///
/// - Parameter torrent: The torrent whose priority we are setting
/// - Parameter priority: One of: `TorrentPriority.high/normal/low`
/// - Parameter onComplete: Called when the servers' response is received with a `TransmissionResponse`
public func setPriority(torrent: Torrent, priority: TorrentPriority, info: (config: TransmissionConfig, auth: TransmissionAuth), onComplete: @escaping (TransmissionResponse) -> Void) {
    url = info.config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = info.config.port ?? 443
    
    let requestBody = TorrentActionRequest(
        method: "torrent-set",
        arguments: [
            "ids": [torrent.id],
            priority.rawValue: []
        ]
    )
    
    let req = makeRequest(requestBody: requestBody, auth: info.auth)
    
    let task = URLSession.shared.dataTask(with: req) { (data, resp, err) in
        if err != nil {
            onComplete(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            setPriority(torrent: torrent, priority: priority, info: info, onComplete: onComplete)
            return
        case 401?:
            return onComplete(TransmissionResponse.forbidden)
        case 200?:
            return onComplete(TransmissionResponse.success)
        default:
            return onComplete(TransmissionResponse.failed)
        }
    }
    task.resume()
}

/// Tells transmission to olny download the selected files
public func setTransferFiles(transferId: Int, files: [Int], info: (config: TransmissionConfig, auth: TransmissionAuth), onComplete: @escaping (TransmissionResponse) -> Void) {
    url = info.config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = info.config.port ?? 443
    
    let requestBody = TorrentActionRequest(
        method: "torrent-set",
        arguments: [
            "ids": [transferId],
            "files-unwanted": files
        ]
    )
    
    let req = makeRequest(requestBody: requestBody, auth: info.auth)
    
    let task = URLSession.shared.dataTask(with: req) { (data, resp, err) in
        if err != nil {
            onComplete(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            authorize(httpResp: httpResp)
            setTransferFiles(transferId: transferId, files: files, info: info, onComplete: onComplete)
            return
        case 401?:
            return onComplete(TransmissionResponse.forbidden)
        case 200?:
            return onComplete(TransmissionResponse.success)
        default:
            return onComplete(TransmissionResponse.failed)
        }
    }
    task.resume()
}

/// Gets the session-token from the response and sets it as the `lastSessionToken`
public func authorize(httpResp: HTTPURLResponse?) {
    let mixedHeaders = httpResp?.allHeaderFields as! [String: Any]
    lastSessionToken = mixedHeaders[TOKEN_HEAD] as? String
}

/// Creates a `URLRequest` with provided body and TransmissionAuth
///
/// ```
/// let request = makeRequest(requestBody: body, auth: auth)
/// ```
///
/// - Parameter requestBody: Any struct that conforms to `Codable` to be sent as the request body
/// - Parameter auth: The authorization values username and password to authorize the request with credentials
/// - Returns: A `URLRequest` with the provided body and auth values
private func makeRequest<T: Codable>(requestBody: T, auth: TransmissionAuth) -> URLRequest {
    // Create the request with auth values
    var req = URLRequest(url: url!.url!)
    req.httpMethod = "POST"
    req.httpBody = try? JSONEncoder().encode(requestBody)
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(lastSessionToken, forHTTPHeaderField: TOKEN_HEAD)
    let loginString = String(format: "%@:%@", auth.username, auth.password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    req.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    
    return req
}
