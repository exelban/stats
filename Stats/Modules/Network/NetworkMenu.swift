//
//  NetworkMenu.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Network {
    public func initMenu() {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        submenu = NSMenu()
        
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        
        let dots = NSMenuItem(title: "Dots", action: #selector(toggleWidget), keyEquivalent: "")
        dots.state = self.widget.type == Widgets.NetworkDots ? NSControl.StateValue.on : NSControl.StateValue.off
        dots.target = self
        
        let arrows = NSMenuItem(title: "Arrows", action: #selector(toggleWidget), keyEquivalent: "")
        arrows.state = self.widget.type == Widgets.NetworkArrows ? NSControl.StateValue.on : NSControl.StateValue.off
        arrows.target = self
        
        let text = NSMenuItem(title: "Text", action: #selector(toggleWidget), keyEquivalent: "")
        text.state = self.widget.type == Widgets.NetworkText ? NSControl.StateValue.on : NSControl.StateValue.off
        text.target = self
        
        let dotsWithText = NSMenuItem(title: "Dots with text", action: #selector(toggleWidget), keyEquivalent: "")
        dotsWithText.state = self.widget.type == Widgets.NetworkDotsWithText ? NSControl.StateValue.on : NSControl.StateValue.off
        dotsWithText.target = self
        
        let arrowsWithText = NSMenuItem(title: "Arrows with text", action: #selector(toggleWidget), keyEquivalent: "")
        arrowsWithText.state = self.widget.type == Widgets.NetworkArrowsWithText ? NSControl.StateValue.on : NSControl.StateValue.off
        arrowsWithText.target = self
        
        let chart = NSMenuItem(title: "Chart", action: #selector(toggleWidget), keyEquivalent: "")
        chart.state = self.widget.type == Widgets.NetworkChart ? NSControl.StateValue.on : NSControl.StateValue.off
        chart.target = self
        
        submenu.addItem(dots)
        submenu.addItem(arrows)
        submenu.addItem(text)
        submenu.addItem(dotsWithText)
        submenu.addItem(arrowsWithText)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.widget.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
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
        
        if self.widget.type == widgetCode {
            return
        }
        
        for item in self.submenu.items {
            if item.title == "Dots" || item.title == "Arrows" || item.title == "Text" || item.title == "Dots with text" || item.title == "Arrows with text" || item.title == "Chart" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(widgetCode, forKey: "\(name)_widget")
        self.widget.type = widgetCode
        initWidget()
        menuBar!.reload(name: self.name)
    }
}
