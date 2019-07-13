//
//  CPUView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Chart: NSView, Widget {
    var activeModule: Observable<Bool> = Observable(false)
    var size: CGFloat = widgetSize.width + 7
    var labelPadding: CGFloat = 10.0
    var label: Bool = false
    var name: String = ""
    var shortName: String = ""
    var menus: [NSMenuItem] = []
    let defaults = UserDefaults.standard
    
    var height: CGFloat = 0.0
    var points: [Double] {
        didSet {
            self.redraw()
        }
    }
    
    override init(frame: NSRect) {
        self.points = Array(repeating: 0.0, count: 50)
        super.init(frame: CGRect(x: 0, y: 0, width: self.size, height: widgetSize.height))
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func Init() {
        self.label = defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : true
        self.initMenu()
        
        if self.label {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width + labelPadding, height: self.frame.size.height)
        }
    }
    
    func initMenu() {
        let label = NSMenuItem(title: "Label", action: #selector(toggleLabel), keyEquivalent: "")
        label.state = self.label ? NSControl.StateValue.on : NSControl.StateValue.off
        label.target = self
        
        self.menus.append(label)
    }
    
    @objc func toggleLabel(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(self.name)_label")
        self.label = (sender.state == NSControl.StateValue.on)
        
        var width = self.size
        if self.label {
            width = width + labelPadding
        }
        
        self.activeModule << false
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
        self.activeModule << true
        self.redraw()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let lineColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 1.0)
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)
        
        let context = NSGraphicsContext.current!.cgContext
        var xOffset: CGFloat = 4.0
        if label {
            xOffset = xOffset + labelPadding
        }
        let yOffset: CGFloat = 3.0
        if height == 0 {
            height = self.frame.size.height - CGFloat((yOffset * 2))
        }
        
        var xRatio = Double(self.frame.size.width - (xOffset * 2)) / (Double(self.points.count) - 1)
        if label {
            xRatio = Double(self.frame.size.width - (xOffset * 2) + labelPadding) / (Double(self.points.count) - 1)
        }
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return CGFloat((Double(point) * xRatio)) + xOffset
        }
        let columnYPoint = { (point: Int) -> CGFloat in
            return CGFloat((CGFloat(truncating: self.points[point] as NSNumber) * self.height)) + yOffset
        }
        
        let graphPath = NSBezierPath()
        let x: CGFloat = columnXPoint(0)
        let y: CGFloat = columnYPoint(0)
        graphPath.move(to: CGPoint(x: x, y: y))
        
        for i in 1..<self.points.count {
            graphPath.line(to: CGPoint(x: columnXPoint(i), y: columnYPoint(i)))
        }
        
        lineColor.setStroke()
        graphPath.stroke()
        context.saveGState()
        
        let clippingPath = graphPath.copy() as! NSBezierPath
        
        clippingPath.line(to: CGPoint(x: columnXPoint(self.points.count - 1), y: yOffset - 0.5))
        clippingPath.line(to: CGPoint(x: columnXPoint(0), y: yOffset - 0.5))
        clippingPath.close()
        clippingPath.addClip()
        
        gradientColor.setFill()
        let rectPath = NSBezierPath(rect: dirtyRect)
        rectPath.fill()
        
        context.restoreGState()
        
        graphPath.lineWidth = 0.5
        graphPath.stroke()
        
        if !self.label {
            return
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7.2, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.labelColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
    
        let letterHeight = (self.frame.size.height - (widgetSize.margin*2)) / 3
        let letterWidth: CGFloat = 10.0
        
        var yMargin = widgetSize.margin
        for char in self.shortName.reversed() {
            let rect = CGRect(x: widgetSize.margin, y: yMargin, width: letterWidth, height: letterHeight)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)
            
            yMargin += letterHeight
        }
    }
    
    func redraw() {
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
    
    func setValue(data: [Double]) {
        let value: Double = data.first!
        
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
    }
}

class ChartWithValue: Chart {
    var valueLabel: NSTextField = NSTextField()
    var color: Bool = false
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: widgetSize.width + 7, height: widgetSize.height))
        self.wantsLayer = true
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func Init() {
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
        valueLabel.font = NSFont.systemFont(ofSize: 8, weight: .ultraLight)
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
        self.activeModule << false
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
        self.activeModule << true
        self.drawValue()
    }
    
    @objc func toggleColor(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(name)_color")
        self.color = sender.state == NSControl.StateValue.on
    }
}
