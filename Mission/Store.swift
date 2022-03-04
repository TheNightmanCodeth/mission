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
    var timer: Timer = Timer()
    
    override init() {
        super.init()
        @FetchRequest(
            entity: Host.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        ) var hosts: FetchedResults<Host>
        // TODO: Add this to the view's onAppear
        hosts.forEach { h in
            if (h.isDefault) {
                var config = TransmissionConfig()
                config.host = h.server
                config.port = Int(h.port)
                let auth = TransmissionAuth(username: h.username!, password: readPassword(name: h.name!))
                self.server = Server(config: config, auth: auth)
                self.host = h
            }
        }
        
        if server == nil {
            if (!hosts.isEmpty) {
                let host = hosts[0]
                var config = TransmissionConfig()
                config.host = host.server
                config.port = Int(host.port)
                let auth = TransmissionAuth(username: host.username!, password: readPassword(name: host.name!))
                self.server = Server(config: config, auth: auth)
                self.host = host
            }
        }
        
        DispatchQueue.main.async {
            if (self.host != nil) {
                updateList(host: self.host!, update: { vals in
                    self.torrents = vals
                })
                self.startTimer()
            } else {
                // Create a new host
                self.setup = true
            }
        }
    }
    
    public func setServer(host: Host) {
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
                print("updating list")
                updateList(host: self.host!, update: { vals in
                    self.objectWillChange.send()
                    self.torrents = vals
                })
            }
        })
    }
    
    func updateServer(newHost: Host) {
        self.setServer(host: newHost)
    }
}
