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
    @State var deleteDialog: Bool = false
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
            Button(action: {
                let info = makeConfig(store: store)
                playPause(torrent: torrent, config: info.config, auth: info.auth, onResponse: { response in
                    // TODO: Handle response
                })
            }, label: {
                Image(systemName: torrent.status == TorrentStatus.stopped.rawValue ? "play.circle" : "pause.circle")
            })
                .buttonStyle(BorderlessButtonStyle())
                .frame(width: 10, height: 10, alignment: .center)
                .padding(.trailing, 5)
            Menu {
                Menu {
                    Button("High") {
                        setPriority(torrent: torrent, priority: TorrentPriority.high, info: makeConfig(store: store), onComplete: { r in })
                    }
                    Button("Normal") {
                        setPriority(torrent: torrent, priority: TorrentPriority.normal, info: makeConfig(store: store), onComplete: { r in })
                    }
                    Button("Low") {
                        setPriority(torrent: torrent, priority: TorrentPriority.low, info: makeConfig(store: store), onComplete: { r in })
                    }
                } label: {
                    Text("Set priority")
                }
                Button("Delete", action: {
                    deleteDialog.toggle()
                })
                // Button("Download", action: {
                    // TODO: Download the destination folder using sftp library
                // })
            } label: {
                
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 10, height: 10, alignment: .center)
        }
        // Ask to delete files on disk when removing transfer
        .alert(
            "Remove Transfer",
            isPresented: $deleteDialog) {
                Button(role: .destructive) {
                    let info = makeConfig(store: store)
                    deleteTorrent(torrent: torrent, erase: true, config: info.config, auth: info.auth, onDel: { response in
                        // TODO: Handle response
                    })
                    deleteDialog.toggle()
                } label: {
                    Text("Delete files")
                }
                Button("Don't delete") {
                    let info = makeConfig(store: store)
                    deleteTorrent(torrent: torrent, erase: false, config: info.config, auth: info.auth, onDel: { response in
                        // TODO: Handle response
                    })
                    deleteDialog.toggle()
                }
            } message: {
                Text("Would you like to delete the transfered files from disk?")
            }.interactiveDismissDisabled(false)
    }
}
