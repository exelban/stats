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

internal func scaleValue(scale: Scale = .linear, value: Double, maxValue: Double, zeroValue: Double, maxHeight: CGFloat, limit: Double) -> CGFloat {
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
            value = log(value/zeroValue)
        }
        if localMaxValue > 0 {
            localMaxValue = log(maxValue/zeroValue)
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
    guard !value.isEmpty else { return }
    
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    var position: CGPoint = point
    let textHeight: CGFloat = subtitle != nil ? 22 : 12
    let valueOffset: CGFloat = subtitle != nil ? 11 : 1
    
    position.x = max(frame.origin.x, min(position.x, frame.origin.x + frame.size.width - size.width))
    position.y = max(frame.origin.y, min(position.y, frame.origin.y + frame.size.height - textHeight - 2))
    
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

public class ChartView: NSView {
    public var id: String = UUID().uuidString
    fileprivate let stateQueue: DispatchQueue
    
    fileprivate init(frame: NSRect, queueLabel: String) {
        self.stateQueue = DispatchQueue(label: queueLabel, attributes: .concurrent)
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func read<T>(_ block: () -> T) -> T {
        self.stateQueue.sync(execute: block)
    }
    
    fileprivate func write(_ block: @escaping () -> Void) {
        self.stateQueue.async(flags: .barrier, execute: block)
    }
    
    fileprivate func displayIfVisible() {
        if Thread.isMainThread {
            if self.window?.isVisible ?? false { self.display() }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.window?.isVisible ?? false { self.display() }
            }
        }
    }
}

public class LineChartView: ChartView {
    private let dateFormatter = DateFormatter()
    
    private var points: [DoubleValue?]
    private var shadowPoints: [DoubleValue?] = []
    private var transparent: Bool = true
    private var flipY: Bool = false
    private var minMax: Bool = false
    private var color: NSColor
    private var suffix: String
    private var toolTipFunc: ((DoubleValue) -> String)?
    private var isTooltipEnabled: Bool = true
    private var xLegend: Bool = false
    private var yLegend: Bool = false
    
    private var scale: Scale
    private var fixedScale: Double
    private var zeroValue: Double
    private let legendDateFormatter = DateFormatter()
    
    private var cursor: NSPoint? = nil
    private var stop: Bool = false
    
    private var tooltipEnabledSnapshot: Bool {
        self.read { self.isTooltipEnabled }
    }
    
    public init(frame: NSRect = .zero, num: Int, suffix: String = "%", color: NSColor = .controlAccentColor, scale: Scale = .none, fixedScale: Double = 1, zeroValue: Double = 0.01) {
        self.points = Array(repeating: nil, count: max(num, 1))
        self.suffix = suffix
        self.color = color
        self.scale = scale
        self.fixedScale = fixedScale
        self.zeroValue = zeroValue
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Line")
        
        self.dateFormatter.dateFormat = "dd/MM HH:mm:ss"
        self.legendDateFormatter.dateFormat = "HH:mm:ss"
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                .activeAlways,
                .mouseEnteredAndExited,
                .mouseMoved,
                .inVisibleRect
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var originalPoints: [DoubleValue?] = []
        var shadowPoints: [DoubleValue?] = []
        var transparent: Bool = true
        var flipY: Bool = false
        var minMax: Bool = false
        var color: NSColor = .controlAccentColor
        var suffix: String = "%"
        var toolTipFunc: ((DoubleValue) -> String)?
        var isTooltipEnabled: Bool = true
        var xLegend: Bool = false
        var yLegend: Bool = false
        var scale: Scale = .none
        var fixedScale: Double = 1
        var zeroValue: Double = 0.01
        self.read {
            originalPoints = self.points
            shadowPoints = self.shadowPoints
            transparent = self.transparent
            flipY = self.flipY
            minMax = self.minMax
            color = self.color
            suffix = self.suffix
            toolTipFunc = self.toolTipFunc
            isTooltipEnabled = self.isTooltipEnabled
            xLegend = self.xLegend
            yLegend = self.yLegend
            scale = self.scale
            fixedScale = self.fixedScale
            zeroValue = self.zeroValue
        }
        
        let points = stop ? shadowPoints : originalPoints
        guard let context = NSGraphicsContext.current?.cgContext, !points.isEmpty else { return }
        context.setShouldAntialias(true)
        let maxValue = points.compactMap { $0 }.max() ?? 0
        
        let lineColor: NSColor = color
        var gradientColor: NSColor = color.withAlphaComponent(0.5)
        if !transparent {
            gradientColor = color.withAlphaComponent(0.8)
        }
        let gradient = NSGradient(colors: [
            gradientColor.withAlphaComponent(0.5),
            gradientColor.withAlphaComponent(1.0)
        ])
        
        let offset: CGFloat = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let xLegendHeight: CGFloat = xLegend ? 14 : 0
        let yLegendWidth: CGFloat = yLegend ? 30 : 0
        let height: CGFloat = self.frame.height - offset - xLegendHeight
        let chartWidth: CGFloat = self.frame.width - yLegendWidth
        let xRatio: CGFloat = chartWidth / CGFloat(points.count-1)
        let zero: CGFloat = flipY ? self.frame.height : xLegendHeight
        
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
            
            var y = scaleValue(scale: scale, value: v.value, maxValue: maxValue, zeroValue: zeroValue, maxHeight: height, limit: fixedScale)
            if flipY {
                y = height - y
            }
            
            let point = CGPoint(
                x: yLegendWidth + CGFloat(i) * xRatio,
                y: y + xLegendHeight
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
            if let gradient {
                gradient.draw(in: path, angle: 90)
            } else {
                gradientColor.set()
                path.fill()
            }
        }
        
        if minMax {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            var str: String = ""
            let flatList = originalPoints.map{ $0?.value ?? 0 }
            if let value = flatList.max() {
                str = toolTipFunc != nil ? toolTipFunc!(DoubleValue(value)) : "\(Int(value.rounded(toPlaces: 2) * 100))\(suffix)"
            }
            let textWidth = str.widthOfString(usingFont: stringAttributes[NSAttributedString.Key.font] as! NSFont)
            let y = flipY ? xLegendHeight + 1 : height + xLegendHeight - 9
            let rect = CGRect(x: 1, y: y, width: textWidth, height: 8)
            NSAttributedString.init(string: str, attributes: stringAttributes).draw(with: rect)
        }
        
        if xLegend, list.count >= 2 {
            let legendFont = NSFont.systemFont(ofSize: 9, weight: .light)
            let legendAttributes: [NSAttributedString.Key: Any] = [
                .font: legendFont,
                .foregroundColor: (isDarkMode ? NSColor.white : NSColor.textColor).withAlphaComponent(0.5)
            ]
            
            let sampleWidth = "00:00:00".widthOfString(usingFont: legendFont)
            let spacing: CGFloat = 8
            let maxLabels = max(2, Int(self.frame.width / (sampleWidth + spacing)))
            let count = min(maxLabels, 5)
            let step = max(1, (list.count - 1) / (count - 1))
            var indices: [Int] = []
            for i in stride(from: 0, to: list.count - 1, by: step) {
                indices.append(i)
            }
            if indices.last != list.count - 1 {
                indices.append(list.count - 1)
            }
            
            var lastMaxX: CGFloat = -.greatestFiniteMagnitude
            for idx in indices {
                let item = list[idx]
                let str = self.legendDateFormatter.string(from: item.value.ts)
                let textWidth = str.widthOfString(usingFont: legendFont)
                var x = item.point.x - textWidth / 2
                x = max(0, min(x, self.frame.width - textWidth))
                guard x >= lastMaxX else { continue }
                let attrStr = NSAttributedString(string: str, attributes: legendAttributes)
                attrStr.draw(with: CGRect(x: x, y: 0, width: textWidth, height: 12))
                lastMaxX = x + textWidth + spacing
            }
        }
        
        if yLegend {
            let legendFont = NSFont.systemFont(ofSize: 9, weight: .light)
            let legendAttributes: [NSAttributedString.Key: Any] = [
                .font: legendFont,
                .foregroundColor: (isDarkMode ? NSColor.white : NSColor.textColor).withAlphaComponent(0.5)
            ]
            
            let textHeight = legendFont.ascender - legendFont.descender
            let steps = [0, 25, 50, 75, 100]
            let spacing = (height - textHeight) / CGFloat(steps.count - 1)
            for (i, step) in steps.enumerated() {
                let textY = xLegendHeight + CGFloat(i) * spacing
                let lineY = xLegendHeight + height * CGFloat(step) / 100
                
                if xLegend {
                    let gridColor = (isDarkMode ? NSColor.white : NSColor.black).withAlphaComponent(0.06)
                    gridColor.setStroke()
                    let line = NSBezierPath()
                    line.move(to: CGPoint(x: yLegendWidth, y: lineY))
                    line.line(to: CGPoint(x: self.frame.width, y: lineY))
                    line.lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
                    line.stroke()
                }
                
                let label = "\(step)\(suffix)"
                let attrStr = NSAttributedString(string: label, attributes: legendAttributes)
                attrStr.draw(at: CGPoint(x: 0, y: textY))
            }
        }
        
        if isTooltipEnabled, let p = self.cursor, !list.isEmpty {
            guard p.y <= height + xLegendHeight else { return }
            
            let overPoints = list.filter { $0.point.x >= p.x }
            let underPoints = list.filter { $0.point.x <= p.x }
            
            if let over = overPoints.min(by: { $0.point.x < $1.point.x }), let under = underPoints.max(by: { $0.point.x < $1.point.x }) {
                let diffOver = over.point.x - p.x
                let diffUnder = p.x - under.point.x
                let nearest = (diffOver < diffUnder) ? over : under
                let vLine = NSBezierPath()
                let hLine = NSBezierPath()
                
                vLine.setLineDash([4, 4], count: 2, phase: 0)
                hLine.setLineDash([6, 6], count: 2, phase: 0)
                
                vLine.move(to: CGPoint(x: p.x, y: xLegendHeight))
                vLine.line(to: CGPoint(x: p.x, y: height + xLegendHeight))
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
                let roundedValue = Int(nearest.value.value.rounded(toPlaces: 2) * 100)
                let strValue = "\(roundedValue)\(suffix)"
                let value = toolTipFunc != nil ? toolTipFunc!(nearest.value) : strValue
                let tooltipWidth: CGFloat = 78
                let tooltipX = nearest.point.x + 4 + tooltipWidth > self.frame.size.width
                    ? nearest.point.x - tooltipWidth - 4
                    : nearest.point.x + 4
                drawToolTip(self.frame, CGPoint(x: tooltipX, y: nearest.point.y+4), CGSize(width: tooltipWidth, height: height), value: value, subtitle: date)
            }
        }
    }
    
    public override func updateTrackingAreas() {
        self.trackingAreas.forEach({ self.removeTrackingArea($0) })
        self.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [
                .activeAlways,
                .mouseEnteredAndExited,
                .mouseMoved,
                .inVisibleRect
            ],
            owner: self, userInfo: nil
        ))
        super.updateTrackingAreas()
    }
    
    public func addValue(_ value: DoubleValue) {
        self.write {
            guard !self.points.isEmpty else { return }
            self.points.remove(at: 0)
            self.points.append(value)
        }
        self.displayIfVisible()
    }
    
    public func addValue(_ value: Double) {
        self.addValue(DoubleValue(value))
    }
    
    public func reinit(_ num: Int = 60) {
        self.write {
            guard self.points.count != num else { return }
            if num < self.points.count {
                self.points = Array(self.points[self.points.count-num..<self.points.count])
            } else {
                let origin = self.points
                self.points = Array(repeating: nil, count: num)
                self.points.replaceSubrange(Range(uncheckedBounds: (lower: num-origin.count, upper: num)), with: origin)
            }
        }
        self.displayIfVisible()
    }
    
    public func setScale(_ newScale: Scale, fixedScale: Double = 1) {
        self.write {
            self.scale = newScale
            self.fixedScale = fixedScale
        }
        self.displayIfVisible()
    }
    
    public func setPoints(_ newPoints: [DoubleValue]) {
        self.write { self.points = newPoints.map { Optional($0) } }
        self.displayIfVisible()
    }
    
    public func setColor(_ newColor: NSColor) {
        self.write { self.color = newColor }
        self.displayIfVisible()
    }
    
    public func setSuffix(_ newSuffix: String) {
        self.write { self.suffix = newSuffix }
        self.displayIfVisible()
    }
    
    public func setTransparent(_ newValue: Bool) {
        self.write { self.transparent = newValue }
        self.displayIfVisible()
    }
    
    public func setFlipY(_ newValue: Bool) {
        self.write { self.flipY = newValue }
        self.displayIfVisible()
    }
    
    public func setMinMax(_ newValue: Bool) {
        self.write { self.minMax = newValue }
        self.displayIfVisible()
    }
    
    public func setToolTipFunc(_ newValue: ((DoubleValue) -> String)?) {
        self.write { self.toolTipFunc = newValue }
    }
    
    public func setTooltipEnabled(_ newValue: Bool) {
        self.write { self.isTooltipEnabled = newValue }
    }
    
    public func setLegend(x: Bool, y: Bool) {
        self.write {
            self.xLegend = x
            self.yLegend = y
        }
        self.displayIfVisible()
    }
    
    public override func mouseEntered(with event: NSEvent) {
        guard self.tooltipEnabledSnapshot else { return }
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseMoved(with event: NSEvent) {
        guard self.tooltipEnabledSnapshot else { return }
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard self.tooltipEnabledSnapshot else { return }
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        guard self.tooltipEnabledSnapshot else { return }
        self.cursor = nil
        self.needsDisplay = true
    }
    
    public override func mouseDown(with: NSEvent) {
        guard self.tooltipEnabledSnapshot else { return }
        self.write { self.shadowPoints = self.points }
        self.stop = true
    }
    
    public override func mouseUp(with: NSEvent) {
        guard self.tooltipEnabledSnapshot else { return }
        self.stop = false
    }
}

