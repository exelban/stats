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
    var view: NSView = NSView()
    let defaults = UserDefaults.standard
    
    var active: Observable<Bool>
    var reader: Reader = CPUReader()
    
    init() {
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.view = ChartView(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
    }
    
    func start() {
        if !self.reader.usage.value.isNaN {
            (self.view as! ChartView).value(value: self.reader.usage!.value)
        }
        
        self.reader.start()
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                (self.view as! ChartView).value(value: value)
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
