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
// swiftlint:disable file_length

import Cocoa
import QuartzCore

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
    
    fileprivate var animationEnabled: Bool = false
    fileprivate let animationDuration: CFTimeInterval = 0.25
    
    fileprivate init(frame: NSRect, queueLabel: String) {
        self.stateQueue = DispatchQueue(label: queueLabel, attributes: .concurrent)
        super.init(frame: frame)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
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
        self.onMain { [weak self] in
            guard let self, self.window?.isVisible ?? false else { return }
            self.needsDisplay = true
        }
    }
    
    public func setAnimation(_ enabled: Bool) {
        self.write { self.animationEnabled = enabled }
    }
    
    fileprivate var animationsAllowed: Bool {
        self.read { self.animationEnabled } && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    fileprivate func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    fileprivate func fadeTransition() {
        let transition = CATransition()
        transition.type = .fade
        transition.duration = self.animationDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.layer?.add(transition, forKey: kCATransition)
    }
    
    fileprivate func slideTransition(_ dx: CGFloat, duration: CFTimeInterval) {
        guard dx != 0 else { return }
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = dx
        animation.toValue = 0
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        self.layer?.add(animation, forKey: "slide")
    }
    
    fileprivate func fadeOrDisplay() {
        self.onMain { [weak self] in
            guard let self, self.window?.isVisible ?? false else { return }
            if self.animationsAllowed {
                self.fadeTransition()
            }
            self.needsDisplay = true
        }
    }
}

public class LineChartView: ChartView {
    private static let xLegendFont = NSFont.systemFont(ofSize: 9, weight: .light)
    private static let xLegendSampleWidth = "00:00:00".widthOfString(usingFont: xLegendFont)
    
    private let dateFormatter = DateFormatter()
    
    private var points: [DoubleValue?]
    private var head: Int = 0
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
    private var lastSlideAt: CFTimeInterval = 0
    
    private var tooltipEnabledSnapshot: Bool {
        self.read { self.isTooltipEnabled }
    }
    
