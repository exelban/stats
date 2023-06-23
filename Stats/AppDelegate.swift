//
//  AppDelegate.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

import Kit
import UserNotifications

import CPU
import RAM
import Disk
import Net
import Battery
import Sensors
import GPU
import Bluetooth
import Clock

let updater = Updater(github: "exelban/stats", url: "https://api.serhiy.io/v1/stats/release/latest")
var modules: [Module] = [
    CPU(),
    GPU(),
    RAM(),
    Disk(),
    Sensors(),
    Network(),
    Battery(),
    Bluetooth(),
    Clock()
]
let telemetry: Telemetry = Telemetry(&modules)

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    internal let settingsWindow: SettingsWindow = SettingsWindow()
    internal let updateWindow: UpdateWindow = UpdateWindow()
    internal let setupWindow: SetupWindow = SetupWindow()
    internal let updateActivity = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.updateCheck")
    internal var clickInNotification: Bool = false
    internal var menuBarItem: NSStatusItem? = nil
    internal var combinedView: CombinedView = CombinedView()
    
    internal var pauseState: Bool {
        Store.shared.bool(key: "pause", defaultValue: false)
    }
    
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
        SMCHelper.shared.checkForUpdate()
        self.setup {
            modules.reversed().forEach{ $0.mount() }
            self.settingsWindow.setModules()
        }
        self.defaultValues()
        self.icon()
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForAppPause), name: .pause, object: nil)
        
        info("Stats started in \((startingPoint.timeIntervalSinceNow * -1).rounded(toPlaces: 4)) seconds")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        modules.forEach{ $0.terminate() }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if self.clickInNotification {
            self.clickInNotification = false
            return true
        }
        
        if flag {
            self.settingsWindow.makeKeyAndOrderFront(self)
        } else {
            self.settingsWindow.setIsVisible(true)
        }
        
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        self.clickInNotification = true
        
        if let uri = response.notification.request.content.userInfo["url"] as? String {
            debug("Downloading new version of app...")
            if let url = URL(string: uri) {
                updater.download(url, completion: { path in
                    updater.install(path: path) { error in
                        if let error {
                            showAlert("Error update Stats", error, .critical)
                        }
                    }
                })
            }
        }
        
        completionHandler()
    }
}
