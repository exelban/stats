//
//  Memory.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Memory: Module {
    let name: String = "Memory"
    let shortName: String = "MEM"
    var view: NSView = NSView()
    var menu: NSMenuItem = NSMenuItem()
    var submenu: NSMenu = NSMenu()
    var active: Observable<Bool>
    var available: Observable<Bool>
    var reader: Reader = MemoryReader()
    var widgetType: WidgetType
    
    let defaults = UserDefaults.standard
    
    @IBOutlet weak var value: NSTextField!
    
    init() {
        self.available = Observable(true)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        initWidget()
        initMenu()
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
        self.active << false
        self.initWidget()
        self.initMenu()
        self.active << true
    }
}
