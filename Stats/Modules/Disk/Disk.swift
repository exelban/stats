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
    var color: Observable<Bool>
    var label: Observable<Bool>
    
    var reader: Reader = DiskReader()
    
    @IBOutlet weak var value: NSTextField!
    
    init() {
        self.available = Observable(true)
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.widgetType = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        self.color = Observable(defaults.object(forKey: "\(name)_color") != nil ? defaults.bool(forKey: "\(name)_color") : false)
        self.label = Observable(defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : false)
        
        self.initMenu()
        self.initWidget()
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
        
        let color = NSMenuItem(title: "Color", action: #selector(toggleColor), keyEquivalent: "")
        color.state = defaults.bool(forKey: "\(name)_color") ? NSControl.StateValue.on : NSControl.StateValue.off
        color.target = self
        
        submenu.addItem(color)
        
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
    
    @objc func toggleColor(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_color")
        self.color << (sender.state == NSControl.StateValue.on)
    }
}
