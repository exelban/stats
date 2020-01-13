//
//  CPU.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

class CPU: Module {
    public let name: String = "CPU"
    public let shortName: String = "CPU"
    public var view: NSView = NSView()
    public var menu: NSMenuItem = NSMenuItem()
    public var active: Bool = true
    public var available: Bool = true
    public var hyperthreading: Observable<Bool>
    public var reader: Reader = CPUReader()
    public var tabView: NSTabViewItem = NSTabViewItem()
    public var tabAvailable: Bool = true
    public var tabInitialized: Bool = false
    public var widgetType: WidgetType
    public var chart: LineChartView = LineChartView()
    public var updateInterval: Int
    
    private let defaults = UserDefaults.standard
    private var submenu: NSMenu = NSMenu()
    
    init() {
        self.active = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.hyperthreading = Observable(defaults.object(forKey: "\(name)_hyperthreading") != nil ? defaults.bool(forKey: "\(name)_hyperthreading") : false)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        self.updateInterval = defaults.object(forKey: "\(name)_interval") != nil ? defaults.integer(forKey: "\(name)_interval") : 1
        
        self.reader.setInterval(value: self.updateInterval)
        if self.widgetType == Widgets.BarChart {
            (self.reader as! CPUReader).perCoreMode = true
            (self.reader as! CPUReader).hyperthreading = self.hyperthreading.value
        }
        
        if !self.available {
            self.reader.stop()
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
        
        let mini = NSMenuItem(title: "Mini", action: #selector(toggleWidget), keyEquivalent: "")
        mini.state = self.widgetType == Widgets.Mini ? NSControl.StateValue.on : NSControl.StateValue.off
        mini.target = self
        
        let chart = NSMenuItem(title: "Chart", action: #selector(toggleWidget), keyEquivalent: "")
        chart.state = self.widgetType == Widgets.Chart ? NSControl.StateValue.on : NSControl.StateValue.off
        chart.target = self
        
        let chartWithValue = NSMenuItem(title: "Chart with value", action: #selector(toggleWidget), keyEquivalent: "")
        chartWithValue.state = self.widgetType == Widgets.ChartWithValue ? NSControl.StateValue.on : NSControl.StateValue.off
        chartWithValue.target = self
        
        let barChart = NSMenuItem(title: "Bar chart", action: #selector(toggleWidget), keyEquivalent: "")
        barChart.state = self.widgetType == Widgets.BarChart ? NSControl.StateValue.on : NSControl.StateValue.off
        barChart.target = self
        
        let hyperthreading = NSMenuItem(title: "Hyperthreading", action: #selector(toggleHyperthreading), keyEquivalent: "")
        hyperthreading.state = self.hyperthreading.value ? NSControl.StateValue.on : NSControl.StateValue.off
        hyperthreading.target = self
        
        submenu.addItem(mini)
        submenu.addItem(chart)
        submenu.addItem(chartWithValue)
        submenu.addItem(barChart)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
        if self.widgetType == Widgets.BarChart {
            submenu.addItem(hyperthreading)
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
        case "Mini":
            widgetCode = Widgets.Mini
        case "Chart":
            widgetCode = Widgets.Chart
        case "Chart with value":
            widgetCode = Widgets.ChartWithValue
        case "Bar chart":
            widgetCode = Widgets.BarChart
        default:
            break
        }
        
        if widgetCode == Widgets.BarChart {
            (self.reader as! CPUReader).perCoreMode = true
        } else {
            (self.reader as! CPUReader).perCoreMode = false
        }
        
        if self.widgetType == widgetCode {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Mini" || item.title == "Chart" || item.title == "Chart with value" || item.title == "Bar chart" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(widgetCode, forKey: "\(name)_widget")
        self.widgetType = widgetCode
        self.initWidget()
        self.initMenu(active: true)
        menuBar!.reload(name: self.name)
    }
    
    @objc func toggleHyperthreading(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_hyperthreading")
        self.hyperthreading << (sender.state == NSControl.StateValue.on)
        (self.reader as! CPUReader).hyperthreading = sender.state == NSControl.StateValue.on
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
