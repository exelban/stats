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
    public var updateInterval: Double = 1
    
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
    
    public let defaults = UserDefaults.standard
    public var submenu: NSMenu = NSMenu()
    
    public var cyclesValue: NSTextField = NSTextField()
    public var stateValue: NSTextField = NSTextField()
    public var healthValue: NSTextField = NSTextField()
    public var amperageValue: NSTextField = NSTextField()
    public var voltageValue: NSTextField = NSTextField()
    public var temperatureValue: NSTextField = NSTextField()
    public var powerValue: NSTextField = NSTextField()
    public var chargingValue: NSTextField = NSTextField()
    public var levelValue: NSTextField = NSTextField()
    public var sourceValue: NSTextField = NSTextField()
    public var timeLabel: NSTextField = NSTextField()
    public var timeValue: NSTextField = NSTextField()
    
    init() {
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        
        self.initWidget()
        self.initMenu()
        self.initPopup()
        
        readers.append(BatteryReader(self.usageUpdater))
        
        self.task = Repeater.init(interval: .seconds(self.updateInterval), observer: { _ in
            self.readers.forEach { reader in
                reader.read()
            }
        })
    }
    
    public func start() {
        if self.task != nil && self.task!.state.isRunning == false {
            self.task!.start()
        }
    }
    
    public func stop() {
        if self.task!.state.isRunning {
            self.task?.pause()
        }
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
            (self.widget.view as! Widget).setValue(data: [abs(value.capacity), Double(time)])
            
            if self.widget.view is BatteryWidget && value.capacity != 100 {
                (self.widget.view as! BatteryWidget).setCharging(value: value.capacity > 0)
            } else if self.widget.view is BatteryWidget && value.capacity == 100 {
                (self.widget.view as! BatteryWidget).setCharging(value: false)
            }
        }
    }
}

