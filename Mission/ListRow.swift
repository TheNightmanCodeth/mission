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
                    .padding(.bottom, 1)
                ProgressView(value: torrent.percentDone)
                    .progressViewStyle(LinearProgressViewStyle(tint: torrent.status == TorrentStatus.seeding.rawValue ? Color.green : Color.blue))
                let status = torrent.status == TorrentStatus.seeding.rawValue ?
                    "Seeding to \(torrent.peersConnected - torrent.sendingToUs) of \(torrent.peersConnected) peers" :
                torrent.status == TorrentStatus.stopped.rawValue ? "Stopped" :
                    "Downloading from \(torrent.sendingToUs) of \(torrent.peersConnected) peers"
                
                Text(status)
                    .font(.custom("sub", size: 10))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }.padding([.top, .bottom, .leading], 10)
                .padding(.trailing, 5)
            Button(action: {}, label: {
                Image(systemName: torrent.status == TorrentStatus.stopped.rawValue ? "play.circle" : "pause.circle")
            })
                .buttonStyle(BorderlessButtonStyle())
                .frame(width: 10, height: 10, alignment: .center)
                .padding(.trailing, 5)
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
                Button("Download", action: {
                    // TODO: Download the destination folder using sftp library
                })
            } label: {
                
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 10, height: 10, alignment: .center)
        }
    }
}
