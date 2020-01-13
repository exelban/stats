//
//  BatteryView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class BatteryWidget: NSView, Widget {
    public var activeModule: Observable<Bool> = Observable(false)
    public var name: String = "Battery"
    public var shortName: String = "BAT"
    public var menus: [NSMenuItem] = []
    public var size: CGFloat = 30
    public var batterySize: CGFloat = 30
    
    private let defaults = UserDefaults.standard
    private var color: Bool = false
    
    public var value: Double {
        didSet {
            self.redraw()
            self.update()
        }
    }
    public var time: Double {
        didSet {
            self.redraw()
            self.update()
        }
    }
    public var charging: Bool {
        didSet {
            self.redraw()
            self.update()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    override init(frame: NSRect) {
        self.value = 0.0
        self.time = 0.0
        self.charging = false
        super.init(frame: CGRect(x: 0, y: 0, width: self.size, height: widgetSize.height))
        self.wantsLayer = true
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func Init() {
        self.color = defaults.object(forKey: "\(name)_color") != nil ? defaults.bool(forKey: "\(name)_color") : false
        self.initMenu()
        self.redraw()
    }
    
    func initMenu() {}
    func update() {}
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var x: CGFloat = 4.0
        let w: CGFloat = self.batterySize - (x * 2)
        let h: CGFloat = 11.0
        let y: CGFloat = (dirtyRect.size.height - h) / 2
        let r: CGFloat = 1.0
        if dirtyRect.size.width != batterySize {
            x += self.size - batterySize
        }
        
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
        
        let maxWidth = w-4
        let inner = NSBezierPath(roundedRect: NSRect(x: x+0.5, y: y+1.5, width: maxWidth*CGFloat(self.value), height: h-3), xRadius: 0.5, yRadius: 0.5)
        self.value.batteryColor(color: self.color).set()
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
    
    func redraw() {
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
    
    func setValue(data: [Double]) {
        let value: Double = data.first!
        let time: Double = data.last!
        if self.value != value {
            self.value = value
        }
        if self.time != time {
            self.time = time
        }
    }
    
    func setCharging(value: Bool) {
        if self.charging != value {
            self.charging = value
        }
    }
    
    func changeWidth(width: CGFloat) {
        self.size = batterySize + width
        self.frame.size.width = self.size
        menuBar!.refresh()
    }
}
