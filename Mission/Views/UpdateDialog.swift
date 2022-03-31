//
//  UpdateDialog.swift
//  Mission
//
//  Created by Joe Diragi on 3/30/22.
//

import SwiftUI
import System

struct UpdateDialog: View {
    @Environment(\.openURL) var openURL
    @State var changelog: String
    var store: Store
    
    var body: some View {
        VStack {
            HStack {
                Text(store.latestRelTitle)
                    .padding(.top, 20)
            }
            ScrollView {
                Text(
                    changelog
                ).textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            HStack {
                Button("Cancel") {
                    store.hasUpdate.toggle()
                }.padding(20)
                Spacer()
                Button("Get Update") {
                    openURL(URL(string: store.latestRelease)!)
                    store.hasUpdate.toggle()
                }.padding(20)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