public class NetworkChartView: ChartView {
    private var base: DataSizeBase = .byte
    
    private var reversedOrder: Bool
    
    private var inChart: LineChartView
    private var outChart: LineChartView
    
    public init(frame: NSRect, num: Int, minMax: Bool = true, reversedOrder: Bool = false,
                outColor: NSColor = .systemRed, inColor: NSColor = .systemBlue, scale: Scale = .none, fixedScale: Double = 1) {
        self.reversedOrder = reversedOrder
        
        let safeHeight = max(frame.height, 2)
        let topFrame = NSRect(x: frame.origin.x, y: safeHeight/2, width: frame.width, height: safeHeight/2)
        let bottomFrame = NSRect(x: frame.origin.x, y: 0, width: frame.width, height: safeHeight/2)
        let inFrame = self.reversedOrder ? topFrame : bottomFrame
        let outFrame = self.reversedOrder ? bottomFrame : topFrame
        self.inChart = LineChartView(frame: inFrame, num: num, color: inColor, scale: scale, fixedScale: fixedScale, zeroValue: 256.0)
        self.outChart = LineChartView(frame: outFrame, num: num, color: outColor, scale: scale, fixedScale: fixedScale, zeroValue: 256.0)
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Network")
        
        self.inChart.setMinMax(minMax)
        self.outChart.setMinMax(minMax)
        
        self.inChart.setFlipY(!self.reversedOrder)
        self.outChart.setFlipY(self.reversedOrder)
        
        let tooltip: (DoubleValue) -> String = { [weak self] v in
            let base: DataSizeBase = self?.read { self?.base ?? .byte } ?? .byte
            return Units(bytes: Int64(v.value)).getReadableSpeed(base: base)
        }
        self.inChart.setToolTipFunc(tooltip)
        self.outChart.setToolTipFunc(tooltip)
        
        self.addSubview(self.inChart)
        self.addSubview(self.outChart)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setBase(_ newBase: DataSizeBase) {
        self.write { self.base = newBase }
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
        
        self.inChart.setFlipY(!self.reversedOrder)
        self.outChart.setFlipY(self.reversedOrder)
        
        let safeHeight = max(frame.height, 2)
        let topFrame = CGPoint(x: 0, y: safeHeight/2)
        let bottomFrame = CGPoint(x: 0, y: 0)
        self.inChart.setFrameOrigin(self.reversedOrder ? topFrame : bottomFrame)
        self.outChart.setFrameOrigin(self.reversedOrder ? bottomFrame : topFrame)
        
        self.inChart.display()
        self.outChart.display()
    }
    
    public func setColors(in inColor: NSColor? = nil, out outColor: NSColor? = nil) {
        if let inColor {
            self.inChart.setColor(inColor)
        }
        if let outColor {
            self.outChart.setColor(outColor)
        }
    }
    
    public func setTooltipState(_ newState: Bool) {
        self.inChart.setTooltipEnabled(newState)
        self.outChart.setTooltipEnabled(newState)
    }
    
    public override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        
        let safeHeight = max(frame.height, 2)
        let topFrame = CGPoint(x: 0, y: safeHeight/2)
        let bottomFrame = CGPoint(x: 0, y: 0)
        
        self.inChart.setFrameOrigin(self.reversedOrder ? topFrame : bottomFrame)
        self.outChart.setFrameOrigin(self.reversedOrder ? bottomFrame : topFrame)
    }
}

