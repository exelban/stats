//
//  AppDelegate.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

import Kit

import CPU
import RAM
import Disk
import Net
import Battery
import Sensors
import GPU
import Fans
import Bluetooth

let updater = macAppUpdater(user: "exelban", repo: "stats")
var modules: [Module] = [
    CPU(),
    GPU(),
    RAM(),
    Disk(),
    Sensors(),
    Fans(),
    Network(),
    Battery(),
    Bluetooth()
]

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    internal let settingsWindow: SettingsWindow = SettingsWindow()
    internal let updateWindow: UpdateWindow = UpdateWindow()
    internal let updateNotification = NSUserNotification()
    internal let updateActivity = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.updateCheck")
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        
        self.parseArguments()
        self.parseVersion()
        
        modules.forEach{ $0.mount() }
        self.settingsWindow.setModules()
        
        self.defaultValues()
        
        info("Stats started in \((startingPoint.timeIntervalSinceNow * -1).rounded(toPlaces: 4)) seconds")
        
        Server.shared.sendEvent(
            modules: modules.filter({ $0.enabled != false && $0.available != false }).map({ $0.config.name }),
            omit: CommandLine.arguments.contains("--omit")
        )
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        modules.forEach{ $0.terminate() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            self.settingsWindow.makeKeyAndOrderFront(self)
        } else {
            self.settingsWindow.setIsVisible(true)
        }
        return true
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if let uri = notification.userInfo?["url"] as? String {
            debug("Downloading new version of app...")
            if let url = URL(string: uri) {
                updater.download(url, doneHandler: { path in
                    updater.install(path: path)
                })
            }
        }
        
        NSUserNotificationCenter.default.removeDeliveredNotification(self.updateNotification)
    }
}
