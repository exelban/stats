//
//  CPU.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class CPU: Module {
    let name: String = "CPU"
    let shortName: String = "CPU"
    var view: NSView = NSView()
    var menu: NSMenuItem = NSMenuItem()
    var submenu: NSMenu = NSMenu()
    var active: Observable<Bool>
    var available: Observable<Bool>
    var hyperthreading: Observable<Bool>
    var reader: Reader = CPUReader()
    var tabView: NSTabViewItem = NSTabViewItem()
    
    var viewAvailable: Bool = true
    
    let defaults = UserDefaults.standard
    var widgetType: WidgetType
    
    init() {
        self.available = Observable(true)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.hyperthreading = Observable(defaults.object(forKey: "\(name)_hyperthreading") != nil ? defaults.bool(forKey: "\(name)_hyperthreading") : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        
        if self.widgetType == Widgets.BarChart {
            (self.reader as! CPUReader).perCoreMode = true
            (self.reader as! CPUReader).hyperthreading = self.hyperthreading.value
            self.reader.read()
        }
        
        initWidget()
        initMenu()
        initTab()
    }
    
    func initTab() {
        self.tabView.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
        
        let text: NSTextField = NSTextField(string: self.name)
        text.isEditable = false
        text.isSelectable = false
        text.isBezeled = false
        text.wantsLayer = true
        text.textColor = .labelColor
        text.canDrawSubviewsIntoLayer = true
        text.alignment = .natural
        text.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        text.frame.origin.x = ((self.tabView.view?.frame.size.width)! - 30) / 2
        text.frame.origin.y = ((self.tabView.view?.frame.size.height)! - 22) / 2
        
        self.tabView.view?.addSubview(text)
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
        self.active << false
        self.initWidget()
        self.initMenu()
        self.active << true
    }
    
    @objc func toggleHyperthreading(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_hyperthreading")
        self.hyperthreading << (sender.state == NSControl.StateValue.on)
        (self.reader as! CPUReader).hyperthreading = sender.state == NSControl.StateValue.on
    }
}
