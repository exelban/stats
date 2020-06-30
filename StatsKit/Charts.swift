//
//  Chart.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 17/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public enum chart_t: Int {
    case line = 0
    case bar = 1
    
    init?(value: Int) {
        self.init(rawValue: value)
    }
}

public class LineChartView: NSView {
    public var points: [Double]? = nil
    public var transparent: Bool = true
    
    public var color: NSColor = NSColor.controlAccentColor
    
    public init(frame: NSRect, num: Int) {
        self.points = Array(repeating: 0, count: num)
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if self.points?.count == 0 {
            return
        }
        
        let lineColor: NSColor = self.color
        var gradientColor: NSColor = self.color.withAlphaComponent(0.5)
        if !self.transparent {
            gradientColor = self.color.withAlphaComponent(0.8)
        }
        
        let context = NSGraphicsContext.current!.cgContext
        context.setShouldAntialias(true)
        let height: CGFloat = self.frame.size.height - self.frame.origin.y - 0.5
        let xRatio: CGFloat = self.frame.size.width / CGFloat(self.points!.count)
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return (CGFloat(point) * xRatio) + dirtyRect.origin.x
        }
        let columnYPoint = { (point: Int) -> CGFloat in
            return CGFloat((CGFloat(truncating: self.points![point] as NSNumber) * height)) + dirtyRect.origin.y + 0.5
        }
        
        let linePath = NSBezierPath()
        let x: CGFloat = columnXPoint(0)
        let y: CGFloat = columnYPoint(0)
        linePath.move(to: CGPoint(x: x, y: y))
        
        for i in 1..<self.points!.count {
            linePath.line(to: CGPoint(x: columnXPoint(i), y: columnYPoint(i)))
        }
        
        lineColor.setStroke()
        
        context.saveGState()
        
        let underLinePath = linePath.copy() as! NSBezierPath
        
        underLinePath.line(to: CGPoint(x: columnXPoint(self.points!.count - 1), y: 0))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: 0))
        underLinePath.close()
        underLinePath.addClip()
        
        gradientColor.setFill()
        let rectPath = NSBezierPath(rect: dirtyRect)
        rectPath.fill()
        
        context.restoreGState()
        
        linePath.stroke()
        linePath.lineWidth = 0.5
    }
    
    public func addValue(_ value: Double) {
        self.points!.remove(at: 0)
        self.points!.append(value)
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
}
