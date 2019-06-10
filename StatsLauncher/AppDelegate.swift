//
//  AppDelegate.swift
//  StatsLauncher
//
//  Created by Samuel Grant on 10/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainAppIdentifier = "eu.exelban.Stats"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty
        
        if !isRunning {
            DistributedNotificationCenter.default().addObserver(self,
                                                                selector: #selector(self.terminate),
                                                                name: .killLauncher,
                                                                object: mainAppIdentifier)
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            NSWorkspace.shared.launchApplication(path as String)
        }
        else {
            self.terminate()
        }
    }
    
    @objc func terminate() {
        NSApp.terminate(nil)
    }
}