public class PieChartView: ChartView {
    private var filled: Bool = false
    private var drawValue: Bool = false
    private var drawNeedle: Bool = false
    private var openCircle: Bool = false
    private var nonActiveSegmentColor: NSColor = NSColor.lightGray
    
    private var value: Double? = nil
    private var text: String? = nil
    private var activeSegment: Int? = nil
    private var segments: [ColorValue] = []
    private var color: NSColor = NSColor.systemBlue
    
    public init(frame: NSRect = .zero, segments: [ColorValue] = [], filled: Bool = false, drawValue: Bool = false, drawNeedle: Bool = false, openCircle: Bool = false) {
        self.filled = filled
        self.drawValue = drawValue
        self.drawNeedle = drawNeedle
        self.openCircle = openCircle
        self.segments = segments
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Pie")
        
        self.setAccessibilityElement(true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        var filled: Bool = false
        var drawValue: Bool = false
        var drawNeedle: Bool = false
        var openCircle: Bool = false
        var nonActiveSegmentColor: NSColor = NSColor.lightGray
        var value: Double? = nil
        var text: String? = nil
        var activeSegment: Int? = nil
        var segments: [ColorValue] = []
        var color: NSColor = NSColor.systemBlue
        self.read {
            filled = self.filled
            drawValue = self.drawValue
            drawNeedle = self.drawNeedle
            openCircle = self.openCircle
            nonActiveSegmentColor = self.nonActiveSegmentColor
            value = self.value
            text = self.text
            activeSegment = self.activeSegment
            segments = self.segments
            color = self.color
        }
        
        let arcWidth: CGFloat = filled ? min(self.frame.width, self.frame.height) / 2 : 7
        let fullCircle: CGFloat = 2 * CGFloat.pi
        let arcSpan: CGFloat = openCircle ? (3/2) * CGFloat.pi : fullCircle
        if segments.isEmpty {
            segments = [ColorValue(value ?? 0, color: color)]
        }
        
        if openCircle {
            let totalAmount = segments.reduce(0) { $0 + $1.value }
            if totalAmount < 1 {
                segments.append(ColorValue(Double(1-totalAmount), color: NSColor.lightGray.withAlphaComponent(0.5)))
            }
        } else {
            let totalAmount = segments.reduce(0) { $0 + $1.value }
            if totalAmount < 1 {
                segments.append(ColorValue(Double(1-totalAmount), color: nonActiveSegmentColor.withAlphaComponent(0.5)))
            }
        }
        
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(openCircle ? .round : .butt)
        
        if openCircle {
            let startAngle: CGFloat = CGFloat.pi + CGFloat.pi/4
            var previousAngle = startAngle
            
            for segment in segments {
                let currentAngle: CGFloat = previousAngle - (CGFloat(segment.value) * arcSpan)
                
                if let color = segment.color {
                    context.setStrokeColor(color.cgColor)
                }
                context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: true)
                context.strokePath()
                
                previousAngle = currentAngle
            }
        } else {
            let startAngle: CGFloat = CGFloat.pi/2
            var previousAngle = startAngle
            
            for segment in segments.reversed() {
                let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * fullCircle)
                
                if let color = segment.color {
                    context.setStrokeColor(color.cgColor)
                }
                context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
                context.strokePath()
                
                previousAngle = currentAngle
            }
        }
        
