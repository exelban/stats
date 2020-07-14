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
import Memory
import Disk
import Net
import Battery
import Sensors

var store: Store = Store()
let updater = macAppUpdater(user: "exelban", repo: "stats")
let systemKit: SystemKit = SystemKit()
var smc: SMCService = SMCService()
var modules: [Module] = [Battery(&store), Network(&store), Sensors(&store, &smc), Disk(&store), Memory(&store), CPU(&store, &smc)].reversed()
var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Stats")

class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    private let settingsWindow: SettingsWindow = SettingsWindow()
    private let updateWindow: UpdateWindow = UpdateWindow()
    
    private let updateNotification = NSUserNotification()
    private let updateActivity = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.updateCheck")
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        
        self.parseArguments()
        
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(checkForNewVersion), name: .checkForUpdates, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCron), name: .changeCronInterval, object: nil)
        
        modules.forEach{ $0.mount() }
        
        self.settingsWindow.setModules()
        
        self.parseVersion()
        self.defaultValues()
        self.updateCron()
        os_log(.info, log: log, "Stats started in %.4f seconds", startingPoint.timeIntervalSinceNow * -1)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if let uri = notification.userInfo?["url"] as? String {
            os_log(.debug, log: log, "Downloading new version of app...")
            if let url = URL(string: uri) {
                updater.download(url)
            }
        }
        
        NSUserNotificationCenter.default.removeDeliveredNotification(self.updateNotification)
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
    
    @objc internal func checkForNewVersion(_ window: Bool = false) {
        updater.check() { result, error in
            if error != nil {
                os_log(.error, log: log, "error updater.check(): %s", "\(error!.localizedDescription)")
                return
            }
            
            guard error == nil, let version: version = result else {
                os_log(.error, log: log, "download error(): %s", "\(error!.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async(execute: {
                if window {
                    os_log(.debug, log: log, "open update window: %s", "\(version.latest)")
                    self.updateWindow.open(version)
                    return
                }
                
                if version.newest {
                    os_log(.debug, log: log, "show update window because new version of app found: %s", "\(version.latest)")
                    
                    self.updateNotification.identifier = "new-version-\(version.latest)"
                    self.updateNotification.title = "New version available"
                    self.updateNotification.subtitle = "Click to install the new version of Stats"
                    self.updateNotification.soundName = NSUserNotificationDefaultSoundName
                    
                    self.updateNotification.hasActionButton = true
                    self.updateNotification.actionButtonTitle = "Install"
                    self.updateNotification.userInfo = ["url": version.url]
                    
                    NSUserNotificationCenter.default.delegate = self
                    NSUserNotificationCenter.default.deliver(self.updateNotification)
                }
            })
        }
    }
    
    @objc private func updateCron() {
        self.updateActivity.invalidate()
        self.updateActivity.repeats = true
        
        guard let updateInterval = updateIntervals(rawValue: store.string(key: "update-interval", defaultValue: updateIntervals.atStart.rawValue)) else {
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
            self.checkForNewVersion(false)
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
    }
}
