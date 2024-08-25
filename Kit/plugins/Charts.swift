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

public struct circle_segment {
    public let value: Double
    public var color: NSColor
    
    public init(value: Double, color: NSColor) {
        self.value = value
        self.color = color
    }
}

internal func scaleValue(scale: Scale = .linear, value: Double, maxValue: Double, maxHeight: CGFloat, limit: Double) -> CGFloat {
    var value = value
    if scale == .none && value > 1 && maxValue != 0 {
        value /= maxValue
    }
    var localMaxValue = maxValue
    var y = value * maxHeight
    
    switch scale {
    case .square:
        if value > 0 {
            value = sqrt(value)
        }
        if localMaxValue > 0 {
            localMaxValue = sqrt(maxValue)
        }
    case .cube:
        if value > 0 {
            value = cbrt(value)
        }
        if localMaxValue > 0 {
            localMaxValue = cbrt(maxValue)
        }
    case .logarithmic:
        // Smallest value passed is 1024
        // Setting y=0 to 256 gives a nice curve
        let zeroVal = 256.0
        if value > 0 {
            value = log(value/zeroVal)
        }
        if localMaxValue > 0 {
            localMaxValue = log(maxValue/zeroVal)
        }
    case .fixed:
        if value > limit {
            value = limit
        }
        localMaxValue = limit
    default: break
    }
    
    if value < 0 {
        value = 0
    }
    if localMaxValue <= 0 {
        localMaxValue = 1
    }
    
    if scale != .none {
        y = (maxHeight * value)/localMaxValue
    }
    
    return y
}

private func drawToolTip(_ frame: NSRect, _ point: CGPoint, _ size: CGSize, value: String, subtitle: String? = nil) {
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    var position: CGPoint = point
    let textHeight: CGFloat = subtitle != nil ? 22 : 12
    let valueOffset: CGFloat = subtitle != nil ? 11 : 1
    
    if position.x + size.width > frame.size.width+frame.origin.x {
        position.x = point.x - size.width
        style.alignment = .right
    }
    if position.y + textHeight > size.height {
        position.y = point.y - textHeight - 20
    }
    if position.y < 2 {
        position.y = 2
    }
    
    let box = NSBezierPath(roundedRect: NSRect(x: position.x-3, y: position.y-2, width: size.width, height: textHeight+2), xRadius: 2, yRadius: 2)
    NSColor.gray.setStroke()
    box.stroke()
    (isDarkMode ? NSColor.black : NSColor.white).withAlphaComponent(0.8).setFill()
    box.fill()
    
    var attributes = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12, weight: .regular),
        NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor
    ]
    var rect = CGRect(x: position.x, y: position.y+valueOffset, width: size.width, height: 12)
    var str = NSAttributedString.init(string: value, attributes: attributes)
    str.draw(with: rect)
    
    if let subtitle {
        attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: 9, weight: .medium)
        attributes[NSAttributedString.Key.foregroundColor] = (isDarkMode ? NSColor.white : NSColor.textColor).withAlphaComponent(0.7)
        rect = CGRect(x: position.x, y: position.y, width: size.width-8, height: 9)
        str = NSAttributedString.init(string: subtitle, attributes: attributes)
        str.draw(with: rect)
    }
}

public class LineChartView: NSView {
    public var id: String = UUID().uuidString
    
    private let dateFormatter = DateFormatter()
    
    public var points: [DoubleValue?]
    public var shadowPoints: [DoubleValue?] = []
    public var transparent: Bool = true
    public var flipY: Bool = false
    public var minMax: Bool = false
    public var color: NSColor
    public var suffix: String
    public var toolTipFunc: ((DoubleValue) -> String)?
    
    private var scale: Scale
    private var fixedScale: Double
    
    private var cursor: NSPoint? = nil
    private var stop: Bool = false
    
