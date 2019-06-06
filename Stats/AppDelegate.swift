//
//  AppDelegate.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

let modules: Observable<[Module]> = Observable([CPU(), Memory(), Disk()])
let colors: Observable<Bool> = Observable(true)

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard
    var menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = self.menuBarItem.button else {
            NSApp.terminate(nil)
            return
        }
        
        colors << (defaults.object(forKey: "colors") != nil ? defaults.bool(forKey: "colors") : false)
        _ = MenuBar(menuBarItem, menuBarButton: menuBarButton)
        
        let launcherAppId = "eu.exelban.Stats"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        
        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if modules.value.count != 0 {
            for module in modules.value{
                module.stop()
            }
        }
    }
}
