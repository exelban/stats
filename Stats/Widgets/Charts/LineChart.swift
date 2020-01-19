//
//  LineChart.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Chart: NSView, Widget {
    public var name: String = ""
    public var menus: [NSMenuItem] = []
    
    internal let defaults = UserDefaults.standard
    internal var size: CGFloat = widgetSize.width + 7
    internal var labelPadding: CGFloat = 10.0
    internal var label: Bool = false
    
    internal var height: CGFloat = 0.0
    internal var points: [Double] = []
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
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
    
    func start() {
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
        
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
        self.redraw()
        menuBar!.refresh()
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
        for char in String(self.name.prefix(3)).uppercased().reversed() {
            let rect = CGRect(x: widgetSize.margin, y: yMargin, width: letterWidth, height: letterHeight)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)

            yMargin += letterHeight
        }
    }
    
    func redraw() {
        self.display()
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
        
        self.redraw()
    }
}
