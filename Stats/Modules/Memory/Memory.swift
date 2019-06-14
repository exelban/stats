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
    var colors: Bool = false
    var view: NSView = NSView()
    let defaults = UserDefaults.standard
    
    var active: Observable<Bool>
    var reader: Reader = MemoryReader()
    
    @IBOutlet weak var value: NSTextField!
    
    init() {
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.view = loadViewFromNib()
    }
    
    func start() {
        if !self.reader.usage.value.isNaN {
            self.value.stringValue = "\(Int(Float(self.reader.usage.value.roundTo(decimalPlaces: 2))! * 100))%"
            self.value.textColor = self.reader.usage.value.usageColor()
        }
        
        self.reader.start()
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                self.value.stringValue = "\(Int(Float(value.roundTo(decimalPlaces: 2))! * 100))%"
                self.value.textColor = value.usageColor()
            }
        }
    }
    
    func menu() -> NSMenuItem {
        let menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        menu.isEnabled = true
        return menu
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
}
