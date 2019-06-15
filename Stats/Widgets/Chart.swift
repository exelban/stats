//
//  CPUView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Chart: NSView, Widget {
    var height: CGFloat = 0.0
    var points: [Float] {
        didSet {
            self.needsDisplay = true
            setNeedsDisplay(self.frame)
        }
    }
    
    override init(frame: NSRect) {
        self.points = Array(repeating: 0.0, count: 50)
        super.init(frame: frame)
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let lineColor: NSColor = NSColor.selectedMenuItemColor
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)
        
        let context = NSGraphicsContext.current!.cgContext
        let xOffset: CGFloat = 4.0
        let yOffset: CGFloat = 3.0
        if height == 0 {
            height = self.frame.size.height - CGFloat((yOffset * 2))
        }
        let xRatio = Double(self.frame.size.width - (xOffset * 2)) / (Double(self.points.count) - 1)
        
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
    }
    
    func value(value: Float) {
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
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        
        self.wantsLayer = true
        
        valueLabel = NSTextField(frame: NSMakeRect(2, MODULE_HEIGHT - 11, self.frame.size.width, 10))
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
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func value(value: Float) {
        self.valueLabel.stringValue = "\(Int(Float(Float(value).roundTo(decimalPlaces: 2))! * 100))%"
        self.valueLabel.textColor = Float(value).usageColor()
        
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
