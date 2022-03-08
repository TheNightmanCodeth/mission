//
//  FileAccess.swift
//  Mission
//
//  Created by Joe Diragi on 3/6/22.
//

import Foundation

public struct FileAccess {
    func downloadFile(path: String, host: Host, auth: (username: String, password: String), onRec: @escaping (Data) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let urlString = "ftp://\(auth.username):\(auth.password)@\(String(describing: host.server))/\(path)"
            let url = URL(string: urlString)
            var data: Data? = nil
            if let anUrl = url {
                data = try? Data(contentsOf: anUrl)
                onRec(data!)
            }
        }
    }
}
