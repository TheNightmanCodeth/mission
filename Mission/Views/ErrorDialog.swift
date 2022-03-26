//
//  ErrorDialog.swift
//  Mission
//
//  Created by Joe Diragi on 3/25/22.
//

import Foundation
import SwiftUI

struct ErrorDialog: View {
    var store: Store
    
    var body: some View {
        VStack {
            HStack {
                Text("Error")
                    .font(.headline)
                    .padding(.leading, 20)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                Button(action: {
                    store.isError.toggle()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .padding(.leading, 20)
                        .frame(alignment: .trailing)
                }).buttonStyle(BorderlessButtonStyle())
            }
            Text(store.debugBrief)
                .padding(.horizontal, 20)
            ScrollView {
                Text(store.debugMessage)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: false)
            }.padding(.bottom, 20)
        }
    }
}
