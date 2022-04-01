//
//  FileSelectDialog.swift
//  Mission
//
//  Created by Joe Diragi on 3/16/22.
//

import Foundation
import SwiftUI

struct MultipleSelectionRow: View {
    var title: String
    @State var isSelected: Bool
    var action: () -> Void

    var body: some View {
        HStack {
            Toggle(self.title, isOn: self.$isSelected)
                .onChange(of: isSelected) { i in
                    action()
                }
        }
    }
}

struct FileSelectDialog: View {
    @ObservedObject var store: Store
    
    @State var files: [File] = []
    @State var selections: [Int] = []
    
    init(store: Store) {
        self.store = store
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Select Files")
                    .font(.headline)
                    .padding(.leading, 20)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                Button(action: {
                    store.isShowingTransferFiles.toggle()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .padding(.leading, 20)
                        .frame(alignment: .trailing)
                }).buttonStyle(BorderlessButtonStyle())
            }
            List {
                ForEach(Array(store.addTransferFilesList.enumerated()), id: \.offset) { (i,f) in
                    MultipleSelectionRow(title: f.name, isSelected: self.selections.contains(i)) {
                        if self.selections.contains(i) {
                            print("remove \(i)")
                            self.selections.append(i)
                        } else {
                            print("add \(i)")
                            self.selections.removeAll(where: { $0 == i })
                        }
                    }
                }
            }
            Button("Submit") {
                var dontDownload: [Int] = []
                store.addTransferFilesList.enumerated().forEach { (i,f) in
                    if (!self.selections.contains(i)) {
                        dontDownload.append(i)
                    }
                }
                print("Don't download: \(dontDownload)")
                setTransferFiles(transferId: store.transferToSetFiles, files: dontDownload, info: (config: store.server!.config, auth: store.server!.auth)) { i in
                    store.isShowingTransferFiles.toggle()
                }
            }.padding()
        }
    }
}
