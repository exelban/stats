//
//  LineChartWithValue.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class ChartWithValue: Chart {
    private var valueLabel: NSTextField = NSTextField()
    private var color: Bool = false
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: widgetSize.width + 7, height: widgetSize.height))
        self.wantsLayer = true
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override  func start() {
        self.label = defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : true
        self.color = defaults.object(forKey: "\(name)_color") != nil ? defaults.bool(forKey: "\(name)_color") : false
        self.initMenu()
        
        if self.label {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width + labelPadding, height: self.frame.size.height)
        }
        self.drawValue()
    }
    
    override func initMenu() {
        let label = NSMenuItem(title: "Label", action: #selector(toggleLabel), keyEquivalent: "")
        label.state = self.label ? NSControl.StateValue.on : NSControl.StateValue.off
        label.target = self
        
        let color = NSMenuItem(title: "Color", action: #selector(toggleColor), keyEquivalent: "")
        color.state = self.color ? NSControl.StateValue.on : NSControl.StateValue.off
        color.target = self
        
        self.menus.append(label)
        self.menus.append(color)
    }
    
    override func setValue(data: [Double]) {
        let value: Double = data.first!
        
        self.valueLabel.stringValue = "\(Int(Float(value.roundTo(decimalPlaces: 2))! * 100))%"
        self.valueLabel.textColor = value.usageColor(color: self.color)
        
        if self.points.count < 50 {
            self.points.append(value)
            return
        }
        
        for (i, _) in self.points.enumerated() {
            if i+1 < self.points.count {
                self.points[i] = self.points[i+1]
            } else {
                self.points[i] = value
            }
        }
        
        self.redraw()
    }
    
    func drawValue () {
        for subview in self.subviews {
            subview.removeFromSuperview()
        }
        
        valueLabel = NSTextField(frame: NSMakeRect(2, widgetSize.height - 11, self.frame.size.width, 10))
        if label {
            valueLabel = NSTextField(frame: NSMakeRect(labelPadding + 2, widgetSize.height - 11, self.frame.size.width, 10))
        }
        valueLabel.textColor = NSColor.red
        valueLabel.isEditable = false
        valueLabel.isSelectable = false
        valueLabel.isBezeled = false
        valueLabel.wantsLayer = true
        valueLabel.textColor = .labelColor
        valueLabel.backgroundColor = .controlColor
        valueLabel.canDrawSubviewsIntoLayer = true
        valueLabel.alignment = .natural
        valueLabel.font = NSFont.systemFont(ofSize: 8, weight: .light)
        valueLabel.stringValue = ""
        valueLabel.addSubview(NSView())
        
        self.height = 7.0
        self.addSubview(valueLabel)
    }
    
    @objc override func toggleLabel(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(self.name)_label")
        self.label = (sender.state == NSControl.StateValue.on)
        
        var width = self.size
        if self.label {
            width = width + labelPadding
        }
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
        self.drawValue()
        menuBar!.refresh()
    }
    
    @objc func toggleColor(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_color")
        self.color = sender.state == NSControl.StateValue.on
    }
}
