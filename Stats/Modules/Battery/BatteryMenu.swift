//
//  BatteryMenu.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Battery {
    public func initMenu() {
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
        percentage.state = self.widget.type == Widgets.BatteryPercentage ? NSControl.StateValue.on : NSControl.StateValue.off
        percentage.target = self
        
        let time = NSMenuItem(title: "Time", action: #selector(toggleWidget), keyEquivalent: "")
        time.state = self.widget.type == Widgets.BatteryTime ? NSControl.StateValue.on : NSControl.StateValue.off
        time.target = self
        
        submenu.addItem(percentage)
        submenu.addItem(time)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.widget.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
        if self.enabled {
            menu.submenu = submenu
        }
    }
    
    @objc func toggle(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: name)
        self.enabled = state
        menuBar!.reload(name: self.name)
        
        if !state {
            menu.submenu = nil
        } else {
            menu.submenu = submenu
        }
        
        self.restart()
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
        
        if self.widget.type == widgetCode {
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
        self.widget.type = widgetCode
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
}
