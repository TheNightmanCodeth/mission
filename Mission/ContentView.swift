//
//  ContentView.swift
//  Mission
//
//  Created by Joe Diragi on 2/24/22.
//

import SwiftUI
import Foundation
import KeychainAccess
import AlertToast

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Host.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var hosts: FetchedResults<Host>

    @ObservedObject var store: Store = Store()
    private var keychain = Keychain(service: "me.jdiggity.mission")
    
    @State private var isShowingAddAlert = false
    
    @State private var alertInput = ""
    @State private var filename  = ""
    @State private var downloadDir = ""
    
    var body: some View {
        List(store.torrents, id: \.self) { torrent in
            ListRow(torrent: binding(for: torrent), store: store)
        }
        .toast(isPresenting: $store.isShowingLoading) {
            AlertToast(type: .loading)
        }
        .onAppear(perform: {
            hosts.forEach { h in
                if (h.isDefault) {
                    var config = TransmissionConfig()
                    config.host = h.server
                    config.port = Int(h.port)
                    store.setHost(host: h)
                }
            }
            if (store.host != nil) {
                let info = makeConfig(store: store)
                getDefaultDownloadDir(config: info.config, auth: info.auth, onResponse: { downloadDir in
                    DispatchQueue.main.async {
                        store.defaultDownloadDir = downloadDir
                        self.downloadDir = store.defaultDownloadDir
                    }
                })
                updateList(store: store, update: { vals in
                    DispatchQueue.main.async {
                        store.torrents = vals
                    }
                })
                store.startTimer()
            } else {
                // Create a new host
                store.setup = true
            }
        })
        .navigationTitle("Mission")
        .toolbar {
            ToolbarItem(placement: .status) {
                Menu {
                    ForEach(hosts, id: \.self) { host in
                        Button(action: {
                            store.setHost(host: host)
                            store.startTimer()
                            store.isShowingLoading.toggle()
                        }) {
                            let text = host.isDefault ? "\(host.name!) *" : host.name
                            Text(text!)
                        }
                    }
                    Button(action: {store.setup.toggle()}) {
                        Text("Add new...")
                    }
                } label: {
                    Image(systemName: "network")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    self.isShowingAddAlert.toggle()
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        // Add server sheet
        .sheet(isPresented: $store.setup, onDismiss: {}, content: {
            AddServerDialog(store: store, viewContext: viewContext, hosts: hosts)
        })
        // Add torrent alert
        .sheet(isPresented: $isShowingAddAlert, onDismiss: {}, content: {
            AddTorrentDialog(store: store)
        })
    }
    
    func binding(for torrent: Torrent) -> Binding<Torrent> {
        guard let scrumIndex = store.torrents.firstIndex(where: { $0.id == torrent.id }) else {
            fatalError("Can't find in array")
        }
        return $store.torrents[scrumIndex]
    }
}

/// Updates the list of torrents when called
func updateList(store: Store, update: @escaping ([Torrent]) -> Void) {
    let info = makeConfig(store: store)
    getTorrents(config: info.config, auth: info.auth, onReceived: { torrents in
        update(torrents!)
        DispatchQueue.main.async {
            store.isShowingLoading = false
        }
    })
}

/// Function for generating config and auth for API calls
/// - Parameter store: The current `Store` containing session information needed for creating the config.
/// - Returns a tuple containing the requested `config` and `auth`
func makeConfig(store: Store) -> (config: TransmissionConfig, auth: TransmissionAuth) {
    // Send the file to the server
    var config = TransmissionConfig()
    config.host = store.host?.server
    config.port = Int(store.host!.port)
    let keychain = Keychain(service: "me.jdiggity.mission")
    let password = keychain[store.host!.name!]
    let auth = TransmissionAuth(username: store.host!.username!, password: password!)
    
    return (config: config, auth: auth)
}
