//
//  ContentView.swift
//  Mission
//
//  Created by Joe Diragi on 2/24/22.
//

import SwiftUI
import Combine
import Logging
import Foundation
import KeychainAccess

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var store: Store = Store()
    
    @State private var isShowingAddAlert = false
    @State private var isShowingAuthAlert = false
    @State private var isShowingFilePicker = false
    
    @State private var nameInput = ""
    @State private var alertInput = ""
    @State private var hostInput = ""
    @State private var portInput = ""
    @State private var userInput = ""
    @State private var passInput = ""
    @State private var filename  = ""
    
    var body: some View {
        
        List(store.torrents, id: \.self) { torrent in
            ListRow(torrent: binding(for: torrent), store: store)
        }
        .navigationTitle("Mission")
        .toolbar {
            ToolbarItem(placement: .status) {
                Button(action: {
                    store.setup.toggle()
                }) {
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
        .sheet(isPresented: $store.setup, onDismiss: {}, content: {
            VStack {
                HStack {
                    Text("Connect to Server")
                        .font(.headline)
                        .padding(.bottom, 10)
                        .padding(.top, 20)
                    
                    Button(action: {
                        store.setup.toggle()
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    }).buttonStyle(BorderlessButtonStyle())
                }
                Text("Add a server with it's URL and login")
                    .padding()
                TextField(
                    "Nickname",
                    text: $nameInput
                ).padding()
                TextField(
                    "Hostname (no http://)",
                    text: $hostInput
                ).padding()
                TextField(
                    "port",
                    text: $portInput
                ).padding()
                TextField(
                    "Username",
                    text: $userInput
                ).padding()
                TextField(
                    "Password",
                    text: $passInput
                ).padding()
                HStack {
                    Spacer()
                    Button("Submit") {
                        // Save host
                        let newHost = Host(context: viewContext)
                        newHost.name = nameInput
                        newHost.server = hostInput
                        newHost.port = Int16(portInput)!
                        newHost.username = userInput
                        try? viewContext.save()
                        
                        // Save password to keychain
                        let keychain = Keychain(service: "me.jdiggity.mission")
                        keychain[nameInput] = passInput
                        
                        // Update the view
                        store.setServer(host: newHost)
                        store.updateServer(newHost: newHost)
                        store.startTimer()
                        store.setup.toggle()
                    }.padding()
                }
            }
        })
        .sheet(isPresented: $isShowingAddAlert, onDismiss: {}, content: {
            VStack {
                HStack {
                    Text("Add Torrent")
                        .font(.headline)
                        .padding(.leading, 20)
                        .padding(.bottom, 10)
                        .padding(.top, 20)
                    Button(action: {
                        self.isShowingAddAlert.toggle()
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            .padding(.leading, 20)
                    }).buttonStyle(BorderlessButtonStyle())
                }
                
                Text("Add either a magnet link or .torrent file")
                    .font(.body)
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                
                TextField(
                    "Magnet link",
                    text: $alertInput
                ).onSubmit {
                    // TODO: Validate entry
                }.padding()
                
                HStack {
                    Button("Upload file") {
                        // Show file chooser panel
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        // TODO: Figure out how the hell to use [UTTYpe]
                        panel.allowedFileTypes = ["torrent"]
                        
                        if panel.runModal() == .OK {
                            // Convert the file to a base64 string
                            let fileData = try! Data.init(contentsOf: panel.url!)
                            let fileStream: String = fileData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                            // Send the file to the server
                            var config = TransmissionConfig()
                            config.host = store.host?.server
                            config.port = Int(store.host!.port)
                            let keychain = Keychain(service: "me.jdiggity.mission")
                            let password = keychain[store.host!.name!]
                            let auth = TransmissionAuth(username: store.host!.username!, password: password!)
                            addTorrent(fileUrl: fileStream, auth: auth, file: true, config: config, onAdd: { response in
                                if response == TransmissionResponse.success {
                                    self.isShowingAddAlert.toggle()
                                }
                            })
                        }
                    }
                    .padding()
                    Spacer()
                    Button("Submit") {
                        // Send the magnet link to the server
                        var config = TransmissionConfig()
                        config.host = store.host?.server
                        config.port = Int(store.host!.port)
                        let keychain = Keychain(service: "me.jdiggity.mission")
                        let password = keychain[store.host!.name!]
                        let auth = TransmissionAuth(username: store.host!.username!, password: password!)
                        addTorrent(fileUrl: alertInput, auth: auth, file: false, config: config, onAdd: { response in
                            if response == TransmissionResponse.success {
                                self.isShowingAddAlert.toggle()
                            }
                        })
                    }.padding()
                }
                
            }.interactiveDismissDisabled(false)
        })
    }
    
    func binding(for torrent: Torrent) -> Binding<Torrent> {
        guard let scrumIndex = store.torrents.firstIndex(where: { $0.id == torrent.id }) else {
            fatalError("Can't find in array")
        }
        return $store.torrents[scrumIndex]
    }
}

func updateList(host: Host, update: @escaping ([Torrent]) -> Void) {
    var config = TransmissionConfig()
    config.host = host.server
    config.port = Int(host.port)
    
    let keychain = Keychain(service: "me.jdiggity.mission")
    let auth = TransmissionAuth(username: host.username!, password: keychain[host.name!]!)
    
    getTorrents(config: config, auth: auth, onReceived: { torrents in
        // TODO: Check for null in `torrents` and show auth error
        update(torrents!)
    })
}
