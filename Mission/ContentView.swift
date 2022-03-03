//
//  ContentView.swift
//  Mission
//
//  Created by Joe Diragi on 2/24/22.
//

import SwiftUI
import TransmissionRpcClient
import Combine
import Logging
import Foundation
import KeychainAccess

struct windowSize {
    // changes let to static - read comments
    let minWidth : CGFloat = 500
    let minHeight : CGFloat = 500
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var store: Store = Store()
    @ObservedObject var serverStore: ServerStore = ServerStore()
    
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
            ListRow(torrent: binding(for: torrent))
        }
        
        //.frame(minWidth: windowSize().minWidth, minHeight: windowSize().minHeight)
        .navigationTitle("Mission")
        .toolbar {
            ToolbarItem(placement: .status) {
                Button(action: {
                    self.isShowingAuthAlert.toggle()
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
                    })
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
                        let newHost = Host(context: viewContext)
                        newHost.name = nameInput
                        newHost.server = hostInput
                        var port = portInput
                        newHost.port = Int16(portInput)!
                        newHost.username = userInput
                        let keychain = Keychain(service: "me.jdiggity.mission")
                        keychain[nameInput] = passInput
                        try? viewContext.save()
                        serverStore.setServer(host: newHost)
                        store.updateServer(newHost: newHost)
                        store.startTimer()
                        store.setup.toggle()
                        self.isShowingAuthAlert.toggle()
                    }.padding()
                }
            }
        })
        .sheet(isPresented: $isShowingAddAlert, onDismiss: {}, content: {
            VStack {
                HStack {
                    Text("Add Torrent")
                        .font(.headline)
                        .padding(.bottom, 10)
                        .padding(.top, 20)
                    
                    Button(action: {
                        self.isShowingAddAlert.toggle()
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    })
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
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        //panel.allowedContentTypes
                        if panel.runModal() == .OK {
                            let fileData = try! Data.init(contentsOf: panel.url!)
                            let fileStream: String = fileData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                            var config = TransmissionConfig()
                            config.host = serverStore.host?.server
                            config.port = Int(serverStore.host!.port)
                            let keychain = Keychain(service: "me.jdiggity.mission")
                            let password = keychain[serverStore.host!.name!]
                            let auth = TransmissionAuth(username: serverStore.host!.username!, password: password!)
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
                        var config = TransmissionConfig()
                        config.host = serverStore.host?.server
                        config.port = Int(serverStore.host!.port)
                        let keychain = Keychain(service: "me.jdiggity.mission")
                        let password = keychain[serverStore.host!.name!]
                        let auth = TransmissionAuth(username: serverStore.host!.username!, password: password!)
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

class Store: NSObject, ObservableObject {
    @Published var torrents: [Torrent] = []
    @Published var setup: Bool = false
    var timer: Timer = Timer()
    @ObservedObject var serverStore: ServerStore = ServerStore()
    
    override init() {
        super.init()
        
        DispatchQueue.main.async {
            if (self.serverStore.host != nil) {
                updateList(host: self.serverStore.host!, update: { vals in
                    self.torrents = vals
                })
                self.startTimer()
            } else {
                // Create a new host
                self.setup = true
            }
        }
    }
    
    func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
            DispatchQueue.main.async {
                print("updating list")
                updateList(host: self.serverStore.host!, update: { vals in
                    self.objectWillChange.send()
                    self.torrents = vals
                })
            }
        })
    }
    
    func updateServer(newHost: Host) {
        self.serverStore.setServer(host: newHost)
    }
}

class ServerStore: NSObject, ObservableObject {
    @Published var server: Server?
    @Published var host: Host?
    
    override init() {
        super.init()
        // TODO: Set server to default value
        @FetchRequest(
            entity: Host.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        ) var hosts: FetchedResults<Host>
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
    
}

struct Server {
    var config: TransmissionConfig
    var auth: TransmissionAuth
}

struct ListRow: View {
    @Binding var torrent: Torrent
    var body: some View {
        VStack {
            Text(torrent.name)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            ProgressView(value: torrent.percentDone)
        }.padding(.all, 10)
    }
}

func updateList(host: Host, update: @escaping ([Torrent]) -> Void) {
    var config = TransmissionConfig()
    config.host = host.server
    config.port = Int(host.port)
    
    let keychain = Keychain(service: "me.jdiggity.mission")
    let auth = TransmissionAuth(username: host.username!, password: keychain[host.name!]!)
    
    getTorrents(config: config, auth: auth, onReceived: { torrents in
        print("Updating torrents...")
        // TODO: Check for null in `torrents` and show auth error
        update(torrents!)
    })
}
