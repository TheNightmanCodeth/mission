//
//  ListEntry.swift
//  Mission
//
//  Created by Joe Diragi on 3/3/22.
//

import Foundation
import SwiftUI
import KeychainAccess

struct ListRow: View {
    @Binding var torrent: Torrent
    var store: Store
    
    var body: some View {
        HStack {
            VStack {
                Text(torrent.name)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                ProgressView(value: torrent.percentDone)
            }.padding(.all, 10)
            Menu {
                Button("Delete", action: {
                    var config = TransmissionConfig()
                    config.host = store.host?.server
                    config.port = Int(store.host!.port)
                    let keychain = Keychain(service: "me.jdiggity.mission")
                    let password = keychain[store.host!.name!]
                    let auth = TransmissionAuth(username: store.host!.username!, password: password!)
                    
                    deleteTorrent(torrent: torrent, erase: false, config: config, auth: auth, onDel: { response in
                        // TODO: Handle response
                    })
                })
            } label: {
                
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 10, height: 10, alignment: .center)
        }
    }
}
