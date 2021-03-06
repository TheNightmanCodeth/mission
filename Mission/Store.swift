//
//  Store.swift
//  Mission
//
//  Created by Joe Diragi on 3/3/22.
//
import SwiftUI
import Foundation
import KeychainAccess

struct Server {
    var config: TransmissionConfig
    var auth: TransmissionAuth
}

class Store: NSObject, ObservableObject {
    @Published var torrents: [Torrent] = []
    @Published var setup: Bool = false
    @Published var server: Server?
    @Published var host: Host?
    
    @Published var isShowingLoading: Bool = false
    @Published var defaultDownloadDir: String = ""
    
    @Published var isShowingAddAlert: Bool = false
    @Published var isShowingServerAlert: Bool = false
    @Published var isShowingTransferFiles: Bool = false
    @Published var transferToSetFiles: Int = 0
    @Published var editServers: Bool = false
    @Published var successToast: Bool = false
    @Published var hasUpdate: Bool = false
    @Published var latestRelease: String = ""
    @Published var latestRelTitle: String = ""
    @Published var latestChangelog: String = ""
    
    @Published var isError: Bool = false
    @Published var debugBrief: String = ""
    @Published var debugMessage: String = ""
    
    @Published var addTransferFilesList: [File] = []
    
    var timer: Timer = Timer()
    
    public func setHost(host: Host) {
        var config = TransmissionConfig()
        config.host = host.server
        config.port = Int(host.port)
        
        let auth = TransmissionAuth(username: host.username!, password: readPassword(name: host.name!))
        self.server = Server(config: config, auth: auth)
        self.host = host
    }
    
    func readPassword(name: String) -> String {
        let keychain = Keychain(service: "me.jdiggity.mission")
        let password = keychain[name]
        return password!
    }
    
    func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
            DispatchQueue.main.async {
                updateList(store: self, update: { vals in
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                        self.torrents = vals
                    }
                })
            }
        })
    }
}