        if drawNeedle, let activeSegment = activeSegment, !segments.isEmpty {
            let needleEndSize: CGFloat = 2
            let startAngle: CGFloat = CGFloat.pi + CGFloat.pi/4
            let idx = min(activeSegment, segments.count - 1)
            var needleValue: CGFloat = 0
            for i in 0..<idx {
                needleValue += CGFloat(segments[i].value)
            }
            needleValue += CGFloat(segments[idx].value) / 2
            let needleAngle = startAngle - needleValue * arcSpan
            let needleLength = radius - arcWidth/2
            
            let tip = CGPoint(
                x: centerPoint.x + needleLength * cos(needleAngle),
                y: centerPoint.y + needleLength * sin(needleAngle)
            )
            let perpAngle = needleAngle + CGFloat.pi/2
            let base1 = CGPoint(
                x: centerPoint.x + needleEndSize * cos(perpAngle),
                y: centerPoint.y + needleEndSize * sin(perpAngle)
            )
            let base2 = CGPoint(
                x: centerPoint.x - needleEndSize * cos(perpAngle),
                y: centerPoint.y - needleEndSize * sin(perpAngle)
            )
            
            let needlePath = NSBezierPath()
            needlePath.move(to: tip)
            needlePath.line(to: base1)
            needlePath.line(to: base2)
            needlePath.close()
            
            let needleCirclePath = NSBezierPath(
                roundedRect: NSRect(
                    x: centerPoint.x - needleEndSize,
                    y: centerPoint.y - needleEndSize,
                    width: needleEndSize * 2,
                    height: needleEndSize * 2
                ),
                xRadius: needleEndSize * 2,
                yRadius: needleEndSize * 2
            )
            needleCirclePath.close()
            
            NSColor.systemBlue.setFill()
            needlePath.fill()
            needleCirclePath.fill()
        }
        