    public init(frame: NSRect, num: Int, suffix: String = "%", color: NSColor = .controlAccentColor, scale: Scale = .none, fixedScale: Double = 1) {
        self.points = Array(repeating: nil, count: num)
        self.suffix = suffix
        self.color = color
        self.scale = scale
        self.fixedScale = fixedScale
        
        super.init(frame: frame)
        
        self.dateFormatter.dateFormat = "dd/MM HH:mm:ss"
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let points = self.stop ? self.shadowPoints : self.points
        guard let context = NSGraphicsContext.current?.cgContext, !points.isEmpty else { return }
        context.setShouldAntialias(true)
        let maxValue = points.compactMap { $0 }.max() ?? 0
        
        let lineColor: NSColor = self.color
        var gradientColor: NSColor = self.color.withAlphaComponent(0.5)
        if !self.transparent {
            gradientColor = self.color.withAlphaComponent(0.8)
        }
        
        let offset: CGFloat = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let height: CGFloat = self.frame.height - offset
        let xRatio: CGFloat = self.frame.width / CGFloat(points.count-1)
        let zero: CGFloat = self.flipY ? self.frame.height : 0
        
        var lines: [[CGPoint]] = []
        var line: [CGPoint] = []
        var list: [(value: DoubleValue, point: CGPoint)] = []
        
        for (i, v) in points.enumerated() {
            guard let v else {
                if !line.isEmpty {
                    lines.append(line)
                    line = []
                }
                continue
            }
            
            var y = scaleValue(scale: self.scale, value: v.value, maxValue: maxValue, maxHeight: height, limit: self.fixedScale)
            if self.flipY {
                y = height - y
            }
            
            let point = CGPoint(
                x: (CGFloat(i) * xRatio) + dirtyRect.origin.x,
                y: y
            )
            line.append(point)
            list.append((value: v, point: point))
        }
        if lines.isEmpty && !line.isEmpty {
            lines.append(line)
        }
        
        var path = NSBezierPath()
        for linePoints in lines {
            if linePoints.count == 1 {
                path = NSBezierPath(ovalIn: CGRect(x: linePoints[0].x-offset, y: linePoints[0].y-offset, width: 1, height: 1))
                lineColor.set()
                path.stroke()
                gradientColor.set()
                path.fill()
                continue
            }
            
            path = NSBezierPath()
            path.move(to: linePoints[0])
            for i in 1..<linePoints.count {
                path.line(to: linePoints[i])
            }
            lineColor.set()
            path.lineWidth = offset
            path.stroke()
            
            path = path.copy() as! NSBezierPath
            path.line(to: CGPoint(x: linePoints[linePoints.count-1].x, y: zero))
            path.line(to: CGPoint(x: linePoints[0].x, y: zero))
            path.close()
            gradientColor.set()
            path.fill()
        }
        
        if self.minMax {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            var str: String = ""
            let flatList = self.points.map{ $0?.value ?? 0 }
            if let value = flatList.max() {
                str = self.toolTipFunc != nil ? self.toolTipFunc!(DoubleValue(value)) : "\(Int(value.rounded(toPlaces: 2) * 100))\(self.suffix)"
            }
            let textWidth = str.widthOfString(usingFont: stringAttributes[NSAttributedString.Key.font] as! NSFont)
            let y = self.flipY ? 1 : height - 9
            let rect = CGRect(x: 1, y: y, width: textWidth, height: 8)
            NSAttributedString.init(string: str, attributes: stringAttributes).draw(with: rect)
        }
        
        if let p = self.cursor, let over = list.first(where: { $0.point.x >= p.x }), let under = list.last(where: { $0.point.x <= p.x }) {
            guard p.y <= height else { return }
            
            let diffOver = over.point.x - p.x
            let diffUnder = p.x - under.point.x
            let nearest = (diffOver < diffUnder) ? over : under
            let vLine = NSBezierPath()
            let hLine = NSBezierPath()
            
            vLine.setLineDash([4, 4], count: 2, phase: 0)
            hLine.setLineDash([6, 6], count: 2, phase: 0)
            
            vLine.move(to: CGPoint(x: p.x, y: 0))
            vLine.line(to: CGPoint(x: p.x, y: height))
            vLine.close()
            
            hLine.move(to: CGPoint(x: 0, y: p.y))
            hLine.line(to: CGPoint(x: self.frame.size.width, y: p.y))
            hLine.close()
            
            NSColor.tertiaryLabelColor.set()
            
            vLine.lineWidth = offset
            hLine.lineWidth = offset
            
            vLine.stroke()
            hLine.stroke()
            
            let dotSize: CGFloat = 4
            let path = NSBezierPath(ovalIn: CGRect(
                x: nearest.point.x-(dotSize/2),
                y: nearest.point.y-(dotSize/2),
                width: dotSize,
                height: dotSize
            ))
            NSColor.red.set()
            path.stroke()
            
            let date = self.dateFormatter.string(from: nearest.value.ts)
            let roundedValue = (nearest.value.value * 100).rounded(toPlaces: 2)
            let strValue = roundedValue >= 1 ? "\(Int(roundedValue))\(self.suffix)" : "\(roundedValue)\(self.suffix)"
            let value = self.toolTipFunc != nil ? self.toolTipFunc!(nearest.value) : strValue
            drawToolTip(self.frame, CGPoint(x: nearest.point.x+4, y: nearest.point.y+4), CGSize(width: 78, height: height), value: value, subtitle: date)
        }
    }
    
