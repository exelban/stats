//
//  Disk.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Disk: Module {
    let name: String = "Disk"
    let shortName: String = "SSD"
    var view: NSView = NSView()
    var menu: NSMenuItem = NSMenuItem()
    var submenu: NSMenu = NSMenu()
    let defaults = UserDefaults.standard
    var widgetType: WidgetType
    
    var active: Observable<Bool>
    var available: Observable<Bool>
    var viewAvailable: Bool = false
    var tabView: NSTabViewItem = NSTabViewItem()
    
    var reader: Reader = DiskReader()
    
    @IBOutlet weak var value: NSTextField!
    
    init() {
        self.available = Observable(true)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        
        self.initWidget()
        self.initMenu()
        initTab()
    }
    
    func initTab() {
        self.tabView.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
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
        
        menu.submenu = submenu
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
        self.initMenu()
        self.active << true
    }
}
