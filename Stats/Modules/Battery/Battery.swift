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
    public var active: Observable<Bool>
    public var available: Observable<Bool>
    public var reader: Reader = BatteryReader()
    public var tabAvailable: Bool = true
    public var tabInitialized: Bool = false
    public var tabView: NSTabViewItem = NSTabViewItem()
    
    public var widgetType: WidgetType = Widgets.Battery
    public let percentageView: Observable<Bool>
    public let timeView: Observable<Bool>
    
    private let defaults = UserDefaults.standard
    private var submenu: NSMenu = NSMenu()
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.percentageView = Observable(defaults.object(forKey: "\(self.name)_percentage") != nil ? defaults.bool(forKey: "\(self.name)_percentage") : false)
        self.timeView = Observable(defaults.object(forKey: "\(self.name)_time") != nil ? defaults.bool(forKey: "\(self.name)_time") : false)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Battery
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
        
        if active {
            menu.submenu = submenu
        }
    }
    
    @objc func toggle(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: name)
        self.active << state
        
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
        menuBar!.updateWidget(name: self.name)
    }
}

