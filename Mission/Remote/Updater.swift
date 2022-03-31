//
//  Updater.swift
//  Mission
//
//  Created by Joe Diragi on 3/30/22.
//

import Foundation

extension ContentView {
    func checkForUpdates() {
        getLatestRelease(onComplete: { (release, err) in
            if (err != nil) {
                store.debugBrief = "Error checking for updates"
                store.debugMessage = err.debugDescription
                store.isError.toggle()
                return
            }
            let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            let appVersion = Double(appVersionString)
            let relVersion = Double(release!.version)
            // Download release and mount DMG
            if (appVersion! < relVersion!) {
                DispatchQueue.main.async {
                    store.latestRelTitle = release!.title
                    store.latestChangelog = release!.changelog
                    store.latestRelease = release!.assets[0].downloadLink
                    store.hasUpdate = true
                }
            }
        })
    }
}
