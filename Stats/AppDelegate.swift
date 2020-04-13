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

class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Stats")
    
    private var modules: [Module] = []
    private let window: SettingsWindow = SettingsWindow()
    
    private let cpuMenuBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let memoryMenuBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        
        loadModules()
        window.setModules(&self.modules)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleSettingsHandler(_:)), name: .toggleSettings, object: nil)
        
        setVersion()
        os_log(.info, log: log, "Stats started in %.4f seconds", startingPoint.timeIntervalSinceNow * -1)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        modules.forEach { (m: Module) in
            m.terminate()
        }
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
            let module = try CPU(menuBarItem: cpuMenuBar)
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
        let defaults = UserDefaults.standard
        let key = "version"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        if defaults.object(forKey: key) == nil {
            os_log(.info, log: log, "Previous version not detected. Current version (%s) set", currentVersion)
        } else {
            let prevVersion = defaults.string(forKey: key)
            if prevVersion == currentVersion {
                return
            }
            os_log(.info, log: log, "Detected previous version %s. Current version (%s) set", prevVersion!, currentVersion)
        }

        defaults.set(currentVersion, forKey: key)
    }
}
