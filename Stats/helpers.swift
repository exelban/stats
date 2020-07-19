//
//  helpers.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 13/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import os.log
import StatsKit

extension AppDelegate {
    internal func parseArguments() {
        let args = CommandLine.arguments
        
        if args.contains("--reset") {
            os_log(.debug, log: log, "Receive --reset argument. Reseting store (UserDefaults)...")
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
        
        if let mountIndex = args.firstIndex(of: "--mount-path") {
            if args.indices.contains(mountIndex+1) {
                let mountPath = args[mountIndex+1]
                asyncShell("/usr/bin/hdiutil detach \(mountPath)")
                asyncShell("/bin/rm -rf \(mountPath)")
                
                os_log(.debug, log: log, "DMG was unmounted and mountPath deleted")
            }
        }
        
        if let dmgIndex = args.firstIndex(of: "--dmg-path") {
            if args.indices.contains(dmgIndex+1) {
                asyncShell("/bin/rm -rf \(args[dmgIndex+1])")
                
                os_log(.debug, log: log, "DMG was deleted")
            }
        }
    }
    
    internal func parseVersion() {
        let key = "version"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        if !store.exist(key: key) {
            store.reset()
            os_log(.debug, log: log, "Previous version not detected. Current version (%s) set", currentVersion)
        } else {
            let prevVersion = store.string(key: key, defaultValue: "")
            if prevVersion == currentVersion {
                return
            }
            
            if IsNewestVersion(currentVersion: prevVersion, latestVersion: currentVersion) {
                showNotification(title: "Successfully updated", subtitle: "Stats was updated to v\(currentVersion)", id: "updated-from-\(prevVersion)-to-\(currentVersion)"
                )
            }
            
            os_log(.debug, log: log, "Detected previous version %s. Current version (%s) set", prevVersion, currentVersion)
        }
        
        store.set(key: key, value: currentVersion)
    }
    
    internal func defaultValues() {
        if !store.exist(key: "runAtLoginInitialized") {
            store.set(key: "runAtLoginInitialized", value: true)
            LaunchAtLogin.isEnabled = true
        }
        
        if store.exist(key: "dockIcon") {
            let dockIconStatus = store.bool(key: "dockIcon", defaultValue: false) ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }
        
        if updateIntervals(rawValue: store.string(key: "update-interval", defaultValue: updateIntervals.atStart.rawValue)) != .never {
            self.checkForNewVersion()
        }
    }
    
    internal func checkForNewVersion() {
        updater.check() { result, error in
            if error != nil {
                os_log(.error, log: log, "error updater.check(): %s", "\(error!.localizedDescription)")
                return
            }
            
            guard error == nil, let version: version_s = result else {
                os_log(.error, log: log, "download error(): %s", "\(error!.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async(execute: {
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
}
