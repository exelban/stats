//
//  Network.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 24.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Network: Module {
    var name: String = "Network"
    var shortName: String = "NET"
    var view: NSView = NSView()
    var menu: NSMenuItem = NSMenuItem()
    var submenu: NSMenu = NSMenu()
    var active: Observable<Bool>
    var available: Observable<Bool>
    var color: Observable<Bool>
    var label: Observable<Bool>
    var reader: Reader = NetworkReader()
    var widgetType: WidgetType = 2.0
    
    let defaults = UserDefaults.standard
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.NetworkDots
        self.color = Observable(defaults.object(forKey: "\(name)_color") != nil ? defaults.bool(forKey: "\(name)_color") : false)
        self.label = Observable(defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : false)
        initMenu()
        initWidget()
    }
    
    func start() {
        self.reader.start()
        
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isEmpty {
                (self.view as! Widget).setValue(data: value)
            }
        }
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
        
        submenu.addItem(dots)
        submenu.addItem(arrows)
        submenu.addItem(text)
        submenu.addItem(dotsWithText)
        submenu.addItem(arrowsWithText)
        
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
        default:
            break
        }
        
        if self.widgetType == widgetCode {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Dots" || item.title == "Arrows" || item.title == "Text" || item.title == "Dots with text" || item.title == "Arrows with text" {
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