    public init(
        frame: NSRect = .zero,
        num: Int,
        suffix: String = "%",
        color: NSColor = .controlAccentColor,
        scale: Scale = .none,
        fixedScale: Double = 1,
        zeroValue: Double = 0.01,
        animation: Bool = true
    ) {
        self.points = Array(repeating: nil, count: max(num, 1))
        self.suffix = suffix
        self.color = color
        self.scale = scale
        self.fixedScale = fixedScale
        self.zeroValue = zeroValue
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Line")
        self.animationEnabled = animation
        
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
            originalPoints = self.orderedPointsLocked()
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
        var maxValue: Double = 0
        for opt in points {
            if let p = opt, p.value > maxValue { maxValue = p.value }
        }
        
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
        let needList = xLegend || (isTooltipEnabled && self.cursor != nil)
        
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
            if needList {
                list.append((value: v, point: point))
            }
        }
        if !line.isEmpty {
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
            let legendFont = LineChartView.xLegendFont
            let legendAttributes: [NSAttributedString.Key: Any] = [
                .font: legendFont,
                .foregroundColor: (isDarkMode ? NSColor.white : NSColor.textColor).withAlphaComponent(0.5)
            ]
            
            let sampleWidth = LineChartView.xLegendSampleWidth
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
            
            var over: (value: DoubleValue, point: CGPoint)?
            var overDist: CGFloat = .greatestFiniteMagnitude
            var under: (value: DoubleValue, point: CGPoint)?
            var underDist: CGFloat = .greatestFiniteMagnitude
            for item in list {
                let d = item.point.x - p.x
                if d >= 0, d < overDist { over = item; overDist = d }
                if d <= 0, -d < underDist { under = item; underDist = -d }
            }
            
            if let over, let under {
                let nearest = (overDist < underDist) ? over : under
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
        if self.tooltipEnabledSnapshot {
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
        }
        super.updateTrackingAreas()
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard self.tooltipEnabledSnapshot else { return nil }
        return super.hitTest(point)
    }
    
    public func addValue(_ value: DoubleValue) {
        self.write {
            let n = self.points.count
            guard n > 0 else { return }
            
            if let stats = self.intervalStatsLocked() {
                let gap = value.ts.timeIntervalSince(stats.lastTs)
                if gap >= 2.0, gap > stats.typical * 1.5 {
                    let missing = min(Int((gap / stats.typical).rounded()) - 1, n - 1)
                    for _ in 0..<max(0, missing) {
                        self.points[self.head] = nil
                        self.head = (self.head + 1) % n
                    }
                }
            }
            
            self.points[self.head] = value
            self.head = (self.head + 1) % n
        }
        self.onMain { [weak self] in
            guard let self, self.window?.isVisible ?? false else { return }
            let state = self.read { (n: self.points.count, yLegend: self.yLegend) }
            let dx = state.n > 1 ? (self.bounds.width - (state.yLegend ? 30 : 0)) / CGFloat(state.n - 1) : 0
            guard dx >= 1, !self.stop, self.animationsAllowed else {
                self.needsDisplay = true
                return
            }
            let now = CACurrentMediaTime()
            let dt = self.lastSlideAt == 0 ? self.animationDuration : now - self.lastSlideAt
            self.lastSlideAt = now
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.slideTransition(dx, duration: min(max(dt, 0.1), 1.0))
            self.display()
            CATransaction.commit()
        }
    }
    
    private func orderedPointsLocked() -> [DoubleValue?] {
        let n = self.points.count
        guard n > 0 else { return [] }
        var result: [DoubleValue?] = []
        result.reserveCapacity(n)
        for i in 0..<n {
            result.append(self.points[(self.head + i) % n])
        }
        return result
    }
    
    private func intervalStatsLocked() -> (lastTs: Date, typical: TimeInterval)? {
        var deltas: [TimeInterval] = []
        var prev: Date?
        var lastTs: Date?
        let n = self.points.count
        for i in 0..<n {
            let p = self.points[(self.head + i) % n]
            if let p {
                if let prev {
                    let d = p.ts.timeIntervalSince(prev)
                    if d > 0 { deltas.append(d) }
                }
                prev = p.ts
                lastTs = p.ts
            } else {
                prev = nil
            }
        }
        guard let lastTs, deltas.count >= 2 else { return nil }
        deltas.sort()
        return (lastTs, deltas[deltas.count / 2])
    }
    
    public func addValue(_ value: Double) {
        self.addValue(DoubleValue(value))
    }
    
    public func reinit(_ num: Int = 60) {
        self.write {
            guard self.points.count != num else { return }
            let ordered = self.orderedPointsLocked()
            if num < ordered.count {
                self.points = Array(ordered.suffix(num))
            } else {
                var arr: [DoubleValue?] = Array(repeating: nil, count: num)
                arr.replaceSubrange((num-ordered.count)..<num, with: ordered)
                self.points = arr
            }
            self.head = 0
        }
        self.onMain { [weak self] in
            self?.layer?.removeAnimation(forKey: "slide")
            self?.displayIfVisible()
        }
    }
    
    public func setScale(_ newScale: Scale, fixedScale: Double = 1) {
        guard self.read({ self.scale != newScale || self.fixedScale != fixedScale }) else { return }
        self.write {
            self.scale = newScale
            self.fixedScale = fixedScale
        }
        self.displayIfVisible()
    }
    
    public func setPoints(_ newPoints: [DoubleValue]) {
        self.write {
            self.points = newPoints.map { Optional($0) }
            self.head = 0
        }
        self.onMain { [weak self] in
            self?.layer?.removeAnimation(forKey: "slide")
            self?.displayIfVisible()
        }
    }
    
    public func setColor(_ newColor: NSColor) {
        guard self.read({ self.color }) != newColor else { return }
        self.write { self.color = newColor }
        self.displayIfVisible()
    }
    
    public func setSuffix(_ newSuffix: String) {
        guard self.read({ self.suffix }) != newSuffix else { return }
        self.write { self.suffix = newSuffix }
        self.displayIfVisible()
    }
    
    public func setTransparent(_ newValue: Bool) {
        guard self.read({ self.transparent }) != newValue else { return }
        self.write { self.transparent = newValue }
        self.displayIfVisible()
    }
    
    public func setFlipY(_ newValue: Bool) {
        guard self.read({ self.flipY }) != newValue else { return }
        self.write { self.flipY = newValue }
        self.displayIfVisible()
    }
    
    public func setMinMax(_ newValue: Bool) {
        guard self.read({ self.minMax }) != newValue else { return }
        self.write { self.minMax = newValue }
        self.displayIfVisible()
    }
    
    public func setToolTipFunc(_ newValue: ((DoubleValue) -> String)?) {
        self.write { self.toolTipFunc = newValue }
    }
    
    public func setTooltipEnabled(_ newValue: Bool) {
        self.write { self.isTooltipEnabled = newValue }
        self.updateTrackingAreas()
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
        self.write { self.shadowPoints = self.orderedPointsLocked() }
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
    
    public init(
        frame: NSRect = .zero,
        num: Int,
        minMax: Bool = true,
        reversedOrder: Bool = false,
        outColor: NSColor = .systemRed,
        inColor: NSColor = .systemBlue,
        scale: Scale = .none,
        fixedScale: Double = 1,
        animation: Bool = true
    ) {
        self.reversedOrder = reversedOrder
        
        let safeHeight = max(frame.height, 2)
        let topFrame = NSRect(x: frame.origin.x, y: safeHeight/2, width: frame.width, height: safeHeight/2)
        let bottomFrame = NSRect(x: frame.origin.x, y: 0, width: frame.width, height: safeHeight/2)
        let inFrame = self.reversedOrder ? topFrame : bottomFrame
        let outFrame = self.reversedOrder ? bottomFrame : topFrame
        self.inChart = LineChartView(frame: inFrame, num: num, color: inColor, scale: scale, fixedScale: fixedScale, zeroValue: 256.0, animation: animation)
        self.outChart = LineChartView(frame: outFrame, num: num, color: outColor, scale: scale, fixedScale: fixedScale, zeroValue: 256.0, animation: animation)
        
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
    
    public override func setAnimation(_ enabled: Bool) {
        self.inChart.setAnimation(enabled)
        self.outChart.setAnimation(enabled)
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
    
    public func setLegend(x: Bool, y: Bool) {
        self.inChart.setLegend(x: x, y: y)
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        let safeHeight = max(newSize.height, 2)
        let halfHeight = safeHeight/2
        let topFrame = NSRect(x: 0, y: halfHeight, width: newSize.width, height: halfHeight)
        let bottomFrame = NSRect(x: 0, y: 0, width: newSize.width, height: halfHeight)
        
        self.inChart.frame = self.reversedOrder ? topFrame : bottomFrame
        self.outChart.frame = self.reversedOrder ? bottomFrame : topFrame
    }
}

public class PieChartView: ChartView {
    private var filled: Bool
    private var drawValue: Bool
    private var lineCap: CGLineCap
    private var segments: [ColorValue]
    
    private var nonActiveSegmentColor: NSColor = NSColor.lightGray
    private var value: Double? = nil
    private var maxValue: Double = 1
    private var text: String? = nil
    private var color: NSColor = NSColor.systemBlue
    
    public init(
        frame: NSRect = .zero,
        segments: [ColorValue] = [],
        filled: Bool = false,
        drawValue: Bool = false,
        animation: Bool = true,
        lineCap: CGLineCap = .round
    ) {
        self.filled = filled
        self.drawValue = drawValue
        self.segments = segments
        self.lineCap = lineCap
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Pie")
        self.animationEnabled = animation
        
        self.setAccessibilityElement(true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        var filled: Bool = false
        var drawValue: Bool = false
        var nonActiveSegmentColor: NSColor = NSColor.lightGray
        var value: Double? = nil
        var text: String? = nil
        var segments: [ColorValue] = []
        var color: NSColor = NSColor.systemBlue
        var lineCap: CGLineCap = .butt
        self.read {
            filled = self.filled
            drawValue = self.drawValue
            nonActiveSegmentColor = self.nonActiveSegmentColor
            value = self.value
            text = self.text
            segments = self.segments
            color = self.color
            lineCap = self.lineCap
        }
        
        let arcWidth: CGFloat = filled ? min(self.frame.width, self.frame.height) / 2 : 7
        let fullCircle: CGFloat = 2 * CGFloat.pi
        if segments.isEmpty {
            segments = [ColorValue(value ?? 0, color: color)]
        }
        
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(ColorValue(Double(1-totalAmount), color: nonActiveSegmentColor.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(lineCap)
        
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
        
        if let text = text {
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
            let fontSize: CGFloat = min(15, 15 * pow(min(self.frame.width, self.frame.height) / 60, 1.7))
            let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            let stringAttributes = [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            let percentage = "\(Int(value.rounded(toPlaces: 2) * 100))%"
            let width: CGFloat = percentage.widthOfString(usingFont: font)
            let rect = CGRect(x: (self.frame.width-width)/2, y: (self.frame.height-fontSize*11/15)/2, width: width, height: fontSize*12/15)
            let str = NSAttributedString.init(string: percentage, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        let sanitized = value.isFinite ? value : 0
        self.write {
            if sanitized > 1 {
                if sanitized > self.maxValue {
                    self.maxValue = sanitized
                }
                self.value = sanitized / self.maxValue
            } else {
                self.value = sanitized
            }
        }
        self.fadeOrDisplay()
    }
    
    public func setText(_ value: String) {
        self.write { self.text = value }
        self.displayIfVisible()
    }
    
    public func setSegments(_ segments: [ColorValue]) {
        self.write { self.segments = segments }
        self.fadeOrDisplay()
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
    
    public init(frame: NSRect = .zero, segments: [ColorValue], filled: Bool = true, animation: Bool = true) {
        self.filled = filled
        self.segments = segments
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Tachometer")
        self.animationEnabled = animation
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
        self.fadeOrDisplay()
    }
}

public class GaugeChartView: ChartView {
    private var segments: [ColorValue]
    private var activeSegment: Int? = nil
    private var title: String? = nil
    
    public init(frame: NSRect = .zero, segments: [ColorValue], title: String? = nil, animation: Bool = true) {
        self.segments = segments
        self.title = title
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Gauge")
        self.animationEnabled = animation
        
        self.setAccessibilityElement(true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        var segments: [ColorValue] = []
        var activeSegment: Int? = nil
        var title: String? = nil
        self.read {
            segments = self.segments
            activeSegment = self.activeSegment
            title = self.title
        }
        guard let context = NSGraphicsContext.current?.cgContext, !segments.isEmpty else { return }
        context.setShouldAntialias(true)
        
        let labelHeight: CGFloat = title != nil ? 13 : 0
        let arcWidth: CGFloat = 6
        let bottomPadding: CGFloat = labelHeight + 1
        let centerPoint = CGPoint(x: self.frame.width/2, y: bottomPadding)
        let availableHeight = self.frame.height - bottomPadding
        let radius = min(self.frame.width/2, availableHeight) - arcWidth/2 - 1
        
        let total = segments.reduce(0) { $0 + $1.value }
        let count = segments.count
        let gap: CGFloat = count > 1 ? 0.025 * CGFloat.pi : 0
        let drawSpan = CGFloat.pi - gap * CGFloat(count - 1)
        
        var ranges: [(start: CGFloat, end: CGFloat)] = []
        var previousAngle = CGFloat.pi
        for segment in segments {
            let frac: CGFloat = total > 0 ? CGFloat(segment.value)/CGFloat(total) : 0
            let currentAngle = previousAngle - frac * drawSpan
            ranges.append((previousAngle, currentAngle))
            previousAngle = currentAngle - gap
        }
        
        context.setLineWidth(arcWidth)
        context.setLineCap(.round)
        
        for i in 0..<segments.count {
            if let color = segments[i].color {
                context.setStrokeColor(color.cgColor)
            }
            context.addArc(center: centerPoint, radius: radius, startAngle: ranges[i].start, endAngle: ranges[i].end, clockwise: true)
            context.strokePath()
        }
        
        if let activeSegment, activeSegment >= 0, activeSegment < ranges.count {
            let range = ranges[activeSegment]
            let needleAngle = (range.start + range.end) / 2
            let needleEndSize: CGFloat = 2
            let needleLength = radius - arcWidth/2 - 1

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
        
        if let title {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            let str = NSAttributedString(string: title, attributes: stringAttributes)
            let size = str.size()
            str.draw(with: CGRect(x: 0, y: 0, width: self.frame.width, height: size.height))
        }
    }
    
    public func setActiveSegment(_ index: Int) {
        self.write { self.activeSegment = index }
        self.fadeOrDisplay()
    }
    
    public func setTitle(_ value: String) {
        self.write {
            guard self.title != value else { return }
            self.title = value
        }
        self.displayIfVisible()
    }
    
    public func setSegments(_ segments: [ColorValue]) {
        self.write { self.segments = segments }
        self.fadeOrDisplay()
    }
}

public class ColumnChartView: ChartView {
    private var values: [ColorValue] = []
    private var cursor: CGPoint? = nil
    
    public init(frame: NSRect = NSRect.zero, num: Int, animation: Bool = true) {
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Column")
        self.animationEnabled = animation
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
        
        let spacing: CGFloat = 2
        let count: CGFloat = CGFloat(values.count)
        guard count > 0, self.frame.width > 0, self.frame.height > 0 else { return }
        
        let partitionSize: CGSize = CGSize(width: (self.frame.width - (count*spacing)) / count, height: self.frame.height)
        let radius: CGFloat = min(3, partitionSize.width/2)
        
        var list: [(value: Double, path: NSBezierPath)] = []
        var x: CGFloat = 0
        for i in 0..<values.count {
            let track = NSBezierPath(
                roundedRect: NSRect(x: x, y: 0, width: partitionSize.width, height: partitionSize.height),
                xRadius: radius, yRadius: radius
            )
            NSColor.underPageBackgroundColor.withAlphaComponent(0.25).setFill()
            track.fill()
            track.close()
            
            let value = values[i]
            let color = value.color ?? .controlAccentColor
            let h = min(max(0, CGFloat(value.value) * partitionSize.height), partitionSize.height)
            
            if h > 0 {
                let fill = NSBezierPath(
                    roundedRect: NSRect(x: x, y: 0, width: partitionSize.width, height: h),
                    xRadius: radius, yRadius: radius
                )
                if let gradient = NSGradient(colors: [
                    color.withAlphaComponent(0.5),
                    color.withAlphaComponent(1.0)
                ]) {
                    gradient.draw(in: fill, angle: 90)
                } else {
                    color.setFill()
                    fill.fill()
                }
                fill.close()
            }
            
            x += partitionSize.width + spacing
            list.append((value: value.value, path: track))
        }
        
        if let p = self.cursor {
            let matchingBlock = list.first(where: { $0.path.contains(p) })
            if let block = matchingBlock {
                let value = "\(Int(block.value.rounded(toPlaces: 2) * 100))%"
                let width: CGFloat = block.value == 1 ? 38 : block.value > 0.1 ? 32 : 24
                let tooltipHeight: CGFloat = 12
                let gap: CGFloat = 4
                let tooltipX = min(p.x + gap, self.bounds.width - width)
                let tooltipY = (self.bounds.height - p.y) < (tooltipHeight + gap) ? (p.y - tooltipHeight - gap - 10) : (p.y + gap)
                drawToolTip(self.bounds, CGPoint(x: tooltipX, y: tooltipY), CGSize(width: width, height: self.bounds.height), value: value)
            }
        }
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.write { self.values = values }
        self.fadeOrDisplay()
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
    
    private var values: [ColorValue?] = []
    private let grid: (rows: Int, columns: Int)
    
    private let dateFormatter = DateFormatter()
    private var cursor: NSPoint? = nil
    
    public init(frame: NSRect = .zero, grid: (rows: Int, columns: Int)) {
        self.grid = grid
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Grid")
        let totalCells = max(grid.rows * grid.columns, 1)
        self.values = Array(repeating: nil, count: totalCells)
        
        self.dateFormatter.dateFormat = "HH:mm:ss"
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        var grid: (rows: Int, columns: Int) = (0, 0)
        var values: [ColorValue?] = []
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
        
        let cursor = self.cursor
        var hovered: ColorValue? = nil
        
        var i: Int = 0
        for _ in 0..<grid.columns {
            for _ in 0..<grid.rows {
                let rect = NSRect(origin: origin, size: size)
                let box = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
                (values[i]?.color ?? self.inactiveColor).setFill()
                box.fill()
                box.close()
                if let c = cursor, rect.contains(c), let v = values[i] {
                    hovered = v
                }
                i += 1
                origin.x += size.width + spacing
            }
            origin.x = 0
            origin.y -= size.height + spacing
        }
        
        if let v = hovered, let c = cursor {
            let text = self.dateFormatter.string(from: v.ts)
            let font = NSFont.systemFont(ofSize: 12, weight: .regular)
            let tooltipWidth = text.widthOfString(usingFont: font).rounded(.up) + 6
            let tooltipHeight: CGFloat = 12
            let tooltipX = c.x + 6 + tooltipWidth > self.frame.size.width
                ? c.x - tooltipWidth - 6
                : c.x + 6
            let tooltipY = c.y + 6
            drawToolTip(self.frame, CGPoint(x: tooltipX, y: tooltipY), CGSize(width: tooltipWidth, height: tooltipHeight), value: text)
        }
    }
    
    public func addValue(_ value: Bool) {
        self.write {
            self.values.remove(at: 0)
            self.values.append(ColorValue(value ? 1 : 0, color: value ? self.okColor : self.notOkColor))
        }
        self.displayIfVisible()
    }
    
    public override func mouseEntered(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseMoved(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        self.cursor = nil
        self.needsDisplay = true
    }
    
    public override func updateTrackingAreas() {
        self.trackingAreas.forEach({ self.removeTrackingArea($0) })
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self, userInfo: nil
        ))
        super.updateTrackingAreas()
    }
}

public class BarChartView: ChartView {
    private var values: [ColorValue] = []
    
    private var size: CGFloat?
    private var horizontal: Bool
    
    public init(frame: NSRect = NSRect.zero, size: CGFloat? = nil, horizontal: Bool = false, animation: Bool = true) {
        self.size = size
        self.horizontal = horizontal
        
        super.init(frame: frame, queueLabel: "eu.exelban.Stats.Charts.Bar")
        self.animationEnabled = animation
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
        self.fadeOrDisplay()
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.write { self.values = values }
        self.fadeOrDisplay()
    }
}
