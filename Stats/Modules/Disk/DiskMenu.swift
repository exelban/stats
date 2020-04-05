//
//  DiskMenu.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Disk {
    public func initMenu() {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        submenu = NSMenu()
        
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        
        self.disks.list.forEach { (d: diskInfo) in
            let disk = NSMenuItem(title: d.name, action: #selector(toggleDisk), keyEquivalent: "")
            if self.selectedDisk == "" && d.root {
                disk.state = NSControl.StateValue.on
            } else {
                disk.state = self.selectedDisk == d.mediaBSDName ? NSControl.StateValue.on : NSControl.StateValue.off
            }
            disk.target = self
            
            submenu.addItem(disk)
        }
        
        let mini = NSMenuItem(title: "Mini", action: #selector(toggleWidget), keyEquivalent: "")
        mini.state = self.widget.type == Widgets.Mini ? NSControl.StateValue.on : NSControl.StateValue.off
        mini.target = self
        
        let barChart = NSMenuItem(title: "Bar chart", action: #selector(toggleWidget), keyEquivalent: "")
        barChart.state = self.widget.type == Widgets.BarChart ? NSControl.StateValue.on : NSControl.StateValue.off
        barChart.target = self
        
        submenu.addItem(NSMenuItem.separator())
        
        submenu.addItem(mini)
        submenu.addItem(barChart)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.widget.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(generateIntervalMenu())
        
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
        case "Mini":
            widgetCode = Widgets.Mini
        case "Bar chart":
            widgetCode = Widgets.BarChart
        default:
            break
        }
        
        if self.widget.type == widgetCode {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Mini" || item.title == "Bar chart" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(widgetCode, forKey: "\(name)_widget")
        self.widget.type = widgetCode
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
    
    private func generateIntervalMenu() -> NSMenuItem {
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
        var interval: Double = self.updateInterval
        
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
        self.task?.reset(.seconds(interval), restart: self.task!.state.isRunning)
    }
    
    @objc func toggleDisk(_ sender: NSMenuItem) {
        let name: String = sender.title
        let d: diskInfo? = self.disks.getDiskByName(name)
        if d == nil {
            return
        }
        
        if d!.mediaBSDName == self.selectedDisk {
            return
        }
        
        for item in self.submenu.items {
            if self.disks.getDiskByName(item.title) != nil {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = NSControl.StateValue.on
        self.selectedDisk = d!.mediaBSDName
        self.defaults.set(d!.mediaBSDName, forKey: "\(name)_disk")
        menuBar!.reload(name: self.name)
    }
}
