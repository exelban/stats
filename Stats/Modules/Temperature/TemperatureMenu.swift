//
//  TemperatureMenu.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

struct temperatureMenu {
    let name: String
    let originalName: String
}

struct temperatureGroup {
    let name: String
    var value: String
    var menus: [temperatureMenu]
    
    mutating func addMenu(menu: temperatureMenu) {
        self.menus.append(menu)
    }
    
    func findBy(name: String) -> String {
        let menu = self.menus.first{ $0.name == name }
        if menu != nil {
            return menu!.originalName
        }
        return ""
    }
}

struct temperatureGroupsStruct {
    var list: [Int : temperatureGroup]
    
    mutating func addMenuToGroup(group: String, menu: temperatureMenu) {
        let index = self.list.firstIndex{ $0.value.value == group}
        if index != nil {
            let (k, _) = self.list[index!]
            self.list[k]!.menus.append(menu)
        }
    }
    
    func getOriginalNameOfSensor(name: String) -> String {
        var originalName: String = ""
        
        self.list.forEach{ (key: Int, value: temperatureGroup) in
            if value.findBy(name: name) != "" {
                originalName = value.findBy(name: name)
                return
            }
        }
        
        return originalName
    }
}

var temperatureGroups: temperatureGroupsStruct = temperatureGroupsStruct(list: [
    0: temperatureGroup(name: "CPU", value: "cpu", menus: []),
    1: temperatureGroup(name: "GPU", value: "gpu", menus: []),
    2: temperatureGroup(name: "Memory", value: "mem", menus: []),
    3: temperatureGroup(name: "Termal zones", value: "termal", menus: []),
    4: temperatureGroup(name: "Sensors", value: "sensor", menus: []),
    5: temperatureGroup(name: "PCI", value: "pci", menus: []),
    6: temperatureGroup(name: "Northbridge", value: "northbridge", menus: []),
    7: temperatureGroup(name: "HDD", value: "hdd", menus: []),
    8: temperatureGroup(name: "Thunderbolt", value: "thunderbolt", menus: []),
])

extension Temperature {
    internal func initGroups() {
        var temperatures: Temperatures = Temperatures()
        GetTemperatures(&temperatures)
        
        temperatures.asDictionary.forEach { (arg0) in
            let (key, value) = arg0
            if value as! Double != 0 {
                let group: String = String(key.split(separator: "_")[0])
                
                var name = key.replacingOccurrences(of: "_", with: " ")
                if group == "sensor" || group == "termal" {
                    name = name.replacingOccurrences(of: "\(group) ", with: "")
                }
                
                temperatureGroups.addMenuToGroup(group: group, menu: temperatureMenu(name: name.toUpperCase(), originalName: key))
            }
        }
    }
    
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
        
        let sensor_2: NSMenuItem = NSMenuItem(title: "Sensor #2", action: nil, keyEquivalent: "")
        sensor_2.target = self
        sensor_2.submenu = NSMenu()
        
        for i in 0...temperatureGroups.list.count-1 {
            let group = temperatureGroups.list[i]!
            
            if group.menus.count != 0 {
                sensor_1.submenu!.addItem(NSMenuItem(title: group.name, action: nil, keyEquivalent: ""))
                group.menus.forEach { (m: temperatureMenu) in
                    let menuPoint: NSMenuItem = NSMenuItem(title: m.name, action: #selector(toggleValue1), keyEquivalent: "")
                    menuPoint.state = m.originalName == self.value_1 ? NSControl.StateValue.on : NSControl.StateValue.off
                    menuPoint.target = self
                    sensor_1.submenu!.addItem(menuPoint)
                }
                sensor_1.submenu!.addItem(NSMenuItem.separator())
                
                sensor_2.submenu!.addItem(NSMenuItem(title: group.name, action: nil, keyEquivalent: ""))
                group.menus.forEach { (m: temperatureMenu) in
                    let menuPoint: NSMenuItem = NSMenuItem(title: m.name, action: #selector(toggleValue2), keyEquivalent: "")
                    menuPoint.state = m.originalName == self.value_2 ? NSControl.StateValue.on : NSControl.StateValue.off
                    menuPoint.target = self
                    sensor_2.submenu!.addItem(menuPoint)
                }
                sensor_2.submenu!.addItem(NSMenuItem.separator())
            }
        }
        
        if sensor_1.submenu?.items.count != 0 {
            submenu.addItem(sensor_1)
        }
        if sensor_2.submenu?.items.count != 0 {
            submenu.addItem(sensor_2)
        }
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
    
    @objc func toggleValue1(_ sender: NSMenuItem) {
        let val: String = sender.title
        let originalName = temperatureGroups.getOriginalNameOfSensor(name: val)
        if self.value_1 == originalName {
            return
        }
        
        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            item.state = NSControl.StateValue.off
        }
        
        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(originalName, forKey: "\(name)_value_1")
        self.value_1 = originalName
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
    
    @objc func toggleValue2(_ sender: NSMenuItem) {
        let val: String = sender.title
        let originalName = temperatureGroups.getOriginalNameOfSensor(name: val)
        if self.value_2 == originalName {
            return
        }
        
        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            item.state = NSControl.StateValue.off
        }
        
        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(originalName, forKey: "\(name)_value_2")
        self.value_2 = originalName
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
}
