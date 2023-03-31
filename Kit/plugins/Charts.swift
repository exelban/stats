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

private func scaleValue(scale: Scale = .linear, value: Double, maxValue: Double, maxHeight: CGFloat) -> CGFloat {
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
        if value > 0 {
            value = log(value*100)
        }
        if localMaxValue > 0 {
            localMaxValue = log(maxValue*100)
        }
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

public class LineChartView: NSView {
    public var id: String = UUID().uuidString
    
    public var points: [Double]
    public var shadowPoints: [Double] = []
    public var transparent: Bool = true
    public var color: NSColor = .controlAccentColor
    public var suffix: String = "%"
    public var scale: Scale
    
    private var cursor: NSPoint? = nil
    private var stop: Bool = false
    
    public init(frame: NSRect, num: Int, scale: Scale = .none) {
        self.points = Array(repeating: 0, count: num)
        self.scale = scale
        
        super.init(frame: frame)
        
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
    
    // swiftlint:disable function_body_length
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var points = self.points
        if self.stop {
            points = self.shadowPoints
        }
        guard let maxValue = points.max() else { return }
        
        if points.isEmpty {
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
        let height: CGFloat = dirtyRect.height - self.frame.origin.y - offset
        let xRatio: CGFloat = dirtyRect.width / CGFloat(points.count-1)
        
        let list = points.enumerated().compactMap { (i: Int, v: Double) -> (value: Double, point: CGPoint) in
            return (v, CGPoint(
                x: (CGFloat(i) * xRatio) + dirtyRect.origin.x,
                y: scaleValue(scale: self.scale, value: v, maxValue: maxValue, maxHeight: height) + dirtyRect.origin.y + offset
            ))
        }
        
        let line = NSBezierPath()
        line.move(to: list[0].point)
        
        for i in 1..<points.count {
            line.line(to: list[i].point)
        }
        line.line(to: list[list.count-1].point)
        
        lineColor.set()
        line.lineWidth = offset
        line.stroke()
        
        let underLinePath = line.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: list[list.count-1].point.x, y: 0))
        underLinePath.line(to: CGPoint(x: list[0].point.x, y: 0))
        underLinePath.close()
        gradientColor.set()
        underLinePath.fill()
        
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
            hLine.line(to: CGPoint(x: self.frame.size.width+self.frame.origin.x, y: p.y))
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
            
            let style = NSMutableParagraphStyle()
            style.alignment = .left
            var textPosition: CGPoint = CGPoint(x: nearest.point.x+4, y: nearest.point.y+4)
            
            if textPosition.x + 24 > self.frame.size.width+self.frame.origin.x {
                textPosition.x = nearest.point.x - 30
                style.alignment = .right
            }
            if textPosition.y + 14 > height {
                textPosition.y = nearest.point.y - 14
            }
            
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            let rect = CGRect(x: textPosition.x, y: textPosition.y, width: 26, height: 10)
            let value = "\(Int(nearest.value.rounded(toPlaces: 2) * 100))\(self.suffix)"
            let str = NSAttributedString.init(string: value, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    // swiftlint:enable function_body_length
    
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
    
    public func addValue(_ value: Double) {
        self.points.remove(at: 0)
        self.points.append(value)
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func reinit(_ num: Int = 60) {
        guard self.points.count != num else { return }
        
        if num < self.points.count {
            self.points = Array(self.points[self.points.count-num..<self.points.count])
        } else {
            let origin = self.points
            self.points = Array(repeating: 0.01, count: num)
            self.points.replaceSubrange(Range(uncheckedBounds: (lower: origin.count, upper: num)), with: origin)
        }
    }
    
    public func setScale(_ newScale: Scale) {
        self.scale = newScale
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
    public var id: String = UUID().uuidString
    public var base: DataSizeBase = .byte
    public var inColor: NSColor
    public var outColor: NSColor
    public var points: [(Double, Double)]
    
    private var minMax: Bool = false
    private var scale: Scale = .none
    private var commonScale: Bool = true
    
    public init(frame: NSRect, num: Int, minMax: Bool = true, outColor: NSColor = .systemRed, inColor: NSColor = .systemBlue) {
        self.minMax = minMax
        self.points = Array(repeating: (0, 0), count: num)
        self.outColor = outColor
        self.inColor = inColor
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        let points = self.points
        var uploadMax: Double = points.map{ $0.0 }.max() ?? 0
        var downloadMax: Double = points.map{ $0.1 }.max() ?? 0
        if uploadMax == 0 {
            uploadMax = 1
        }
        if downloadMax == 0 {
            downloadMax = 1
        }
        
        if !self.commonScale {
            if downloadMax > uploadMax {
                uploadMax = downloadMax
            } else {
                downloadMax = uploadMax
            }
        }
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let zero: CGFloat = (dirtyRect.height/2) + dirtyRect.origin.y
        let xRatio: CGFloat = (dirtyRect.width + (lineWidth*3)) / CGFloat(points.count)
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return (CGFloat(point) * xRatio) + (dirtyRect.origin.x - lineWidth)
        }
        let uploadYPoint = { (point: Int) -> CGFloat in
            return scaleValue(scale: self.scale, value: points[point].0, maxValue: uploadMax, maxHeight: dirtyRect.height/2) + (dirtyRect.height/2 + dirtyRect.origin.y)
        }
        let downloadYPoint = { (point: Int) -> CGFloat in
            return (dirtyRect.height/2 + dirtyRect.origin.y) - scaleValue(scale: self.scale, value: points[point].1, maxValue: downloadMax, maxHeight: dirtyRect.height/2)
        }
        
        let uploadlinePath = NSBezierPath()
        uploadlinePath.move(to: CGPoint(x: columnXPoint(0), y: uploadYPoint(0)))
        
        let downloadlinePath = NSBezierPath()
        downloadlinePath.move(to: CGPoint(x: columnXPoint(0), y: downloadYPoint(0)))
        
        for i in 1..<points.count {
            uploadlinePath.line(to: CGPoint(x: columnXPoint(i), y: uploadYPoint(i)))
            downloadlinePath.line(to: CGPoint(x: columnXPoint(i), y: downloadYPoint(i)))
        }
        
        self.outColor.setStroke()
        uploadlinePath.lineWidth = lineWidth
        uploadlinePath.stroke()
        
        self.inColor.setStroke()
        downloadlinePath.lineWidth = lineWidth
        downloadlinePath.stroke()
        
        context.saveGState()
        
        var underLinePath = uploadlinePath.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: columnXPoint(points.count), y: zero))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        underLinePath.close()
        underLinePath.addClip()
        self.outColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(rect: dirtyRect).fill()
        
        context.restoreGState()
        context.saveGState()
        
        underLinePath = downloadlinePath.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: columnXPoint(points.count), y: zero))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        underLinePath.close()
        underLinePath.addClip()
        self.inColor.withAlphaComponent(0.5).setFill()
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
        self.points.remove(at: 0)
        self.points.append((upload, download))
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func reinit(_ num: Int = 60) {
        guard self.points.count != num else { return }
        
        if num < self.points.count {
            self.points = Array(self.points[self.points.count-num..<self.points.count])
        } else {
            let origin = self.points
            self.points = Array(repeating: (0, 0), count: num)
            self.points.replaceSubrange(Range(uncheckedBounds: (lower: origin.count, upper: num)), with: origin)
        }
    }
    
    public func setScale(_ newScale: Scale, _ commonScale: Bool) {
        self.scale = newScale
        self.commonScale = commonScale
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setColors(in inColor: NSColor? = nil, out outColor: NSColor? = nil) {
        var needUpdate: Bool = false
        
        if let newColor = inColor, self.inColor != newColor {
            self.inColor = newColor
            needUpdate = true
        }
        if let newColor = outColor, self.outColor != newColor {
            self.outColor = newColor
            needUpdate = true
        }
        
        if needUpdate && self.window?.isVisible ?? false {
            self.display()
        }
    }
}

public class PieChartView: NSView {
    public var id: String = UUID().uuidString
    
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
        let arcWidth: CGFloat = self.filled ? min(rect.width, rect.height) / 2 : 7
        let fullCircle = 2 * CGFloat.pi
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: self.nonActiveSegmentColor.withAlphaComponent(0.5)))
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
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
}

public class BarChartView: NSView {
    private var values: [ColorValue] = []
    
    public init(frame: NSRect, num: Int) {
        super.init(frame: frame)
        self.values = Array(repeating: ColorValue(0, color: .controlAccentColor), count: num)
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
            
            x += partitionSize.width + spacing
        }
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.values = values
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}
