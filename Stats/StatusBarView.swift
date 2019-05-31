//
//  StatusBarView.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class StatusBarView: NSView, NibLoadable {
    @IBOutlet weak var CPUView: NSView!
    @IBOutlet weak var CPUTitleLabel: NSTextField!
    @IBOutlet weak var CPUValueLabel: NSTextField!
    @IBOutlet weak var MemoryView: NSView!
    @IBOutlet weak var MemoryTitleLabel: NSTextField!
    @IBOutlet weak var MemoryValueLabel: NSTextField!
    @IBOutlet weak var DiskView: NSView!
    @IBOutlet weak var DiskTitleLabel: NSTextField!
    @IBOutlet weak var DiskValueLabel: NSTextField!
    
    let defaults = UserDefaults.standard
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    func prepare() {
        if store.cpuUsage.value != 0 {
            self.CPUValueLabel.stringValue = "\(Int(Float(store.cpuUsage.value.roundTo(decimalPlaces: 2))! * 100))%"
            self.CPUValueLabel.textColor = store.cpuUsage.value.usageColor()
        }
        if store.memoryUsage.value != 0 {
            self.MemoryValueLabel.stringValue = "\(Int(Float(store.memoryUsage.value.roundTo(decimalPlaces: 2))! * 100))%"
            self.MemoryValueLabel.textColor = store.memoryUsage.value.usageColor()
        }
        if store.diskUsage.value != 0 {
            self.DiskValueLabel.stringValue = "\(Int(Float(store.diskUsage.value.roundTo(decimalPlaces: 2))! * 100))%"
            self.DiskValueLabel.textColor = store.diskUsage.value.usageColor()
        }
        
        store.cpuUsage.subscribe(observer: self) { (newValue, _) in
            let percentage = Int(Float(newValue.roundTo(decimalPlaces: 2))! * 100)
            self.CPUValueLabel.stringValue = "\(percentage)%"
            if store.colors.value {
                self.CPUValueLabel.textColor = newValue.usageColor()
            }
        }
        store.memoryUsage.subscribe(observer: self) { (newValue, _) in
            let percentage = Int(Float(newValue.roundTo(decimalPlaces: 2))! * 100)
            self.MemoryValueLabel.stringValue = "\(percentage)%"
            if store.colors.value {
                self.MemoryValueLabel.textColor = newValue.usageColor()
            }
        }
        store.diskUsage.subscribe(observer: self) { (newValue, _) in
            let percentage = Int(Float(newValue.roundTo(decimalPlaces: 2))! * 100)
            self.DiskValueLabel.stringValue = "\(percentage)%"
            if store.colors.value {
                self.DiskValueLabel.textColor = newValue.usageColor()
            }
        }
        
        store.cpuStatus.subscribe(observer: self) { (newValue, _) in
            self.CPUView.isHidden = !newValue
        }
        store.memoryStatus.subscribe(observer: self) { (newValue, _) in
            self.MemoryView.isHidden = !newValue
        }
        store.diskStatus.subscribe(observer: self) { (newValue, _) in
            self.DiskView.isHidden = !newValue
        }
        
        store.activeWidgets.subscribe(observer: self) { (newValue, _) in
            self.frame = CGRect(x: 0 , y: 0, width: CGFloat(28 * newValue), height: self.frame.height)
        }
        
        store.colors.subscribe(observer: self) { (newValue, _) in
            if newValue {
                self.CPUValueLabel.textColor = store.cpuUsage.value.usageColor()
                self.MemoryValueLabel.textColor = store.memoryUsage.value.usageColor()
                self.DiskValueLabel.textColor = store.diskUsage.value.usageColor()
            } else {
                self.CPUValueLabel.textColor = NSColor.labelColor
                self.MemoryValueLabel.textColor = NSColor.labelColor
                self.DiskValueLabel.textColor = NSColor.labelColor
            }
        }
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        let cpuStatus = NSMenuItem(title: "CPU", action: #selector(AppDelegate.toggleStatus(_:)), keyEquivalent: "")
        cpuStatus.state = NSControl.StateValue.on
        cpuStatus.isEnabled = true
        
        let memoryStatus = NSMenuItem(title: "Memory", action: #selector(AppDelegate.toggleStatus(_:)), keyEquivalent: "")
        memoryStatus.state = NSControl.StateValue.on
        
        let diskStatus = NSMenuItem(title: "Disk", action: #selector(AppDelegate.toggleStatus(_:)), keyEquivalent: "")
        diskStatus.state = NSControl.StateValue.on
        
        menu.addItem(cpuStatus)
        menu.addItem(memoryStatus)
        menu.addItem(diskStatus)
        
        menu.addItem(NSMenuItem.separator())
        
        let colorStatus = NSMenuItem(title: "Colors", action: #selector(AppDelegate.toggleStatus(_:)), keyEquivalent: "")
        colorStatus.state = store.colors.value ? NSControl.StateValue.on : NSControl.StateValue.off
        menu.addItem(colorStatus)
        
        let runAtLogin = NSMenuItem(title: "Run at login", action: #selector(AppDelegate.toggleStartOnLogin(_:)), keyEquivalent: "")
        if defaults.object(forKey: "startOnLogin") != nil {
            runAtLogin.state = defaults.bool(forKey: "startOnLogin") ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            runAtLogin.state = NSControl.StateValue.on
        }
        menu.addItem(runAtLogin)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Stats", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        return menu
    }
}
