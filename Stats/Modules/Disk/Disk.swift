//
//  Disk.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Disk: Module {
    public let name: String = "Disk"
    public let shortName: String = "SSD"
    public var view: NSView = NSView()
    public var menu: NSMenuItem = NSMenuItem()
    public var widgetType: WidgetType
    
    public var active: Observable<Bool>
    public var available: Observable<Bool>
    public var tabAvailable: Bool = false
    public var tabInitialized: Bool = false
    public var tabView: NSTabViewItem = NSTabViewItem()
    
    public var reader: Reader = DiskReader()
    public var updateInterval: Int
    
    private var submenu: NSMenu = NSMenu()
    private let defaults = UserDefaults.standard
    
    init() {
        self.available = Observable(true)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        self.updateInterval = defaults.object(forKey: "\(name)_interval") != nil ? defaults.integer(forKey: "\(name)_interval") : 5
        self.reader.setInterval(value: self.updateInterval)
    }
    
    func initTab() {
        self.tabInitialized = true
        self.tabView.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
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
        
        let mini = NSMenuItem(title: "Mini", action: #selector(toggleWidget), keyEquivalent: "")
        mini.state = self.widgetType == Widgets.Mini ? NSControl.StateValue.on : NSControl.StateValue.off
        mini.target = self
        
        let barChart = NSMenuItem(title: "Bar chart", action: #selector(toggleWidget), keyEquivalent: "")
        barChart.state = self.widgetType == Widgets.BarChart ? NSControl.StateValue.on : NSControl.StateValue.off
        barChart.target = self
        
        submenu.addItem(mini)
        submenu.addItem(barChart)
        
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
        self.active << state
        
        if !state {
            self.stop()
        } else {
            self.start()
        }
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
        
        if self.widgetType == widgetCode {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Mini" || item.title == "Bar chart" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(widgetCode, forKey: "\(name)_widget")
        self.widgetType = widgetCode
        self.active << false
        self.initWidget()
        self.initMenu(active: true)
        self.active << true
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
