//
//  CPUView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Chart: NSView, Widget {
    var labelPadding: CGFloat = 10.0
    var labelEnabled: Bool = false
    var label: String = ""
    
    var height: CGFloat = 0.0
    var points: [Double] {
        didSet {
            self.redraw()
        }
    }
    
    override init(frame: NSRect) {
        self.points = Array(repeating: 0.0, count: 50)
        super.init(frame: frame)
        self.wantsLayer = true
        self.addSubview(NSView())
        self.labelEnabled = labelForChart.value
        
        if self.labelEnabled {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width + labelPadding, height: self.frame.size.height)
        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let lineColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 1.0)
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)
        
        let context = NSGraphicsContext.current!.cgContext
        var xOffset: CGFloat = 4.0
        if labelEnabled {
            xOffset = xOffset + labelPadding
        }
        let yOffset: CGFloat = 3.0
        if height == 0 {
            height = self.frame.size.height - CGFloat((yOffset * 2))
        }
        
        var xRatio = Double(self.frame.size.width - (xOffset * 2)) / (Double(self.points.count) - 1)
        if labelEnabled {
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
        
        if !self.labelEnabled {
            return
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7.2, weight: .bold),
            NSAttributedString.Key.foregroundColor: NSColor.labelColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
    
        let letterHeight = (self.frame.size.height - (MODULE_MARGIN*2)) / 3
        let letterWidth: CGFloat = 10.0
        
        var yMargin = MODULE_MARGIN
        for char in self.label.reversed() {
            let rect = CGRect(x: MODULE_MARGIN, y: yMargin, width: letterWidth, height: letterHeight)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)
            
            yMargin += letterHeight
        }
    }
    
    func redraw() {
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
    
    func value(value: Double) {
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
    
    func toggleLabel(value: Bool) {
        labelEnabled = value
        if value {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width + labelPadding, height: self.frame.size.height)
        } else {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width - labelPadding, height: self.frame.size.height)
        }
    }
}

class ChartWithValue: Chart {
    var valueLabel: NSTextField = NSTextField()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        
        valueLabel = NSTextField(frame: NSMakeRect(2, MODULE_HEIGHT - 11, self.frame.size.width, 10))
        if labelEnabled {
            valueLabel = NSTextField(frame: NSMakeRect(labelPadding + 2, MODULE_HEIGHT - 11, self.frame.size.width, 10))
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
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func value(value: Double) {
        self.valueLabel.stringValue = "\(Int(Float(value.roundTo(decimalPlaces: 2))! * 100))%"
        self.valueLabel.textColor = value.usageColor()
        
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
    
    override func toggleLabel(value: Bool) {
        labelEnabled = value
        if value {
            valueLabel.frame = NSMakeRect(labelPadding + 2, MODULE_HEIGHT - 11, self.frame.size.width, 10)
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width + labelPadding, height: self.frame.size.height)
        } else {
            valueLabel.frame = NSMakeRect(2, MODULE_HEIGHT - 11, self.frame.size.width, 10)
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width - labelPadding, height: self.frame.size.height)
        }
    }
}
