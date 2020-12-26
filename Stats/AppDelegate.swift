//
//  AppDelegate.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import os.log
import StatsKit
import ModuleKit
import CPU
import RAM
import Disk
import Net
import Battery
import Sensors
import GPU
import Fans

var store: Store = Store()
let updater = macAppUpdater(user: "exelban", repo: "stats")
var smc: SMCService = SMCService()
var modules: [Module] = [
    Battery(&store),
    Network(&store),
    Fans(&store, &smc),
    Sensors(&store, &smc),
    Disk(&store),
    RAM(&store),
    GPU(&store, &smc),
    CPU(&store, &smc),
].reversed()
var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Stats")

class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    internal let settingsWindow: SettingsWindow = SettingsWindow()
    internal let updateNotification = NSUserNotification()
    
    private let updateActivity = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.updateCheck")
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        print("------------", startingPoint, "------------", to: &Log.log)
        
        self.parseArguments()
        
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateCron), name: .changeCronInterval, object: nil)
        
        modules.forEach{ $0.mount() }
        
        self.settingsWindow.setModules()
        
        self.parseVersion()
        self.defaultValues()
        self.updateCron()
        os_log(.info, log: log, "Stats started in %.4f seconds", startingPoint.timeIntervalSinceNow * -1)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        modules.forEach{ $0.terminate() }
        _ = smc.close()
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
            os_log(.debug, log: log, "Downloading new version of app...")
            if let url = URL(string: uri) {
                updater.download(url, doneHandler: { path in
                    updater.install(path: path)
                })
            }
        }
        
        NSUserNotificationCenter.default.removeDeliveredNotification(self.updateNotification)
    }
    
    @objc private func updateCron() {
        self.updateActivity.invalidate()
        self.updateActivity.repeats = true
        
        guard let updateInterval = AppUpdateIntervals(rawValue: store.string(key: "update-interval", defaultValue: AppUpdateIntervals.atStart.rawValue)) else {
            return
        }
        os_log(.debug, log: log, "Application update interval is '%s'", "\(updateInterval.rawValue)")
        
        switch updateInterval {
        case .oncePerDay: self.updateActivity.interval = 60 * 60 * 24
        case .oncePerWeek: self.updateActivity.interval = 60 * 60 * 24 * 7
        case .oncePerMonth: self.updateActivity.interval = 60 * 60 * 24 * 30
        case .never, .atStart: return
        default: return
        }
        
        self.updateActivity.schedule { (completion: @escaping NSBackgroundActivityScheduler.CompletionHandler) in
            self.checkForNewVersion()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
    }
}
