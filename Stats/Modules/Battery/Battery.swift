//
//  Battery.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Battery: Module {
    public let name: String = "Battery"
    public let shortName: String = ""
    public var view: NSView = NSView()
    public var menu: NSMenuItem = NSMenuItem()
    public var active: Observable<Bool>
    public var available: Observable<Bool>
    public var reader: Reader = BatteryReader()
    public var viewAvailable: Bool = true
    public var tabView: NSTabViewItem = NSTabViewItem()
    
    public var widgetType: WidgetType = Widgets.Mini
    public let percentageView: Observable<Bool>
    
    private let defaults = UserDefaults.standard
    private var submenu: NSMenu = NSMenu()
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.percentageView = Observable(defaults.object(forKey: "\(self.name)_percentage") != nil ? defaults.bool(forKey: "\(self.name)_percentage") : false)
        self.view = BatteryWidget(frame: NSMakeRect(0, 0, widgetSize.width, widgetSize.height))
        initMenu(active: self.active.value)
        initWidget()
        initTab()
    }
    
    func start() {
        if !self.reader.value.value.isEmpty {
            let value = self.reader.value!.value
            (self.view as! BatteryWidget).setCharging(value: value.first! > 0)
            (self.view as! Widget).setValue(data: [abs(value.first!)])
        }
        
        self.reader.start()
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isEmpty {
                (self.view as! BatteryWidget).setCharging(value: value.first! > 0)
                (self.view as! Widget).setValue(data: [abs(value.first!)])
            }
        }
    }
    
    func initWidget() {
        (self.view as! BatteryWidget).setPercentage(value: self.percentageView.value)
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
        menu.isEnabled = true
        
        let percentage = NSMenuItem(title: "Percentage", action: #selector(togglePercentage), keyEquivalent: "")
        percentage.state = defaults.bool(forKey: "\(self.name)_percentage") ? NSControl.StateValue.on : NSControl.StateValue.off
        percentage.target = self
        
        if let view = self.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        submenu.addItem(percentage)
        
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
            menu.submenu = nil
            self.stop()
        } else {
            menu.submenu = submenu
            self.start()
        }
    }
    
    @objc func togglePercentage(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: "\(self.name)_percentage")
        self.percentageView << state
        self.active << false
        self.initWidget()
        self.active << true
    }
}

