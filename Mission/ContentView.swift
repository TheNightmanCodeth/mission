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
    @FetchRequest(
        entity: Host.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var hosts: FetchedResults<Host>

    @ObservedObject var store: Store = Store()
    private var keychain = Keychain(service: "me.jdiggity.mission")
    
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
    @State private var isDefault = false
    
    var body: some View {
        
        List(store.torrents, id: \.self) { torrent in
            ListRow(torrent: binding(for: torrent), store: store)
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
            
            if (store.server == nil) {
                if (!hosts.isEmpty) {
                    let host = hosts[0]
                    var config = TransmissionConfig()
                    config.host = host.server
                    config.port = Int(host.port)
                    store.setHost(host: host)
                }
            }
            
            if (store.host != nil) {
                updateList(host: store.host!, update: { vals in
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
                    .padding([.leading, .trailing], 20)
                    .padding(.bottom, 5)
                TextField(
                    "Nickname",
                    text: $nameInput
                )
                    .padding([.leading, .trailing], 20)
                    .padding([.top, .bottom], 5)
                TextField(
                    "Hostname (no http://)",
                    text: $hostInput
                )
                    .padding([.leading, .trailing], 20)
                    .padding([.top, .bottom], 5)
                TextField(
                    "port",
                    text: $portInput
                )
                    .padding([.leading, .trailing], 20)
                    .padding([.top, .bottom], 5)
                TextField(
                    "Username",
                    text: $userInput
                )
                    .padding([.leading, .trailing], 20)
                    .padding([.top, .bottom], 5)
                TextField(
                    "Password",
                    text: $passInput
                )
                    .padding([.leading, .trailing], 20)
                    .padding([.top, .bottom], 5)
                HStack {
                    Toggle("Make default", isOn: $isDefault)
                        .padding(.leading, 20)
                        .padding(.bottom, 10)
                    Spacer()
                    Button("Submit") {
                        // Save host
                        let newHost = Host(context: viewContext)
                        newHost.name = nameInput
                        newHost.server = hostInput
                        newHost.port = Int16(portInput)!
                        newHost.username = userInput
                        newHost.isDefault = isDefault
                        
                        // Make sure nobody else is default
                        if (isDefault) {
                            hosts.forEach { h in
                                if (h.isDefault) {
                                    h.isDefault.toggle()
                                }
                            }
                        }
                        
                        try? viewContext.save()
                        
                        // Save password to keychain
                        let keychain = Keychain(service: "me.jdiggity.mission")
                        keychain[nameInput] = passInput
                        
                        // Update the view
                        store.setHost(host: newHost)
                        store.startTimer()
                        store.setup.toggle()
                    }
                    .padding([.leading, .trailing], 20)
                    .padding(.top, 5)
                    .padding(.bottom, 10)
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
