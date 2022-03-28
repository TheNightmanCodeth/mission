//
//  EditServersDialog.swift
//  Mission
//
//  Created by Joe Diragi on 3/28/22.
//

import SwiftUI
import KeychainAccess
import AlertToast

struct EditServersDialog: View {
    var viewContext: NSManagedObjectContext
    @ObservedObject var store: Store
    
    @State var selected: Host? = nil
    
    @FetchRequest(
        entity: Host.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) var hosts: FetchedResults<Host>
    
    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Spacer()
                Button(action: {
                    store.editServers.toggle()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                }).buttonStyle(BorderlessButtonStyle())
                    .padding(.trailing, 20)
            }
            NavigationView {
                VStack(alignment: .leading) {
                    List(hosts) { host in
                        NavigationLink(host.name!, destination: ServerDetailsView(host: host, viewContext: viewContext, store: store), tag: host, selection: $selected)
                    }
                    Spacer()
                    HStack {
                        Button(action: {
                            let newHost = Host(context: viewContext)
                            newHost.name = "New Server"
                            try? viewContext.save()
                            self.selected = newHost
                        }, label: {
                            Image(systemName: "plus")
                        }).buttonStyle(BorderlessButtonStyle())
                            .padding([.leading, .bottom], 15)
                        
                        Button(action: {
                            viewContext.delete(selected!)
                        }, label: {
                            Image(systemName: "minus")
                        }).buttonStyle(BorderlessButtonStyle())
                            .padding(.bottom, 15)
                            .padding(.leading, 5)
                            .disabled(selected == nil)
                    }
                }
                
                Spacer()
            }
            
        }
        .toast(isPresenting: $store.successToast) {
            AlertToast(type: .complete(Color.green), title: "Success", subTitle: "Server details updated!")
        }
    }
}

struct ServerDetailsView: View {
    var viewContext: NSManagedObjectContext
    var store: Store
    let keychain = Keychain(service: "me.jdiggity.mission")
    @State var host: Host
    
    @State var showHidePW: Bool = true // True means hidden
    @State var nameInput: String = ""
    @State var hostInput: String = ""
    @State var portInput: String = ""
    @State var userInput: String = ""
    @State var passInput: String = ""
    @State var isDefault: Bool = false
    
    init(host: Host, viewContext: NSManagedObjectContext, store: Store) {
        self.host = host
        self.store = store
        self.viewContext = viewContext
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nickname")
                .font(.system(size: 10))
                .padding(.top, 10)
                .padding(.leading, 20)
            
            TextField(
                "Nickname",
                text: $nameInput
            )
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
                .onAppear { nameInput = host.name ?? "" }
        }
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Hostname (no http://)")
                .font(.system(size: 10))
                .padding(.leading, 20)
            
            TextField(
                "Hostname (no http://)",
                text: $hostInput
            )
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
                .onAppear { hostInput = host.server ?? "" }
        }
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Port")
                .font(.system(size: 10))
                .padding(.leading, 20)
            
            TextField(
                "Port",
                text: $portInput
            )
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
                .onAppear { portInput = "\(host.port)" }
        }
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Username")
                .font(.system(size: 10))
                .padding(.leading, 20)
            
            TextField(
                "Username",
                text: $userInput
            )
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
                .onAppear { userInput = host.username ?? "" }
        }
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Password")
                .font(.system(size: 10))
                .padding(.leading, 20)
            ZStack(alignment: .trailing) {
                if (showHidePW) {
                    SecureField(
                        "Password",
                        text: $passInput
                    )
                        .padding([.leading, .trailing], 20)
                        .padding([.top, .bottom], 5)
                        .onAppear { passInput = keychain[host.name!] ?? "" }
                } else {
                    TextField(
                        "Password",
                        text: $passInput
                    )
                        .padding([.leading, .trailing], 20)
                        .padding([.top, .bottom], 5)
                        .onAppear { passInput = keychain[host.name!] ?? "" }
                }
                Button(action: {
                    showHidePW.toggle()
                }) {
                    Image(systemName: self.showHidePW ? "eye.slash" : "eye")
                        .tint(.gray)
                }.padding(.trailing, 25)
                    .buttonStyle(BorderlessButtonStyle())
            }
        }
        
        HStack {
            Toggle("Make default", isOn: $isDefault)
                .padding(.leading, 20)
                .padding(.bottom, 10)
                .onAppear { isDefault = host.isDefault }
            Spacer()
            Button("Submit") {
                // Save host
                host.name = nameInput
                host.server = hostInput
                host.port = Int16(portInput)!
                host.username = userInput
                
                try? viewContext.save()
                
                // Save password to keychain
                keychain[nameInput] = passInput
                
                store.successToast.toggle()
            }
            .padding([.leading, .trailing], 20)
            .padding(.top, 5)
            .padding(.bottom, 10)
        }
    }
}
