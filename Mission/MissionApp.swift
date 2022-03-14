//
//  MissionApp.swift
//  Mission
//
//  Created by Joe Diragi on 2/24/22.
//

import SwiftUI
import Combine
import Firebase

@main
struct MissionApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
