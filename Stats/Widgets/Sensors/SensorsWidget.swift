//
//  Sensors.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

class SensorsWidget: NSView, Widget {
    public var name: String = "Sensors"
    public var menus: [NSMenuItem] = []
    
    private var value: [Double] = []
    private var size: CGFloat = 24
    private var topValueView: NSTextField = NSTextField()
    private var bottomValueView: NSTextField = NSTextField()
    private let defaults = UserDefaults.standard
    
    private var color: Bool = true
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: self.size, height: widgetSize.height))
        self.wantsLayer = true
        
        let xOffset: CGFloat = 1.0
        
        let topValueView = NSTextField(frame: NSMakeRect(xOffset, 11, self.frame.size.width, 10))
        topValueView.isEditable = false
        topValueView.isSelectable = false
        topValueView.isBezeled = false
        topValueView.wantsLayer = true
        topValueView.textColor = .labelColor
        topValueView.backgroundColor = .controlColor
        topValueView.canDrawSubviewsIntoLayer = true
        topValueView.alignment = .natural
        topValueView.font = NSFont.systemFont(ofSize: 9, weight: .light)
        topValueView.stringValue = ""
        topValueView.addSubview(NSView())
        
        let bottomValueView = NSTextField(frame: NSMakeRect(xOffset, 2, self.frame.size.width, 10))
        bottomValueView.isEditable = false
        bottomValueView.isSelectable = false
        bottomValueView.isBezeled = false
        bottomValueView.wantsLayer = true
        bottomValueView.textColor = .labelColor
        bottomValueView.backgroundColor = .controlColor
        bottomValueView.canDrawSubviewsIntoLayer = true
        bottomValueView.alignment = .natural
        bottomValueView.font = NSFont.systemFont(ofSize: 9, weight: .light)
        bottomValueView.stringValue = ""
        bottomValueView.addSubview(NSView())
        
        self.topValueView = topValueView
        self.bottomValueView = bottomValueView
        
        self.addSubview(self.topValueView)
        self.addSubview(self.bottomValueView)
    }
    
    func start() {
        self.color = defaults.object(forKey: "\(name)_color") != nil ? defaults.bool(forKey: "\(name)_color") : true
        self.initMenu()
        self.redraw()
    }
    
    func redraw() {
        if self.value.count == 2 {
            self.topValueView.textColor = self.value[0].temperatureColor(color: self.color)
            self.bottomValueView.textColor = self.value[1].temperatureColor(color: self.color)
        }
        self.display()
    }
    
    func setValue(data: [Double]) {
        if self.value != data && data.count == 4 {
            self.value = [data[0], data[2]]
            let unit_1: String = String(UnicodeScalar(Int(data[1]))!)
            let unit_2: String = String(UnicodeScalar(Int(data[3]))!)
            
            self.topValueView.stringValue = "\(Int(self.value[0]))\(unit_1)"
            self.bottomValueView.stringValue = "\(Int(self.value[1]))\(unit_2)"

            self.topValueView.textColor = self.value[0].temperatureColor(color: self.color)
            self.bottomValueView.textColor = self.value[1].temperatureColor(color: self.color)
        }
    }
    
    func initMenu() {
        let color = NSMenuItem(title: "Color", action: #selector(toggleColor), keyEquivalent: "")
        color.state = self.color ? NSControl.StateValue.on : NSControl.StateValue.off
        color.target = self
        
        self.menus.append(color)
    }
    
    @objc func toggleColor(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_color")
        self.color = sender.state == NSControl.StateValue.on

        if self.value.count == 2 {
            self.topValueView.textColor = self.value[0].temperatureColor(color: self.color)
            self.bottomValueView.textColor = self.value[1].temperatureColor(color: self.color)
        }
        
        self.redraw()
    }
}
