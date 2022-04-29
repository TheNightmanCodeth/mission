//
//  GitHub.swift
//  Mission
//
//  Created by Joe Diragi on 3/30/22.
//

import Foundation

enum GithubError: Error {
    case unauthorized
    case forbidden
    case success
    case failed
}

struct Asset: Codable {
    var downloadLink: String
    
    enum CodingKeys: String, CodingKey {
        case downloadLink = "browser_download_url"
    }
}

struct Release: Codable {
    var version: String
    var changelog: String
    var title: String
    var assets: [Asset]
    
    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
        case changelog = "body"
        case title = "name"
        case assets
    }
}

func getLatestRelease(onComplete: @escaping (Release?, Error?) -> Void) {
    // Create the request with auth values
    var req = URLRequest(url: URL(string: "https://api.github.com/repos/TheNightmanCodeth/Mission/releases/latest")!)
    req.httpMethod = "GET"
    let task = URLSession.shared.dataTask(with: req) { (data, resp, err) in
        if err != nil {
            onComplete(nil, err!)
        }
        let httpResp = resp as? HTTPURLResponse
        let code = httpResp?.statusCode
        // Call `onAdd` with the status code
        switch httpResp?.statusCode {
        case 409?: // If we get a 409, save the token and try again
            return onComplete(nil, GithubError.unauthorized)
        case 401?:
            return onComplete(nil, GithubError.forbidden)
        case 200?:
            let response = try? JSONDecoder().decode(Release.self, from: data!)
            return onComplete(response, nil)
        default:
            return onComplete(nil, GithubError.failed)
        }
    }
    task.resume()
}
