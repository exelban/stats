//
//  Battery.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Battery: Module {
    let name: String = "Battery"
    let shortName: String = ""
    var view: NSView = NSView()
    var menu: NSMenuItem = NSMenuItem()
    var submenu: NSMenu = NSMenu()
    var active: Observable<Bool>
    var available: Observable<Bool>
    var color: Observable<Bool>
    var label: Observable<Bool>
    var reader: Reader = BatteryReader()
    
    let defaults = UserDefaults.standard
    var widgetType: WidgetType = Widgets.Mini
    let percentageView: Observable<Bool>
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.percentageView = Observable(defaults.object(forKey: "\(self.name)_percentage") != nil ? defaults.bool(forKey: "\(self.name)_percentage") : false)
        self.color = Observable(defaults.object(forKey: "\(name)_color") != nil ? defaults.bool(forKey: "\(name)_color") : false)
        self.label = Observable(defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : false)
        self.view = BatteryView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        initMenu()
        initWidget()
    }
    
    func start() {
        if !self.reader.value.value.isNaN {
            let value = self.reader.value!.value
            (self.view as! BatteryView).setCharging(value: value > 0)
            (self.view as! Widget).value(value: abs(value))
        }
        
        self.reader.start()
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                (self.view as! BatteryView).setCharging(value: value > 0)
                (self.view as! Widget).value(value: abs(value))
            }
        }
    }
    
    func initWidget() {
        self.active << false
        (self.view as! BatteryView).setPercentage(value: self.percentageView.value)
        self.active << true
    }
    
    func initMenu() {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        submenu = NSMenu()
        
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        menu.isEnabled = true
        
        let percentage = NSMenuItem(title: "Percentage", action: #selector(togglePercentage), keyEquivalent: "")
        percentage.state = defaults.bool(forKey: "\(self.name)_percentage") ? NSControl.StateValue.on : NSControl.StateValue.off
        percentage.target = self
        
        let color = NSMenuItem(title: "Color", action: #selector(toggleColor), keyEquivalent: "")
        color.state = defaults.bool(forKey: "\(name)_color") ? NSControl.StateValue.on : NSControl.StateValue.off
        color.target = self
        
        submenu.addItem(percentage)
        submenu.addItem(color)
        
        menu.submenu = submenu
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
    
    @objc func togglePercentage(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: "\(self.name)_percentage")
        self.percentageView << state
        self.initWidget()
    }
    
    @objc func toggleColor(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_color")
        self.color << (sender.state == NSControl.StateValue.on)
    }
}

