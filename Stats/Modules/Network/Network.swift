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
    var reader: Reader = NetworkReader()
    var widgetType: WidgetType = 2.0
    
    let defaults = UserDefaults.standard
    
    init() {
        self.available = Observable(self.reader.available)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Dots
        initMenu()
        initWidget()
    }
    
    func start() {
        self.reader.start()
        
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                (self.view as! Widget).value(value: value)
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
        dots.state = self.widgetType == Widgets.Dots ? NSControl.StateValue.on : NSControl.StateValue.off
        dots.target = self
        
        let arrows = NSMenuItem(title: "Arrows", action: #selector(toggleWidget), keyEquivalent: "")
        arrows.state = self.widgetType == Widgets.Arrows ? NSControl.StateValue.on : NSControl.StateValue.off
        arrows.target = self
        
        let text = NSMenuItem(title: "Text", action: #selector(toggleWidget), keyEquivalent: "")
        text.state = self.widgetType == Widgets.Text ? NSControl.StateValue.on : NSControl.StateValue.off
        text.target = self
        
        let dotsWithText = NSMenuItem(title: "Dots with text", action: #selector(toggleWidget), keyEquivalent: "")
        dotsWithText.state = self.widgetType == Widgets.DotsWithText ? NSControl.StateValue.on : NSControl.StateValue.off
        dotsWithText.target = self
        
        let arrowsWithText = NSMenuItem(title: "Arrows with text", action: #selector(toggleWidget), keyEquivalent: "")
        arrowsWithText.state = self.widgetType == Widgets.ArrowsWithText ? NSControl.StateValue.on : NSControl.StateValue.off
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
            self.stop()
        } else {
            self.start()
        }
    }
    
    @objc func toggleWidget(_ sender: NSMenuItem) {
        var widgetCode: Float = 0.0
        
        switch sender.title {
        case "Dots":
            widgetCode = Widgets.Dots
        case "Arrows":
            widgetCode = Widgets.Arrows
        case "Text":
            widgetCode = Widgets.Text
        case "Dots with text":
            widgetCode = Widgets.DotsWithText
        case "Arrows with text":
            widgetCode = Widgets.ArrowsWithText
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
