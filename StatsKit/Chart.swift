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

public class Chart: NSView {
    internal var points: [Double] = Array(repeating: 0.0, count: 60)
//    internal var points: [Double] = []
    
    public override init(frame: NSRect) {
        super.init(frame: frame)

//        for _ in 0..<60 {
//            points.append(Double(CGFloat(Float(arc4random()) / Float(UINT32_MAX))))
//        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let lineColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 1.0)
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)
        
        let context = NSGraphicsContext.current!.cgContext
        let xOffset: CGFloat = 4.0
        let yOffset: CGFloat = 3.0
        let height: CGFloat = self.frame.size.height - CGFloat((yOffset * 2))
        let xRatio = Double(self.frame.size.width - (xOffset * 2)) / (Double(self.points.count) - 1)
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return CGFloat((Double(point) * xRatio)) + xOffset
        }
        let columnYPoint = { (point: Int) -> CGFloat in
            return CGFloat((CGFloat(truncating: self.points[point] as NSNumber) * height)) + yOffset
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
    
    public func addValue(_ value: Double) {
        self.points.remove(at: 0)
        self.points.append(value)
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}
