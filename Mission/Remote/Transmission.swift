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
}

public enum TransmissionResponse {
    case success
    case forbidden
    case configError
    case failed
}

public func getTorrents(config: TransmissionConfig, auth: TransmissionAuth, onReceived: @escaping ([Torrent]?) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    let listReq = TransmissionListRequest(
        method: "torrent-get",
        arguments: [
            "fields": [ "id", "name", "totalSize", "percentDone" ]
        ]
    )
    
    var req = URLRequest(url: url!.url!)
    let username = auth.username
    let password = auth.password
    let loginString = String(format: "%@:%@", username, password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    
    req.httpMethod = "POST"
    req.httpBody = try? JSONEncoder().encode(listReq)
    req.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(lastSessionToken, forHTTPHeaderField: TOKEN_HEAD)
    
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onReceived(nil)
        }
        print(String(decoding: data!, as: UTF8.self))
        let httpResp = resp as? HTTPURLResponse
        switch httpResp?.statusCode {
        case 409?:
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

public func addTorrent(fileUrl: String, auth: TransmissionAuth, file: Bool, config: TransmissionConfig, onAdd: @escaping (TransmissionResponse) -> Void) -> Void {
    url = config
    url?.scheme = "http"
    url?.path = "/transmission/rpc"
    url?.port = config.port ?? 443
    
    var torrentBody: TransmissionRequest? = nil
    
    if (file) {
        torrentBody = TransmissionRequest (
            method: "torrent-add",
            arguments: ["metainfo": fileUrl]
        )
    } else {
        torrentBody = TransmissionRequest(
            method: "torrent-add",
            arguments: ["fileName": fileUrl]
        )
    }
    
    var req: URLRequest = makeRequest(setTorrentBody: torrentBody!)
    let loginString = String(format: "%@:%@", auth.username, auth.password)
    let loginData = loginString.data(using: String.Encoding.utf8)!
    let base64LoginString = loginData.base64EncodedString()
    req.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
        if error != nil {
            return onAdd(TransmissionResponse.configError)
        }
        
        let httpResp = resp as? HTTPURLResponse
        
        let response = httpResp?.statusCode
        
        switch httpResp?.statusCode {
        case 409?:
            authorize(httpResp: httpResp)
            addTorrent(fileUrl: fileUrl, auth: auth, file: file, config: config, onAdd: onAdd)
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
