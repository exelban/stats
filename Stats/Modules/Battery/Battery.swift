//
//  Battery.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Battery: Module {
    public let name: String = "Battery"
    public let shortName: String = "BAT"
    public var view: NSView = NSView()
    public var menu: NSMenuItem = NSMenuItem()
    public var active: Bool = true
    public var available: Bool = true
    public var reader: Reader = BatteryReader()
    public var tabAvailable: Bool = true
    public var tabInitialized: Bool = false
    public var tabView: NSTabViewItem = NSTabViewItem()
    public var updateInterval: Int
    
    public var widgetType: WidgetType = Widgets.Battery
    public let percentageView: Observable<Bool>
    public let timeView: Observable<Bool>
    
    private let defaults = UserDefaults.standard
    private var submenu: NSMenu = NSMenu()
    
    init() {
        self.available = self.reader.available
        self.active = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.percentageView = Observable(defaults.object(forKey: "\(self.name)_percentage") != nil ? defaults.bool(forKey: "\(self.name)_percentage") : false)
        self.timeView = Observable(defaults.object(forKey: "\(self.name)_time") != nil ? defaults.bool(forKey: "\(self.name)_time") : false)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Battery
        self.updateInterval = defaults.object(forKey: "\(name)_interval") != nil ? defaults.integer(forKey: "\(name)_interval") : 3
        self.reader.setInterval(value: self.updateInterval)
    }
    
    func start() {
        if !self.reader.value.value.isEmpty {
            let value = self.reader.value!.value
            (self.view as! Widget).setValue(data: [abs(value.first!), value.last!])
        }
        if let view = self.view as? BatteryWidget {
            view.setCharging(value: (self.reader as! BatteryReader).usage.value.ACstatus)
        }
        
        self.reader.start()
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isEmpty {
                (self.view as! Widget).setValue(data: [abs(value.first!), value.last!])
            }
        }
        (self.reader as! BatteryReader).usage.subscribe(observer: self) { (value, _) in
            (self.view as! BatteryWidget).setCharging(value: value.ACstatus)
        }
    }
    
    func initMenu(active: Bool) {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        submenu = NSMenu()
        
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        menu.isEnabled = true
        
        let percentage = NSMenuItem(title: "Percentage", action: #selector(toggleWidget), keyEquivalent: "")
        percentage.state = self.widgetType == Widgets.BatteryPercentage ? NSControl.StateValue.on : NSControl.StateValue.off
        percentage.target = self
        
        let time = NSMenuItem(title: "Time", action: #selector(toggleWidget), keyEquivalent: "")
        time.state = self.widgetType == Widgets.BatteryTime ? NSControl.StateValue.on : NSControl.StateValue.off
        time.target = self
        
        submenu.addItem(percentage)
        submenu.addItem(time)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(generateIntervalMenu())
        
        if active {
            menu.submenu = submenu
        }
    }
    
    @objc func toggle(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: name)
        self.active = state
        menuBar!.reload(name: self.name)
        
        if !state {
            menu.submenu = nil
            self.stop()
        } else {
            menu.submenu = submenu
            self.start()
        }
    }
    
    @objc func toggleWidget(_ sender: NSMenuItem) {
        var widgetCode: Float = 0.0
        
        switch sender.title {
        case "Percentage":
            widgetCode = Widgets.BatteryPercentage
        case "Time":
            widgetCode = Widgets.BatteryTime
        default:
            break
        }
        
        if self.widgetType == widgetCode {
            widgetCode = Widgets.Battery
        }
        
        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            if item.title == "Percentage" || item.title == "Time" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(widgetCode, forKey: "\(name)_widget")
        self.widgetType = widgetCode
        self.initWidget()
        self.initMenu(active: true)
        menuBar!.refresh()
    }
    
    func generateIntervalMenu() -> NSMenuItem {
        let updateInterval = NSMenuItem(title: "Update interval", action: nil, keyEquivalent: "")
        
        let updateIntervals = NSMenu()
        let updateInterval_1 = NSMenuItem(title: "1s", action: #selector(changeInterval), keyEquivalent: "")
        updateInterval_1.state = self.updateInterval == 1 ? NSControl.StateValue.on : NSControl.StateValue.off
        updateInterval_1.target = self
        let updateInterval_2 = NSMenuItem(title: "3s", action: #selector(changeInterval), keyEquivalent: "")
        updateInterval_2.state = self.updateInterval == 3 ? NSControl.StateValue.on : NSControl.StateValue.off
        updateInterval_2.target = self
        let updateInterval_3 = NSMenuItem(title: "5s", action: #selector(changeInterval), keyEquivalent: "")
        updateInterval_3.state = self.updateInterval == 5 ? NSControl.StateValue.on : NSControl.StateValue.off
        updateInterval_3.target = self
        let updateInterval_4 = NSMenuItem(title: "10s", action: #selector(changeInterval), keyEquivalent: "")
        updateInterval_4.state = self.updateInterval == 10 ? NSControl.StateValue.on : NSControl.StateValue.off
        updateInterval_4.target = self
        let updateInterval_5 = NSMenuItem(title: "15s", action: #selector(changeInterval), keyEquivalent: "")
        updateInterval_5.state = self.updateInterval == 15 ? NSControl.StateValue.on : NSControl.StateValue.off
        updateInterval_5.target = self
        
        updateIntervals.addItem(updateInterval_1)
        updateIntervals.addItem(updateInterval_2)
        updateIntervals.addItem(updateInterval_3)
        updateIntervals.addItem(updateInterval_4)
        updateIntervals.addItem(updateInterval_5)
        
        updateInterval.submenu = updateIntervals
        
        return updateInterval
    }
    
    @objc func changeInterval(_ sender: NSMenuItem) {
        var interval: Int = self.updateInterval
        
        switch sender.title {
        case "1s":
            interval = 1
        case "3s":
            interval = 3
        case "5s":
            interval = 5
        case "10s":
            interval = 10
        case "15s":
            interval = 15
        default:
            break
        }
        
        
        if interval == self.updateInterval {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Update interval" {
                for subitem in item.submenu!.items {
                    subitem.state = NSControl.StateValue.off
                }
            }
        }
        
        sender.state = NSControl.StateValue.on
        self.updateInterval = interval
        self.defaults.set(interval, forKey: "\(name)_interval")
        self.reader.setInterval(value: interval)
    }
}

