//
//  AddServerDialog.swift
//  Mission
//
//  Created by Joe Diragi on 3/6/22.
//

import Foundation
import SwiftUI
import KeychainAccess

struct AddServerDialog: View {
    @ObservedObject var store: Store
    var viewContext: NSManagedObjectContext
    var hosts: FetchedResults<Host>
    
    @State var nameInput: String = ""
    @State var hostInput: String = ""
    @State var portInput: String = ""
    @State var userInput: String = ""
    @State var passInput: String = ""
    @State var isDefault: Bool = false
    @State var isSSL: Bool = false
    
    var body: some View {
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
            ).textFieldStyle(RoundedBorderTextFieldStyle())
                
            TextField(
                "Hostname (no http://)",
                text: $hostInput
            )
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
            Toggle("SSL", isOn: $isSSL)
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
            TextField(
                "Port",
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
            SecureField(
                "Password",
                text: $passInput
            )
                .padding([.leading, .trailing], 20)
                .padding([.top, .bottom], 5)
            HStack {
                Toggle("Make default", isOn: $isDefault)
                    .padding(.leading, 20)
                    .padding(.bottom, 10)
                    .disabled(store.host == nil)
                Spacer()
                Button("Submit") {
                    // Save host
                    let newHost = Host(context: viewContext)
                    newHost.name = nameInput
                    newHost.server = hostInput
                    newHost.port = Int16(portInput)!
                    newHost.username = userInput
                    newHost.isDefault = isDefault
                    newHost.ssl = isSSL
                    
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
                    
                    // Reset fields
                    nameInput = ""
                    hostInput = ""
                    portInput = ""
                    userInput = ""
                    passInput = ""
                    
                    // Update the view
                    store.setHost(host: newHost)
                    store.startTimer()
                    store.isShowingLoading.toggle()
                    store.setup.toggle()
                }
                .padding([.leading, .trailing], 20)
                .padding(.top, 5)
                .padding(.bottom, 10)
            }
        }.onAppear {
            if (store.host == nil) {
                isDefault = true
            }
        }
    }
}
