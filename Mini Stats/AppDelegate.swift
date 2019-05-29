//
//  AppDelegate.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(84))
    let statusBarView: StatusBarView = StatusBarView.createFromNib()!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.statusItem.length = CGFloat(28 * store.activeWidgets.value)
        
        let _ = CpuUsage()
        let _ = MemoryUsage()
        let _ = DiskUsage()
        
        if let button = statusItem.button {
            button.addSubview(statusBarView)
        }
        statusItem.menu = statusBarView.buildMenu()
        
        store.activeWidgets.subscribe(observer: self) { (newValue, oldValue) in
            self.statusItem.length = CGFloat(28 * newValue)
            
            if let button = self.statusItem.button {
                if newValue == 0 {
                    self.statusItem.length = NSStatusItem.squareLength
                    for view in button.subviews {
                        view.removeFromSuperview()
                    }
                    button.image = NSImage(named:NSImage.Name("tray_icon"))
                } else {
                    button.image = nil
                    button.addSubview(self.statusBarView)
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    @objc func toggleStatus(_ sender : NSMenuItem) {
        let status = sender.state != NSControl.StateValue.on
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        
        switch sender.title {
        case "CPU":
            store.cpuStatus << status
        case "Memory":
            store.memoryStatus << status
        case "Disk":
            store.diskStatus << status
        case "Colors":
            store.colors << status
            return
        default: break
        }
        
        store.activeWidgets << (status ? store.activeWidgets.value+1 : store.activeWidgets.value-1)
    }
}
