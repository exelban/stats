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
import Kit
import UserNotifications

extension AppDelegate {
    internal func parseArguments() {
        let args = CommandLine.arguments
        
        if args.contains("--reset") {
            debug("Receive --reset argument. Reseting store (UserDefaults)...")
            Store.shared.reset()
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
                
                debug("DMG was unmounted and mountPath deleted")
            }
        }
        
        if let dmgIndex = args.firstIndex(of: "--dmg-path") {
            if args.indices.contains(dmgIndex+1) {
                asyncShell("/bin/rm -rf \(args[dmgIndex+1])")
                
                debug("DMG was deleted")
            }
        }
    }
    
    internal func parseVersion() {
        let key = "version"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        guard let updateInterval = AppUpdateInterval(rawValue: Store.shared.string(key: "update-interval", defaultValue: AppUpdateInterval.silent.rawValue)) else {
            return
        }
        
        if !Store.shared.exist(key: key) {
            Store.shared.reset()
            debug("Previous version not detected. Current version (\(currentVersion) set")
        } else {
            let prevVersion = Store.shared.string(key: key, defaultValue: "")
            if prevVersion == currentVersion {
                return
            }
            
            if updateInterval != .silent && isNewestVersion(currentVersion: prevVersion, latestVersion: currentVersion) {
                let title: String = localizedString("Successfully updated")
                let subtitle: String = localizedString("Stats was updated to v", currentVersion)
                
                if #available(macOS 10.14, *) {
                    showNotification(
                        title: title,
                        subtitle: subtitle,
                        delegate: self
                    )
                } else {
                    showNSNotification(
                        title: title,
                        subtitle: subtitle
                    )
                }
            }
            
            debug("Detected previous version \(prevVersion). Current version (\(currentVersion) set")
        }
        
        Store.shared.set(key: key, value: currentVersion)
    }
    
    internal func defaultValues() {
        if !Store.shared.exist(key: "runAtLoginInitialized") {
            Store.shared.set(key: "runAtLoginInitialized", value: true)
            LaunchAtLogin.isEnabled = true
        }
        
        if Store.shared.exist(key: "dockIcon") {
            let dockIconStatus = Store.shared.bool(key: "dockIcon", defaultValue: false) ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }
        
        if let updateInterval = AppUpdateInterval(rawValue: Store.shared.string(key: "update-interval", defaultValue: AppUpdateInterval.silent.rawValue)) {
            self.updateActivity.invalidate()
            self.updateActivity.repeats = true
            
            debug("Application update interval is '\(updateInterval.rawValue)'")
            
            switch updateInterval {
            case .oncePerDay: self.updateActivity.interval = 60 * 60 * 24
            case .oncePerWeek: self.updateActivity.interval = 60 * 60 * 24 * 7
            case .oncePerMonth: self.updateActivity.interval = 60 * 60 * 24 * 30
            case .atStart:
                self.checkForNewVersion()
                return
            case .silent:
                self.checkForNewVersion(silent: true)
                return
            default: return
            }
            
            self.updateActivity.schedule { (completion: @escaping NSBackgroundActivityScheduler.CompletionHandler) in
                self.checkForNewVersion()
                completion(NSBackgroundActivityScheduler.Result.finished)
            }
        }
    }
    
    internal func checkForNewVersion(silent: Bool = false) {
        updater.check { result, error in
            if error != nil {
                debug("error updater.check(): \(error!.localizedDescription)")
                return
            }
            
            guard error == nil, let version: version_s = result else {
                debug("download error(): \(error!.localizedDescription)")
                return
            }
            
            if !version.newest {
                return
            }
            
            if silent {
                if let url = URL(string: version.url) {
                    updater.download(url, completion: { path in
                        updater.install(path: path)
                    })
                }
                return
            }
            
            debug("show update view because new version of app found: \(version.latest)")
            
            if #available(OSX 10.14, *) {
                let center = UNUserNotificationCenter.current()
                center.getNotificationSettings { settings in
                    switch settings.authorizationStatus {
                    case .authorized, .provisional:
                        self.showUpdateNotification(version: version)
                    case .denied:
                        self.showUpdateWindow(version: version)
                    case .notDetermined:
                        center.requestAuthorization(options: [.sound, .alert, .badge], completionHandler: { (_, error) in
                            if error == nil {
                                NSApplication.shared.registerForRemoteNotifications()
                                self.showUpdateNotification(version: version)
                            } else {
                                self.showUpdateWindow(version: version)
                            }
                        })
                    @unknown default:
                        self.showUpdateWindow(version: version)
                        error_msg("unknown notification setting")
                    }
                }
            } else {
                self.showUpdateWindow(version: version)
            }
        }
    }
    
    private func showUpdateNotification(version: version_s) {
        debug("show update notification")
        
        let title = localizedString("New version available")
        let subtitle = localizedString("Click to install the new version of Stats")
        let userInfo = ["url": version.url]
        
        if #available(macOS 10.14, *) {
            showNotification(
                title: title,
                subtitle: subtitle,
                userInfo: userInfo,
                delegate: self
            )
        } else {
            showNSNotification(
                title: title,
                subtitle: subtitle,
                userInfo: userInfo
            )
        }
    }
    
    private func showUpdateWindow(version: version_s) {
        debug("show update window")
        
        DispatchQueue.main.async(execute: {
            self.updateWindow.open(version)
        })
    }
}