        if drawNeedle, let activeSegment = activeSegment {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            let text = "\(activeSegment+1)"
            let width: CGFloat = text.widthOfString(usingFont: NSFont.systemFont(ofSize: 9))
            let rect = CGRect(x: (self.frame.width-width)/2, y: (self.frame.height-26)/2, width: width, height: 12)
            let str = NSAttributedString.init(string: text, attributes: stringAttributes)
            str.draw(with: rect)
        } else if let text = text {
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
        } else if let value = value, drawValue {
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
        let sanitized = value.isFinite ? value : 0
        self.write { self.value = self.openCircle ? (sanitized > 1 ? sanitized/100 : sanitized) : sanitized }
        self.displayIfVisible()
    }
    
    public func setActiveSegment(_ index: Int) {
        self.write { self.activeSegment = index }
        self.displayIfVisible()
    }
    
    public func setText(_ value: String) {
        self.write { self.text = value }
        self.displayIfVisible()
    }
    
    public func setSegments(_ segments: [ColorValue]) {
        self.write { self.segments = segments }
        self.displayIfVisible()
    }
    
    public func setNonActiveSegmentColor(_ newColor: NSColor) {
        self.write {
            guard self.nonActiveSegmentColor != newColor else { return }
            self.nonActiveSegmentColor = newColor
        }
        self.displayIfVisible()
    }
}

