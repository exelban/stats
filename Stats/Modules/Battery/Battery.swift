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
    var reader: Reader = BatteryReader()
    
    let defaults = UserDefaults.standard
    var widgetType: WidgetType = Widgets.Mini
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.view = BatteryView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        initMenu()
    }
    
    func start() {
        if !self.reader.usage.value.isNaN {
            let value = self.reader.usage!.value
            (self.view as! BatteryView).setCharging(value: value > 0)
            (self.view as! Widget).value(value: abs(value))
        }
        
        self.reader.start()
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                (self.view as! BatteryView).setCharging(value: value > 0)
                (self.view as! Widget).value(value: abs(value))
            }
        }
    }
    
    func initMenu() {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        menu.isEnabled = true
    }
    
    @objc func toggle(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: name)
        self.active << state
        
        if !state {
            self.stop()
        } else {
            self.start()
        }
    }
}

