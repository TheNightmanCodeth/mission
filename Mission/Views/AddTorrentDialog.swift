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
    
    var body: some View {
        VStack {
            HStack {
                Text("Add Torrent")
                    .font(.headline)
                    .padding(.leading, 20)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                Button(action: {
                    store.isShowingAddAlert.toggle()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .padding(.leading, 20)
                        .frame(alignment: .trailing)
                }).buttonStyle(BorderlessButtonStyle())
            }
            
            Text("Add either a magnet link or .torrent file.")
                .fixedSize(horizontal: true, vertical: true)
                //.frame(maxWidth: 200, alignment: .center)
                .font(.body)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Magnet Link")
                    .font(.system(size: 10))
                    //.frame(width: 100, alignment: .leading)
                    .padding(.top, 10)
                    .padding(.leading)
                    .padding(.bottom, 5)
                    
                TextField(
                    "Magnet link",
                    text: $alertInput
                ).onSubmit {
                    // TODO: Validate entry
                }
                .padding([.leading, .trailing])
            }
            .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Download Destination")
                    .font(.system(size: 10))
                    .padding(.top, 10)
                    .padding(.leading)
                    .padding(.bottom, 5)
                TextField(
                    "Download Destination",
                    text: $downloadDir
                )
                    .padding([.leading, .trailing])
            }
            
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
                            if response.response == TransmissionResponse.success {
                                store.isShowingAddAlert.toggle()
                                showFilePicker(transferId: response.transferId, info: info)
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
                        if response.response == TransmissionResponse.success {
                            store.isShowingAddAlert.toggle()
                            showFilePicker(transferId: response.transferId, info: info)
                        }
                    })
                }.padding()
            }
            
        }.interactiveDismissDisabled(false)
            .onAppear {
                downloadDir = store.defaultDownloadDir
            }
    }
    
    func showFilePicker(transferId: Int, info: (config: TransmissionConfig, auth: TransmissionAuth)) {
        getTransferFiles(transferId: transferId, info: info, onReceived: { f in
            store.addTransferFilesList = f
            store.transferToSetFiles = transferId
            store.isShowingTransferFiles.toggle()
        })
    }
}

// This is needed to silence buildtime warnings related to the filepicker.
// `.allowedFileTypes` was deprecated in favor of this attrocity. No comment <3
extension UTType {
    static var torrent: UTType {
        UTType.types(tag: "torrent", tagClass: .filenameExtension, conformingTo: nil).first!
    }
}