public class TachometerGraphView: ChartView {
    private var filled: Bool
    private var segments: [ColorValue]
    
    public init(frame: NSRect = .zero, segments: [ColorValue], filled: Bool = true) {
        self.filled = filled
        self.segments = segments
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Tachometer")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        var filled: Bool = false
        var segments: [ColorValue] = []
        self.read {
            filled = self.filled
            segments = self.segments
        }
        
        let arcWidth: CGFloat = filled ? min(self.frame.width, self.frame.height) / 2 : 7
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(ColorValue(Double(1-totalAmount), color: NSColor.lightGray.withAlphaComponent(0.5)))
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
            
            if let color = segment.color {
                context.setStrokeColor(color.cgColor)
            }
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
    }
    
    internal func setSegments(_ segments: [ColorValue]) {
        self.write { self.segments = segments }
        self.displayIfVisible()
    }
}

public class ColumnChartView: ChartView {
    private var values: [ColorValue] = []
    private var cursor: CGPoint? = nil
    
    public init(frame: NSRect = NSRect.zero, num: Int) {
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Column")
        self.values = Array(repeating: ColorValue(0, color: .controlAccentColor), count: num)
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                .activeAlways,
                .mouseEnteredAndExited,
                .mouseMoved,
                .inVisibleRect
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        var values: [ColorValue] = []
        self.read {
            values = self.values
        }
        
        guard !values.isEmpty else { return }
        
        let blocks: Int = 16
        let spacing: CGFloat = 2
        let count: CGFloat = CGFloat(values.count)
        guard count > 0, self.frame.width > 0, self.frame.height > 0 else { return }
        
        let partitionSize: CGSize = CGSize(width: (self.frame.width - (count*spacing)) / count, height: self.frame.height)
        let blockSize = CGSize(width: partitionSize.width-(spacing*2), height: ((partitionSize.height - spacing - 1)/CGFloat(blocks))-1)
        
        var list: [(value: Double, path: NSBezierPath)] = []
        var x: CGFloat = 0
        for i in 0..<values.count {
            let partition = NSBezierPath(
                roundedRect: NSRect(x: x, y: 0, width: partitionSize.width, height: partitionSize.height),
                xRadius: 3, yRadius: 3
            )
            NSColor.underPageBackgroundColor.withAlphaComponent(0.5).setFill()
            partition.fill()
            partition.close()
            
            let value = values[i]
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
        
        if let p = self.cursor {
            let matchingBlock = list.first(where: { $0.path.contains(p) })
            if let block = matchingBlock {
                let value = "\(Int(block.value.rounded(toPlaces: 2) * 100))%"
                let width: CGFloat = block.value == 1 ? 38 : block.value > 0.1 ? 32 : 24
                let tooltipX = min(p.x+4, self.frame.width - width)
                let tooltipY = min(p.y+4, self.frame.height - partitionSize.height)
                drawToolTip(self.frame, CGPoint(x: tooltipX, y: tooltipY), CGSize(width: width, height: min(partitionSize.height, self.frame.height)), value: value)
            }
        }
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.write { self.values = values }
        self.displayIfVisible()
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
    
    public override func updateTrackingAreas() {
        self.trackingAreas.forEach({ self.removeTrackingArea($0) })
        self.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [
                .activeAlways,
                .mouseEnteredAndExited,
                .mouseMoved,
                .inVisibleRect
            ],
            owner: self, userInfo: nil
        ))
        super.updateTrackingAreas()
    }
}

