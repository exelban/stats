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
    
    private let cpuMenuBar = NSStatusBar.system.statusItem(withLength: -1)
    private let memoryMenuBar = NSStatusBar.system.statusItem(withLength: -1)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let startingPoint = Date()
        
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
        
        os_log(.info, log: log, "Stats started in %.4f seconds", startingPoint.timeIntervalSinceNow * -1)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        modules.forEach { (m: Module) in
            m.terminate()
        }
    }
}
