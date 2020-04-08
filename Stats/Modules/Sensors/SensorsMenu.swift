//
//  SensorsMenu.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Sensors {
    public func initMenu() {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        submenu = NSMenu()
        
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        
        let sensor_1: NSMenuItem = NSMenuItem(title: "Sensor #1", action: nil, keyEquivalent: "")
        sensor_1.target = self
        sensor_1.submenu = NSMenu()
        addSensorsMennu(sensor_1.submenu!, value: self.value_1, action: #selector(toggleValue1))

        let sensor_2: NSMenuItem = NSMenuItem(title: "Sensor #2", action: nil, keyEquivalent: "")
        sensor_2.target = self
        sensor_2.submenu = NSMenu()
        addSensorsMennu(sensor_2.submenu!, value: self.value_2, action: #selector(toggleValue2))
        
        submenu.addItem(sensor_1)
        submenu.addItem(sensor_2)
        
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
    
    private func addSensorsMennu(_ menu: NSMenu, value: String, action: Selector?) {
        var sensorsMenu: NSMenuItem? = generateSensorsMenu(type: SensorType.Temperature, value: value, action: action)
        if sensorsMenu != nil {
            menu.addItem(sensorsMenu!)
        }
        sensorsMenu = generateSensorsMenu(type: SensorType.Voltage, value: value, action: action)
        if sensorsMenu != nil {
            menu.addItem(sensorsMenu!)
        }
        sensorsMenu = generateSensorsMenu(type: SensorType.Power, value: value, action: action)
        if sensorsMenu != nil {
            menu.addItem(sensorsMenu!)
        }
    }
    
    private func generateSensorsMenu(type: SensorType, value: String, action: Selector?) -> NSMenuItem? {
        let list: [Sensor_t] = self.sensors.list.filter{ $0.type == type.rawValue }
        if list.isEmpty {
            return nil
        }
        
        let mainItem: NSMenuItem = NSMenuItem(title: type.rawValue, action: nil, keyEquivalent: "")
        mainItem.target = self
        mainItem.submenu = NSMenu()
        
        var groups: [SensorGroup_t] = []
        list.forEach { (s: Sensor_t) in
            if !groups.contains(s.group) {
                groups.append(s.group)
            }
        }
        groups.sort()
        
        groups.forEach { (g: SensorGroup_t) in
            mainItem.submenu!.addItem(NSMenuItem(title: g, action: nil, keyEquivalent: ""))
            
            list.filter{ $0.group == g }.forEach { (s: Sensor_t) in
                let menuPoint: NSMenuItem = NSMenuItem(title: s.name, action: action, keyEquivalent: "")
                menuPoint.state = s.key == value ? NSControl.StateValue.on : NSControl.StateValue.off
                menuPoint.target = self
                menuPoint.extraString = s.key
                
                mainItem.submenu!.addItem(menuPoint)
            }
            
            mainItem.submenu!.addItem(NSMenuItem.separator())
        }
        
        return mainItem
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
    
    @objc func toggleValue1(_ sender: NSMenuItem) {
        let val: String = sender.extraString
        if self.value_1 == val {
            return
        }

        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            item.state = NSControl.StateValue.off
        }

        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(val, forKey: "\(name)_value_1")
        self.value_1 = val
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
    
    @objc func toggleValue2(_ sender: NSMenuItem) {
        let val: String = sender.extraString
        if self.value_2 == val {
            return
        }

        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            item.state = NSControl.StateValue.off
        }

        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(val, forKey: "\(name)_value_2")
        self.value_2 = val
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
}