public class GridChartView: ChartView {
    private let okColor: NSColor = .systemGreen
    private let notOkColor: NSColor = .systemRed
    private let inactiveColor: NSColor = .underPageBackgroundColor.withAlphaComponent(0.4)
    
    private var values: [NSColor] = []
    private let grid: (rows: Int, columns: Int)
    
    public init(frame: NSRect, grid: (rows: Int, columns: Int)) {
        self.grid = grid
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Grid")
        let totalCells = max(grid.rows * grid.columns, 1)
        self.values = Array(repeating: self.inactiveColor, count: totalCells)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        var grid: (rows: Int, columns: Int) = (0, 0)
        var values: [NSColor] = []
        self.read {
            grid = self.grid
            values = self.values
        }
        
        let spacing: CGFloat = 2
        let size: CGSize = CGSize(
            width: (self.frame.width - ((CGFloat(grid.rows)-1) * spacing)) / CGFloat(grid.rows),
            height: (self.frame.height - ((CGFloat(grid.columns)-1) * spacing)) / CGFloat(grid.columns)
        )
        var origin: CGPoint = CGPoint(x: 0, y: (size.height + spacing) * CGFloat(grid.columns - 1))
        
        var i: Int = 0
        for _ in 0..<grid.columns {
            for _ in 0..<grid.rows {
                let box = NSBezierPath(roundedRect: NSRect(origin: origin, size: size), xRadius: 1, yRadius: 1)
                values[i].setFill()
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
        self.write {
            self.values.remove(at: 0)
            self.values.append(value ? self.okColor : self.notOkColor)
        }
        self.displayIfVisible()
    }
}

public class BarChartView: ChartView {
    private var values: [ColorValue] = []
    private var cursor: CGPoint? = nil
    
    private var size: CGFloat?
    private var horizontal: Bool
    
    public init(frame: NSRect = NSRect.zero, size: CGFloat? = nil, horizontal: Bool = false) {
        self.size = size
        self.horizontal = horizontal
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Bar")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        var widthHeight: CGFloat? = nil
        var isHorizontal: Bool = false
        var values: [ColorValue] = []
        self.read {
            widthHeight = self.size
            isHorizontal = self.horizontal
            values = self.values
        }
        
        let totalValue = values.reduce(0) { $0 + $1.value }
        if totalValue < 1 {
            values.append(ColorValue(1 - totalValue, color: NSColor.lightGray.withAlphaComponent(0.25)))
        }
        
        let barSize = widthHeight ?? (isHorizontal ? self.frame.height : self.frame.width)
        let adjustedTotal = values.reduce(0) { $0 + $1.value }
        guard adjustedTotal > 0 else { return }
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let barRect: NSRect = isHorizontal
            ? NSRect(x: 0, y: (self.frame.height - barSize) / 2, width: self.frame.width, height: barSize)
            : NSRect(x: (self.frame.width - barSize) / 2, y: 0, width: barSize, height: self.frame.height)
        let clipPath = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)
        
        context.saveGState()
        clipPath.addClip()
        
        var list: [(value: Double, path: NSBezierPath)] = []
        var offset: CGFloat = 0
        
        for value in values {
            let color = value.color ?? .controlAccentColor
            let segmentLength = CGFloat(value.value / adjustedTotal) * (isHorizontal ? self.frame.width : self.frame.height)
            
            let rect: NSRect = isHorizontal
                ? NSRect(x: offset, y: (self.frame.height - barSize) / 2, width: segmentLength, height: barSize)
                : NSRect(x: (self.frame.width - barSize) / 2, y: offset, width: barSize, height: segmentLength)
            
            let path = NSBezierPath(rect: rect)
            color.setFill()
            path.fill()
            
            list.append((value: value.value, path: path))
            offset += segmentLength
        }
        
        context.restoreGState()
    }
    
    public func setValue(_ values: ColorValue) {
        self.write { self.values = [values] }
        self.displayIfVisible()
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.write { self.values = values }
        self.displayIfVisible()
    }
}
