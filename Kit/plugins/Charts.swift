//
//  Chart.swift
//  Kit
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

public struct circle_segment {
    public let value: Double
    public var color: NSColor
    
    public init(value: Double, color: NSColor) {
        self.value = value
        self.color = color
    }
}

public class LineChartView: NSView {
    public var id: String = UUID().uuidString
    
    public var points: [Double]
    public var transparent: Bool = true
    
    public var color: NSColor = controlAccentColor
    
    public init(frame: NSRect, num: Int) {
        self.points = Array(repeating: 0.01, count: num)
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if self.points.isEmpty {
            return
        }
        
        let lineColor: NSColor = self.color
        var gradientColor: NSColor = self.color.withAlphaComponent(0.5)
        if !self.transparent {
            gradientColor = self.color.withAlphaComponent(0.8)
        }
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        let offset: CGFloat = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let height: CGFloat = self.frame.size.height - self.frame.origin.y - offset
        let xRatio: CGFloat = self.frame.size.width / CGFloat(self.points.count)
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return (CGFloat(point) * xRatio) + dirtyRect.origin.x
        }
        let columnYPoint = { (point: Int) -> CGFloat in
            return CGFloat((CGFloat(truncating: self.points[point] as NSNumber) * height)) + dirtyRect.origin.y + offset
        }
        
        let line = NSBezierPath()
        line.move(to: CGPoint(x: columnXPoint(0), y: columnYPoint(0)))
        
        for i in 1..<self.points.count {
            line.line(to: CGPoint(x: columnXPoint(i), y: columnYPoint(i)))
        }
        
        lineColor.setStroke()
        line.lineWidth = offset
        line.stroke()
        
        let underLinePath = line.copy() as! NSBezierPath
        
        underLinePath.line(to: CGPoint(x: columnXPoint(self.points.count), y: offset))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: offset))
        underLinePath.close()
        underLinePath.addClip()
        
        gradientColor.setFill()
        underLinePath.fill()
    }
    
    public func addValue(_ value: Double) {
        self.points.remove(at: 0)
        self.points.append(value)
        
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
}

public class NetworkChartView: NSView {
    public var id: String = UUID().uuidString
    public var base: DataSizeBase = .byte
    public var monohorome: Bool = false
    
    public var points: [(Double, Double)]? = nil
    private var colors: [NSColor] {
        get {
            return self.monohorome ? [MonochromeColor.red, MonochromeColor.blue] : [NSColor.systemRed, NSColor.systemBlue]
        }
    }
    private var minMax: Bool = false
    
    public init(frame: NSRect, num: Int, minMax: Bool = true) {
        self.minMax = minMax
        self.points = Array(repeating: (0, 0), count: num)
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // swiftlint:disable function_body_length
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let points = self.points else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        var uploadMax: Double = points.map{ $0.0 }.max() ?? 0
        var downloadMax: Double = points.map{ $0.1 }.max() ?? 0
        if uploadMax == 0 {
            uploadMax = 1
        }
        if downloadMax == 0 {
            downloadMax = 1
        }
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        let zero: CGFloat = (dirtyRect.height/2) + dirtyRect.origin.y
        let xRatio: CGFloat = (dirtyRect.width + (lineWidth*3)) / CGFloat(points.count)
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return (CGFloat(point) * xRatio) + (dirtyRect.origin.x - lineWidth)
        }
        let uploadYPoint = { (point: Int) -> CGFloat in
            return CGFloat((points[point].0 * Double(dirtyRect.height/2)) / uploadMax) + dirtyRect.origin.y + dirtyRect.height/2 + lineWidth - offset
        }
        let downloadYPoint = { (point: Int) -> CGFloat in
            return (dirtyRect.height/2 + dirtyRect.origin.y + offset - lineWidth) - CGFloat((points[point].1 * Double(dirtyRect.height/2)) / downloadMax)
        }
        
        let uploadlinePath = NSBezierPath()
        uploadlinePath.move(to: CGPoint(x: columnXPoint(0), y: uploadYPoint(0)))
        
        let downloadlinePath = NSBezierPath()
        downloadlinePath.move(to: CGPoint(x: columnXPoint(0), y: downloadYPoint(0)))
        
        for i in 1..<points.count {
            uploadlinePath.line(to: CGPoint(x: columnXPoint(i), y: uploadYPoint(i)))
            downloadlinePath.line(to: CGPoint(x: columnXPoint(i), y: downloadYPoint(i)))
        }
        
        self.colors[0].setStroke()
        uploadlinePath.lineWidth = lineWidth
        uploadlinePath.stroke()
        
        self.colors[1].setStroke()
        downloadlinePath.lineWidth = lineWidth
        downloadlinePath.stroke()
        
        context.saveGState()
        
