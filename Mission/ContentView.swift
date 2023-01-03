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
    
    @State private var alertInput = ""
    @State private var filename  = ""
    @State private var downloadDir = ""
    
    var body: some View {
        List(store.torrents, id: \.self) { torrent in
            ListRow(torrent: binding(for: torrent), store: store)
        }
        .frame(minWidth: 500, idealWidth: 500, minHeight: 600, idealHeight: 600)
        .refreshable {
            updateList(store: store, update: {_ in})
        }
        .toast(isPresenting: $store.isShowingLoading) {
            AlertToast(type: .loading)
        }
        .onAppear(perform: {
            checkForUpdates()
            hosts.forEach { h in
                if (h.isDefault) {
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
                    Button(action: {
                        playPauseAll(start: false, info: makeConfig(store: store), onResponse: { response in
                            updateList(store: store, update: {_ in})
                        })
                    }) {
                        Text("Pause all")
                    }
                    Button(action: {
                        playPauseAll(start: true, info: makeConfig(store: store), onResponse: { response in
                            updateList(store: store, update: {_ in})
                        })
                    }) {
                        Text("Resume all")
                    }
                } label: {
                    Image(systemName: "playpause")
                }
            }
            ToolbarItem(placement: .status) {
                Menu {
                    ForEach(hosts, id: \.self) { host in
                        Button(action: {
                            store.setHost(host: host)
                            store.startTimer()
                            store.isShowingLoading.toggle()
                        }) {
                            let text = host.name
                            Text(text!)
                        }
                    }
                    Divider()
                    Button(action: {store.editServers.toggle()}) {
                        Text("Edit")
                    }
                } label: {
                    Image(systemName: "network")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    store.isShowingAddAlert.toggle()
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        // Add server sheet
        .sheet(isPresented: $store.setup, content: {
            AddServerDialog(store: store, viewContext: viewContext, hosts: hosts)
                .onExitCommand(perform: {
                    store.setup.toggle()
                })
        })
        // Edit server sheet
        .sheet(isPresented: $store.editServers, content: {
            EditServersDialog(viewContext: viewContext, store: store)
                .frame(width: 450, height: 350)
                .onExitCommand(perform: {
                    store.editServers.toggle()
                })
        })
        // Add torrent alert
        .sheet(isPresented: $store.isShowingAddAlert, content: {
            AddTorrentDialog(store: store)
                .onExitCommand(perform: {
                    store.isShowingAddAlert.toggle()
                })
        })
        // Add transfer file picker
        .sheet(isPresented: $store.isShowingTransferFiles, content: {
            FileSelectDialog(store: store)
                .frame(width: 400, height: 500)
                .onExitCommand(perform: {
                    store.isShowingTransferFiles.toggle()
                })
        })
        // Show an error message if we encounter an error
        .sheet(isPresented: $store.isError, content: {
            ErrorDialog(store: store)
                .frame(width: 400, height: 400)
                .onExitCommand(perform: {
                    store.isError.toggle()
                })
        })
        // Update available dialog
        .sheet(isPresented: $store.hasUpdate, content: {
            UpdateDialog(changelog: store.latestChangelog, store: store)
                .frame(width: 400, height: 500)
                
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
func updateList(store: Store, update: @escaping ([Torrent]) -> Void, retry: Int = 0) {
    let info = makeConfig(store: store)
    getTorrents(config: info.config, auth: info.auth, onReceived: { torrents, err in
        if (err != nil) {
            print("Showing error...")
            DispatchQueue.main.async {
                store.isError.toggle()
                store.debugBrief = "The server gave us this response:"
                store.debugMessage = err!
                store.timer.invalidate()
            }
        } else if (torrents == nil) {
            if (retry > 3) {
                print("Showing error...")
                DispatchQueue.main.async {
                    store.isError.toggle()
                    store.debugBrief = "Couldn't reach server."
                    store.debugMessage = "We asked the server a few times for a response, \nbut it never got back to us 😔"
                }
            }
            updateList(store: store, update: update, retry: retry + 1)
        } else {
            update(torrents!)
            DispatchQueue.main.async {
                store.isShowingLoading = false
            }
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
    config.scheme = store.host!.ssl ? "https" : "http"
    let keychain = Keychain(service: "me.jdiggity.mission")
    let password = keychain[store.host!.name!]
    let auth = TransmissionAuth(username: store.host!.username!, password: password!)
    
    return (config: config, auth: auth)
}
