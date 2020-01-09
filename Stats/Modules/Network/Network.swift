//
//  Network.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 24.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Network: Module {
    public var name: String = "Network"
    public var shortName: String = "NET"
    public var view: NSView = NSView()
    public var menu: NSMenuItem = NSMenuItem()
    public var active: Observable<Bool>
    public var available: Observable<Bool>
    public var reader: Reader = NetworkReader()
    public var widgetType: WidgetType = 2.0
    public var tabAvailable: Bool = false
    public var tabInitialized: Bool = false
    public var tabView: NSTabViewItem = NSTabViewItem()
    public var updateInterval: Int
    
    private let defaults = UserDefaults.standard
    private var submenu: NSMenu = NSMenu()
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.NetworkDots
        self.updateInterval = defaults.object(forKey: "\(name)_interval") != nil ? defaults.integer(forKey: "\(name)_interval") : 1
        self.reader.setInterval(value: self.updateInterval)
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
        text.frame.origin.x = ((self.tabView.view?.frame.size.width)! - 50) / 2
        text.frame.origin.y = ((self.tabView.view?.frame.size.height)! - 22) / 2
        
        self.tabView.view?.addSubview(text)
        
        self.tabInitialized = true
    }
    
    func start() {
        self.reader.start()
        
        self.reader.value.subscribe(observer: self) { (value, _) in
            if  !value.isEmpty {
                (self.view as! Widget).setValue(data: value)
            }
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
        
        let dots = NSMenuItem(title: "Dots", action: #selector(toggleWidget), keyEquivalent: "")
        dots.state = self.widgetType == Widgets.NetworkDots ? NSControl.StateValue.on : NSControl.StateValue.off
        dots.target = self
        
        let arrows = NSMenuItem(title: "Arrows", action: #selector(toggleWidget), keyEquivalent: "")
        arrows.state = self.widgetType == Widgets.NetworkArrows ? NSControl.StateValue.on : NSControl.StateValue.off
        arrows.target = self
        
        let text = NSMenuItem(title: "Text", action: #selector(toggleWidget), keyEquivalent: "")
        text.state = self.widgetType == Widgets.NetworkText ? NSControl.StateValue.on : NSControl.StateValue.off
        text.target = self
        
        let dotsWithText = NSMenuItem(title: "Dots with text", action: #selector(toggleWidget), keyEquivalent: "")
        dotsWithText.state = self.widgetType == Widgets.NetworkDotsWithText ? NSControl.StateValue.on : NSControl.StateValue.off
        dotsWithText.target = self
        
        let arrowsWithText = NSMenuItem(title: "Arrows with text", action: #selector(toggleWidget), keyEquivalent: "")
        arrowsWithText.state = self.widgetType == Widgets.NetworkArrowsWithText ? NSControl.StateValue.on : NSControl.StateValue.off
        arrowsWithText.target = self
        
        let chart = NSMenuItem(title: "Chart", action: #selector(toggleWidget), keyEquivalent: "")
        chart.state = self.widgetType == Widgets.NetworkChart ? NSControl.StateValue.on : NSControl.StateValue.off
        chart.target = self
        
        submenu.addItem(dots)
        submenu.addItem(arrows)
        submenu.addItem(text)
        submenu.addItem(dotsWithText)
        submenu.addItem(arrowsWithText)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
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
    
    @objc func toggleWidget(_ sender: NSMenuItem) {
        var widgetCode: Float = 0.0
        
        switch sender.title {
        case "Dots":
            widgetCode = Widgets.NetworkDots
        case "Arrows":
            widgetCode = Widgets.NetworkArrows
        case "Text":
            widgetCode = Widgets.NetworkText
        case "Dots with text":
            widgetCode = Widgets.NetworkDotsWithText
        case "Arrows with text":
            widgetCode = Widgets.NetworkArrowsWithText
        case "Chart":
            widgetCode = Widgets.NetworkChart
        default:
            break
        }
        
        if self.widgetType == widgetCode {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Dots" || item.title == "Arrows" || item.title == "Text" || item.title == "Dots with text" || item.title == "Arrows with text" || item.title == "Chart" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(widgetCode, forKey: "\(name)_widget")
        self.widgetType = widgetCode
        self.active << false
        initWidget()
        self.active << true
    }
}
