//
//  Battery.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import IOKit.ps

class Battery: Module {
    public var name: String = "Battery"
    public var updateInterval: Double = 15
    
    public var enabled: Bool = true
    public var available: Bool {
        get {
            let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
            let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
            return sources.count > 0
        }
    }
    
    public var readers: [Reader] = []
    public var task: Repeater?
    
    public var widget: ModuleWidget = ModuleWidget()
    public var popup: ModulePopup = ModulePopup(true)
    public var menu: NSMenuItem = NSMenuItem()
    
    internal let defaults = UserDefaults.standard
    internal var submenu: NSMenu = NSMenu()
    
    internal var cyclesValue: NSTextField = NSTextField()
    internal var stateValue: NSTextField = NSTextField()
    internal var healthValue: NSTextField = NSTextField()
    internal var amperageValue: NSTextField = NSTextField()
    internal var voltageValue: NSTextField = NSTextField()
    internal var temperatureValue: NSTextField = NSTextField()
    internal var powerValue: NSTextField = NSTextField()
    internal var chargingValue: NSTextField = NSTextField()
    internal var levelValue: NSTextField = NSTextField()
    internal var sourceValue: NSTextField = NSTextField()
    internal var timeLabel: NSTextField = NSTextField()
    internal var timeValue: NSTextField = NSTextField()
    
    init() {
        if !self.available { return }
        
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        
        self.initWidget()
        self.initMenu()
        self.initPopup()
        
        readers.append(BatteryReader(self.usageUpdater))
    }
    
    public func start() {
        (readers[0] as! BatteryReader).start()
    }
    
    public func stop() {
        (readers[0] as! BatteryReader).stop()
    }
    
    public func restart() {
        self.stop()
        self.start()
    }
    
    private func usageUpdater(value: BatteryUsage) {
        self.popupUpdater(value: value)
        
        var time = value.timeToEmpty
        if time == 0 && value.timeToCharge != 0 {
            time = value.timeToCharge
        }
        
        if self.widget.view is Widget {
            (self.widget.view as! Widget).setValue(data: [abs(value.level), Double(time)])
            
            if self.widget.view is BatteryWidget && value.level != 100 {
                (self.widget.view as! BatteryWidget).setCharging(value: value.level > 0)
            } else if self.widget.view is BatteryWidget && value.level == 100 {
                (self.widget.view as! BatteryWidget).setCharging(value: false)
            }
        }
    }
}

