//
//  Battery.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class BatteryView: NSView {
    var value: Float {
        didSet {
            self.needsDisplay = true
            setNeedsDisplay(self.frame)
        }
    }
    var charging: Bool {
        didSet {
            self.needsDisplay = true
            setNeedsDisplay(self.frame)
        }
    }
    
    override init(frame: NSRect) {
        self.value = 1.0
        self.charging = false
        super.init(frame: frame)
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let x: CGFloat = 4.0
        let w: CGFloat = dirtyRect.size.width - (x * 2)
        let h: CGFloat = 11.0
        let y: CGFloat = (dirtyRect.size.height - h) / 2
        let r: CGFloat = 1.0
        
        let battery = NSBezierPath(roundedRect: NSRect(x: x-1, y: y, width: w-1, height: h), xRadius: r, yRadius: r)
        
        let bPX: CGFloat = x+w-2
        let bPY: CGFloat = (dirtyRect.size.height / 2) - 2
        let batteryPoint = NSBezierPath(roundedRect: NSRect(x: bPX, y: bPY, width: 2, height: 4), xRadius: r, yRadius: r)
        if self.charging {
            NSColor.systemGreen.set()
        } else {
            NSColor.labelColor.set()
        }
        batteryPoint.lineWidth = 1.1
        batteryPoint.stroke()
        batteryPoint.fill()
        
        let maxWidth = w-4.25
        let inner = NSBezierPath(roundedRect: NSRect(x: x+0.75, y: y+1.5, width: maxWidth*CGFloat(self.value), height: h-3), xRadius: 0.5, yRadius: 0.5)
        self.value.batteryColor().set()
        inner.lineWidth = 0
        inner.stroke()
        inner.close()
        inner.fill()
        
        if self.charging {
            NSColor.systemGreen.set()
        } else {
            NSColor.labelColor.set()
        }
        battery.lineWidth = 0.8
        battery.stroke()
    }
    
    func changeValue(value: Float) {
        if self.value != value {
            self.value = value
        }
    }
    
    func setCharging(value: Bool) {
        if self.charging != value {
            self.charging = value
        }
    }
}

class Battery: Module {
    let name: String = "Battery"
    var view: NSView = NSView()
    let defaults = UserDefaults.standard
    
    var active: Observable<Bool>
    var reader: Reader = BatteryReader()
    
    init() {
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.view = BatteryView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
    }
    
    func start() {
        if !self.reader.usage.value.isNaN {
            let value = self.reader.usage!.value
            (self.view as! BatteryView).setCharging(value: value > 0)
            (self.view as! BatteryView).changeValue(value: abs(value))
        }
        
        self.reader.start()
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                (self.view as! BatteryView).setCharging(value: value > 0)
                (self.view as! BatteryView).changeValue(value: abs(value))
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