        var underLinePath = uploadlinePath.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: columnXPoint(points.count), y: zero))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        underLinePath.close()
        underLinePath.addClip()
        self.colors[0].withAlphaComponent(0.5).setFill()
        NSBezierPath(rect: dirtyRect).fill()
        
        context.restoreGState()
        context.saveGState()
        
        underLinePath = downloadlinePath.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: columnXPoint(points.count), y: zero))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        underLinePath.close()
        underLinePath.addClip()
        self.colors[1].withAlphaComponent(0.5).setFill()
        NSBezierPath(rect: dirtyRect).fill()
        
        context.restoreGState()
        
        if self.minMax {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let uploadText = Units(bytes: Int64(uploadMax)).getReadableSpeed(base: self.base)
            let downloadText = Units(bytes: Int64(downloadMax)).getReadableSpeed(base: self.base)
            let uploadTextWidth = uploadText.widthOfString(usingFont: stringAttributes[NSAttributedString.Key.font] as! NSFont)
            let downloadTextWidth = downloadText.widthOfString(usingFont: stringAttributes[NSAttributedString.Key.font] as! NSFont)
            
            var rect = CGRect(x: 1, y: dirtyRect.height - 9, width: uploadTextWidth, height: 8)
            NSAttributedString.init(string: uploadText, attributes: stringAttributes).draw(with: rect)
            
            rect = CGRect(x: 1, y: 2, width: downloadTextWidth, height: 8)
            NSAttributedString.init(string: downloadText, attributes: stringAttributes).draw(with: rect)
        }
    }
    
    public func addValue(upload: Double, download: Double) {
        if self.points == nil {
            return
        }
        
        self.points?.remove(at: 0)
        self.points?.append((upload, download))
        
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
}

public class PieChartView: NSView {
    public var id: String = UUID().uuidString
    
    private var filled: Bool = false
    private var drawValue: Bool = false
    
    private var value: Double? = nil
    private var segments: [circle_segment] = []
    
    public init(frame: NSRect, segments: [circle_segment], filled: Bool = false, drawValue: Bool = false) {
        self.filled = filled
        self.drawValue = drawValue
        self.segments = segments
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = self.filled ? min(rect.width, rect.height) / 2 : 7
        let fullCircle = 2 * CGFloat.pi
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: NSColor.lightGray.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (min(rect.width, rect.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        let startAngle: CGFloat = CGFloat.pi/2
        var previousAngle = startAngle
        
        for segment in segments.reversed() {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * fullCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
        
        if let value = self.value, self.drawValue {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 15, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            let percentage = "\(Int(value*100))%"
            let width: CGFloat = percentage.widthOfString(usingFont: NSFont.systemFont(ofSize: 15))
            let rect = CGRect(x: (self.frame.width-width)/2, y: (self.frame.height-11)/2, width: width, height: 12)
            let str = NSAttributedString.init(string: percentage, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        self.value = value
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
    
    public func setSegments(_ segments: [circle_segment]) {
        self.segments = segments
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
    
    public func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
}

public class HalfCircleGraphView: NSView {
    public var id: String = UUID().uuidString
    
    private var value: Double = 0.0
    private var text: String? = nil
    
    public var color: NSColor = NSColor.systemBlue
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = 7.0
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (min(rect.width, rect.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        var segments: [circle_segment] = [
            circle_segment(value: self.value, color: self.color)
        ]
        if self.value < 1 {
            segments.append(circle_segment(value: Double(1-self.value), color: NSColor.lightGray.withAlphaComponent(0.5)))
        }
        
        let startAngle: CGFloat = -(1/4)*CGFloat.pi
        let endCircle: CGFloat = (7/4)*CGFloat.pi - (1/4)*CGFloat.pi
        var previousAngle = startAngle
        
        context.saveGState()
        context.translateBy(x: rect.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        
        for segment in segments {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * endCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
        
        context.restoreGState()
        
        if self.text != nil {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let width: CGFloat = self.text!.widthOfString(usingFont: NSFont.systemFont(ofSize: 10))
            let height: CGFloat = self.text!.heightOfString(usingFont: NSFont.systemFont(ofSize: 10))
            let rect = CGRect(x: ((self.frame.width-width)/2)-0.5, y: (self.frame.height-6)/2, width: width, height: height)
            let str = NSAttributedString.init(string: self.text!, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        self.value = value > 1 ? value/100 : value
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
    
    public func setText(_ value: String) {
        self.text = value
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
}

public class TachometerGraphView: NSView {
    private var filled: Bool
    private var segments: [circle_segment]
    
    public init(frame: NSRect, segments: [circle_segment], filled: Bool = true) {
        self.filled = filled
        self.segments = segments
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = self.filled ? min(rect.width, rect.height) / 2 : 7
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: NSColor.lightGray.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (min(rect.width, rect.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        context.translateBy(x: rect.width, y: -4)
        context.scaleBy(x: -1, y: 1)
        
        let startAngle: CGFloat = 0
        let endCircle: CGFloat = CGFloat.pi
        var previousAngle = startAngle
        
        for segment in segments {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * endCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
    }
    
    public func setSegments(_ segments: [circle_segment]) {
        self.segments = segments
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
    
    public func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
}
