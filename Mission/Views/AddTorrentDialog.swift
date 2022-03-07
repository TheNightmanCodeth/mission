//
//  AddTorrentAlert.swift
//  Mission
//
//  Created by Joe Diragi on 3/6/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentDialog: View {
    @ObservedObject var store: Store
    
    @State var alertInput: String = ""
    @State var downloadDir: String = ""
    @State var isShowingAddAlert: Bool = false
    
    var body: some View {
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
            
            Text("Add either a magnet link or .torrent file.")
                .fixedSize(horizontal: true, vertical: true)
                .frame(maxWidth: 200, alignment: .center)
                .font(.body)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            
            TextField(
                "Magnet link",
                text: $alertInput
            ).onSubmit {
                // TODO: Validate entry
            }.padding()
            
            TextField(
                "Download directory",
                text: $downloadDir
            ).padding()
            
            HStack {
                Button("Upload file") {
                    // Show file chooser panel
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.torrent]
                    
                    if panel.runModal() == .OK {
                        // Convert the file to a base64 string
                        let fileData = try! Data.init(contentsOf: panel.url!)
                        let fileStream: String = fileData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                        
                        let info = makeConfig(store: store)
                        
                        addTorrent(fileUrl: fileStream, saveLocation: downloadDir, auth: info.auth, file: true, config: info.config, onAdd: { response in
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
                    let info = makeConfig(store: store)
                    addTorrent(fileUrl: alertInput, saveLocation: downloadDir, auth: info.auth, file: false, config: info.config, onAdd: { response in
                        if response == TransmissionResponse.success {
                            self.isShowingAddAlert.toggle()
                        }
                    })
                }.padding()
            }
            
        }.interactiveDismissDisabled(false)
    }
}

// This is needed to silence buildtime warnings related to the filepicker.
// `.allowedFileTypes` was deprecated in favor of this attrocity. No comment <3
extension UTType {
    static var torrent: UTType {
        UTType.types(tag: "torrent", tagClass: .filenameExtension, conformingTo: nil).first!
    }
}
