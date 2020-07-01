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

class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsWindow: SettingsWindow = SettingsWindow()
    private let updateWindow: UpdateWindow = UpdateWindow()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        
        self.parseArguments()
        
        NotificationCenter.default.addObserver(self, selector: #selector(toggleSettingsHandler), name: .toggleSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkForUpdates), name: .checkForUpdates, object: nil)
        
        modules.forEach{ $0.mount() }
        
        self.settingsWindow.setModules()
        
        self.setVersion()
        self.defaultValues()
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
    
    @objc private func toggleSettingsHandler(_ notification: Notification) {
        if !self.settingsWindow.isVisible {
            self.settingsWindow.setIsVisible(true)
            self.settingsWindow.makeKeyAndOrderFront(nil)
        }
        
        if let name = notification.userInfo?["module"] as? String {
            self.settingsWindow.openMenu(name)
        }
    }
    
    @objc private func checkForUpdates(_ notification: Notification) {
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
                os_log(.error, log: log, "open update window: %s", "\(version.latest)")
                self.updateWindow.open(version)
            })
        }
    }
    
    private func setVersion() {
        let key = "version"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        if !store.exist(key: key) {
            store.reset()
            os_log(.info, log: log, "Previous version not detected. Current version (%s) set", currentVersion)
        } else {
            let prevVersion = store.string(key: key, defaultValue: "")
            if prevVersion == currentVersion {
                return
            }
            os_log(.info, log: log, "Detected previous version %s. Current version (%s) set", prevVersion, currentVersion)
        }
        
        store.set(key: key, value: currentVersion)
    }
    
    private func parseArguments() {
        let args = CommandLine.arguments
        
        if args.contains("--reset") {
            os_log(.info, log: log, "Receive --reset argument. Reseting store (UserDefaults)...")
            store.reset()
        }
        
        if let disableIndex = args.firstIndex(of: "--disable") {
            if args.indices.contains(disableIndex+1) {
                let disableModules = args[disableIndex+1].split(separator: ",")
                
                disableModules.forEach { (moduleName: Substring) in
                    if let module = modules.first(where: { $0.config.name.lowercased() == moduleName.lowercased()}) {
                        module.unmount()
                    }
                }
            }
        }
    }
    
    private func defaultValues() {
        if !store.exist(key: "runAtLoginInitialized") {
            store.set(key: "runAtLoginInitialized", value: true)
            LaunchAtLogin.isEnabled = true
        }
        
        if store.exist(key: "dockIcon") {
            let dockIconStatus = store.bool(key: "dockIcon", defaultValue: false) ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }
        
        if store.bool(key: "checkUpdatesOnLogin", defaultValue: true) {
            updater.check() { result, error in
                if error != nil {
                    os_log(.error, log: log, "error updater.check(): %s", "\(error!.localizedDescription)")
                    return
                }
                
                guard error == nil, let version: version = result else {
                    os_log(.error, log: log, "download error(): %s", "\(error!.localizedDescription)")
                    return
                }
                
                if version.newest {
                    DispatchQueue.main.async(execute: {
                        os_log(.error, log: log, "show update window because new version of app found: %s", "\(version.latest)")
                        self.updateWindow.open(version)
                    })
                }
            }
        }
    }
}
