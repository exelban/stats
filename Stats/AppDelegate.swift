//
//  AppDelegate.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import os.log
import ModuleKit
import CPU
import Memory
import StatsKit

let store: Store = Store()
let updater = macAppUpdater(user: "exelban", repo: "stats")
let systemKit: SystemKit = SystemKit()

class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Stats")
    
    private var modules: [Module] = []
    private let window: SettingsWindow = SettingsWindow()
    private var smc: SMCService = SMCService()
    
    private let cpuMenuBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let memoryMenuBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        let result = self.smc.open()
        if result != kIOReturnSuccess {
            os_log(.error, log: log, "open SMC: %s", result)
            NSApp.terminate(nil)
            return
        }
        
        self.loadModules()
        self.window.setModules(&self.modules)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleSettingsHandler(_:)), name: .toggleSettings, object: nil)
        
        self.setVersion()
        self.defaultValues()
        os_log(.info, log: log, "Stats started in %.4f seconds", startingPoint.timeIntervalSinceNow * -1)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        self.modules.forEach { (m: Module) in
            m.terminate()
        }
        _ = self.smc.close()
    }
    
    @objc func toggleSettingsHandler(_ notification: Notification) {
        if !self.window.isVisible {
            self.window.setIsVisible(true)
            self.window.makeKeyAndOrderFront(nil)
        }
        
        if let name = notification.userInfo?["module"] as? String {
            self.window.openMenu(name)
        }
    }
    
    private func loadModules() {
        do {
            os_log(.debug, log: log, "Starting CPU module initialization...")
            let module = try CPU(menuBarItem: cpuMenuBar, smc: &smc)
            os_log(.debug, log: log, "Successfully initialize %s module with availability: %d", "\(type(of: module))", module.available)
            
            if module.available {
                self.modules.append(module)
            }
        } catch {
            os_log(.error, log: log, "%s", error.localizedDescription)
        }
        
        do {
            os_log(.debug, log: log, "Starting Memory module initialization...")
            let module = try Memory(menuBarItem: memoryMenuBar)
            os_log(.debug, log: log, "Successfully initialize %s module with availability: %d", "\(type(of: module))", module.available)
            
            if module.available {
                self.modules.append(module)
            }
        } catch {
            os_log(.error, log: log, "%s", error.localizedDescription)
        }
    }
    
    private func setVersion() {
        let key = "version"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        if !store.exist(key: key) {
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
    
    private func defaultValues() {
        if !store.exist(key: "runAtLoginInitialized") {
            store.set(key: "runAtLoginInitialized", value: true)
            LaunchAtLogin.isEnabled = true
        }
        
        if store.exist(key: "dockIcon") {
            let dockIconStatus = store.bool(key: "dockIcon", defaultValue: false) ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }
        
        if store.bool(key: "checkUpdatesOnLogin", defaultValue: false) {
            updater.check() { result, error in
                if error != nil {
                    os_log(.error, log: self.log, "error updater.check(): %s", "\(error!.localizedDescription)")
                    return
                }

                guard error == nil, let version: version = result else {
                    os_log(.error, log: self.log, "download error(): %s", "\(error!.localizedDescription)")
                    return
                }

                if version.newest {
                    DispatchQueue.main.async(execute: {
                        print("new version detected, open updater window!")
//                        let updatesVC: NSWindowController? = NSStoryboard(name: "Updates", bundle: nil).instantiateController(withIdentifier: "UpdatesVC") as? NSWindowController
//                        updatesVC?.window?.center()
//                        updatesVC?.window?.level = .floating
//                        updatesVC!.showWindow(self)
                    })
                }
            }
        }
    }
}