    public override func updateTrackingAreas() {
        self.trackingAreas.forEach({ self.removeTrackingArea($0) })
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
        super.updateTrackingAreas()
    }
    
    public func addValue(_ value: DoubleValue) {
        self.points.remove(at: 0)
        self.points.append(value)
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func addValue(_ value: Double) {
        self.addValue(DoubleValue(value))
    }
    
    public func reinit(_ num: Int = 60) {
        guard self.points.count != num else { return }
        
        if num < self.points.count {
            self.points = Array(self.points[self.points.count-num..<self.points.count])
        } else {
            let origin = self.points
            self.points = Array(repeating: nil, count: num)
            self.points.replaceSubrange(Range(uncheckedBounds: (lower: num-origin.count, upper: num)), with: origin)
        }
    }
    
    public func setScale(_ newScale: Scale, fixedScale: Double = 1) {
        self.scale = newScale
        self.fixedScale = fixedScale
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseMoved(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        self.cursor = nil
        self.needsDisplay = true
    }
    
    public override func mouseDown(with: NSEvent) {
        self.shadowPoints = self.points
        self.stop = true
    }
    public override func mouseUp(with: NSEvent) {
        self.stop = false
    }
}

public class NetworkChartView: NSView {
    public var base: DataSizeBase = .byte
    
    private var reversedOrder: Bool
    
    private var inChart: LineChartView
    private var outChart: LineChartView
    
    public init(frame: NSRect, num: Int, minMax: Bool = true, reversedOrder: Bool = false,
                outColor: NSColor = .systemRed, inColor: NSColor = .systemBlue, scale: Scale = .none, fixedScale: Double = 1) {
        self.reversedOrder = reversedOrder
        
        let topFrame = NSRect(x: 0, y: frame.height/2, width: frame.width, height: frame.height/2)
        let bottomFrame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height/2)
        let inFrame = self.reversedOrder ? topFrame : bottomFrame
        let outFrame = self.reversedOrder ? bottomFrame : topFrame
        self.inChart = LineChartView(frame: inFrame, num: num, color: inColor, scale: scale, fixedScale: fixedScale)
        self.outChart = LineChartView(frame: outFrame, num: num, color: outColor, scale: scale, fixedScale: fixedScale)
        
        super.init(frame: frame)
        
        self.inChart.minMax = minMax
        self.outChart.minMax = minMax
        
        self.inChart.flipY = !self.reversedOrder
        self.outChart.flipY = self.reversedOrder
        
        self.inChart.toolTipFunc = { v in
            return Units(bytes: Int64(v.value)).getReadableSpeed(base: self.base)
        }
        self.outChart.toolTipFunc = { v in
            return Units(bytes: Int64(v.value)).getReadableSpeed(base: self.base)
        }
        
        self.addSubview(self.inChart)
        self.addSubview(self.outChart)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func addValue(upload: Double, download: Double) {
        self.inChart.addValue(DoubleValue(download))
        self.outChart.addValue(DoubleValue(upload))
    }
    
    public func reinit(_ num: Int = 60) {
        self.inChart.reinit(num)
        self.outChart.reinit(num)
    }
    
    public func setScale(_ newScale: Scale, _ fixedScale: Double = 1) {
        self.inChart.setScale(newScale, fixedScale: fixedScale)
        self.outChart.setScale(newScale, fixedScale: fixedScale)
    }
    
    public func setReverseOrder(_ newValue: Bool) {
        guard self.reversedOrder != newValue else { return }
        self.reversedOrder = newValue
        
        self.inChart.flipY = !self.reversedOrder
        self.outChart.flipY = self.reversedOrder
        
        let topFrame = CGPoint(x: 0, y: frame.height/2)
        let bottomFrame = CGPoint(x: 0, y: 0)
        self.inChart.setFrameOrigin(self.reversedOrder ? topFrame : bottomFrame)
        self.outChart.setFrameOrigin(self.reversedOrder ? bottomFrame : topFrame)
        
        self.inChart.display()
        self.outChart.display()
    }
    
    public func setColors(in inColor: NSColor? = nil, out outColor: NSColor? = nil) {
        if let inColor {
            self.inChart.color = inColor
        }
        if let outColor {
            self.outChart.color = outColor
        }
    }
}

public class PieChartView: NSView {
    private var filled: Bool = false
    private var drawValue: Bool = false
    private var nonActiveSegmentColor: NSColor = NSColor.lightGray
    
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
        let arcWidth: CGFloat = self.filled ? min(self.frame.width, self.frame.height) / 2 : 7
        let fullCircle = 2 * CGFloat.pi
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: self.nonActiveSegmentColor.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        
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
            
            let percentage = "\(Int(value.rounded(toPlaces: 2) * 100))%"
            let width: CGFloat = percentage.widthOfString(usingFont: NSFont.systemFont(ofSize: 15))
            let rect = CGRect(x: (self.frame.width-width)/2, y: (self.frame.height-11)/2, width: width, height: 12)
            let str = NSAttributedString.init(string: percentage, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        self.value = value
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setSegments(_ segments: [circle_segment]) {
        self.segments = segments
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
    
    public func setNonActiveSegmentColor(_ newColor: NSColor) {
        guard self.nonActiveSegmentColor != newColor else { return }
        self.nonActiveSegmentColor = newColor
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}

public class HalfCircleGraphView: NSView {
    public var id: String = UUID().uuidString
    
    private var value: Double = 0.0
    private var text: String? = nil
    
    public var color: NSColor = NSColor.systemBlue
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = 7.0
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        
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
        context.translateBy(x: self.frame.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        
        for segment in segments {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * endCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
        
        context.restoreGState()
        
        if let text = self.text {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let width: CGFloat = text.widthOfString(usingFont: NSFont.systemFont(ofSize: 10))
            let rect = CGRect(x: ((self.frame.width-width)/2)-0.5, y: (self.frame.height-6)/2, width: width, height: 13)
            let str = NSAttributedString.init(string: text, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        self.value = value > 1 ? value/100 : value
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setText(_ value: String) {
        self.text = value
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}

internal class TachometerGraphView: NSView {
    private var filled: Bool
    private var segments: [circle_segment]
    
    internal init(frame: NSRect, segments: [circle_segment], filled: Bool = true) {
        self.filled = filled
        self.segments = segments
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = self.filled ? min(self.frame.width, self.frame.height) / 2 : 7
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: NSColor.lightGray.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        context.translateBy(x: self.frame.width, y: -4)
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
    
    internal func setSegments(_ segments: [circle_segment]) {
        self.segments = segments
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    internal func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
}

public class BarChartView: NSView {
    private var values: [ColorValue] = []
    private var cursor: CGPoint? = nil
    
    public init(frame: NSRect = NSRect.zero, num: Int) {
        super.init(frame: frame)
        self.values = Array(repeating: ColorValue(0, color: .controlAccentColor), count: num)
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let blocks: Int = 16
        let spacing: CGFloat = 2
        let count: CGFloat = CGFloat(self.values.count)
        let partitionSize: CGSize = CGSize(width: (self.frame.width - (count*spacing)) / count, height: self.frame.height)
        let blockSize = CGSize(width: partitionSize.width-(spacing*2), height: ((partitionSize.height - spacing - 1)/CGFloat(blocks))-1)
        
        var list: [(value: Double, path: NSBezierPath)] = []
        var x: CGFloat = 0
        for i in 0..<self.values.count {
            let partition = NSBezierPath(
                roundedRect: NSRect(x: x, y: 0, width: partitionSize.width, height: partitionSize.height),
                xRadius: 3, yRadius: 3
            )
            NSColor.underPageBackgroundColor.withAlphaComponent(0.5).setFill()
            partition.fill()
            partition.close()
            
            let value = self.values[i]
            let color = value.color ?? .controlAccentColor
            let activeBlockNum = Int(round(value.value*Double(blocks)))
            let h = value.value*(partitionSize.height-spacing)
            
            if dirtyRect.height < 30 && h != 0 {
                let block = NSBezierPath(
                    roundedRect: NSRect(x: x+spacing, y: 1, width: partitionSize.width-(spacing*2), height: h),
                    xRadius: 1, yRadius: 1
                )
                color.setFill()
                block.fill()
                block.close()
            } else {
                var y: CGFloat = spacing
                for b in 0..<blocks {
                    let block = NSBezierPath(
                        roundedRect: NSRect(x: x+spacing, y: y, width: blockSize.width, height: blockSize.height),
                        xRadius: 1, yRadius: 1
                    )
                    (activeBlockNum <= b ? NSColor.controlBackgroundColor.withAlphaComponent(0.4) : color).setFill()
                    block.fill()
                    block.close()
                    y += blockSize.height + 1
                }
            }
            
            x += partitionSize.width + spacing
            list.append((value: value.value, path: partition))
        }
        
        if let p = self.cursor, let block = list.first(where: { $0.path.contains(p) }) {
            let value = "\(Int(block.value.rounded(toPlaces: 2) * 100))%"
            let width: CGFloat = block.value == 1 ? 38 : block.value > 0.1 ? 32 : 24
            drawToolTip(self.frame, CGPoint(x: p.x+4, y: p.y+4), CGSize(width: width, height: partitionSize.height), value: value)
        }
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.values = values
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.display()
    }
    public override func mouseMoved(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.display()
    }
    public override func mouseDragged(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.display()
    }
    public override func mouseExited(with event: NSEvent) {
        self.cursor = nil
        self.display()
    }
}

public class GridChartView: NSView {
    private let okColor: NSColor = .systemGreen
    private let notOkColor: NSColor = .systemRed
    private let inactiveColor: NSColor = .underPageBackgroundColor.withAlphaComponent(0.4)
    
    private var values: [NSColor] = []
    private let grid: (rows: Int, columns: Int)
    
    public init(frame: NSRect, grid: (rows: Int, columns: Int)) {
        self.grid = grid
        super.init(frame: frame)
        self.values = Array(repeating: self.inactiveColor, count: grid.rows * grid.columns)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let spacing: CGFloat = 2
        let size: CGSize = CGSize(
            width: (self.frame.width - ((CGFloat(self.grid.rows)-1) * spacing)) / CGFloat(self.grid.rows),
            height: (self.frame.height - ((CGFloat(self.grid.columns)-1) * spacing)) / CGFloat(self.grid.columns)
        )
        var origin: CGPoint = CGPoint(x: 0, y: (size.height + spacing) * CGFloat(self.grid.columns - 1))
        
        var i: Int = 0
        for _ in 0..<self.grid.columns {
            for _ in 0..<self.grid.rows {
                let box = NSBezierPath(roundedRect: NSRect(origin: origin, size: size), xRadius: 1, yRadius: 1)
                self.values[i].setFill()
                box.fill()
                box.close()
                i += 1
                origin.x += size.width + spacing
            }
            origin.x = 0
            origin.y -= size.height + spacing
        }
    }
    
    public func addValue(_ value: Bool) {
        self.values.remove(at: 0)
        self.values.append(value ? self.okColor : self.notOkColor)
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}
