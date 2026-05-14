//
//  Chart.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class RoundedBarChart: WidgetWrapper {
    private var labelState: Bool = false
    private var boxState: Bool = true
    private var frameState: Bool = false
    private var valueState: Bool = false
    private var valueColorState: Bool = false
    // Liquid Glass / macOS Tahoe pill style. Defaults on for macOS 26+.
    public var liquidGlassState: Bool = Constants.isTahoe
    // Liquid Glass warning thresholds (see BarChart for the same logic).
    private var liquidGlassWarningState: Bool = true
    // Reuses the project's existing `colorZones` typealias so the same
    // breakpoints feed both Utilization color mode (when offered) and the
    // Liquid Glass warning hues. Persisted as two int percentages.
    private var _colorZones: colorZones = (0.6, 0.8)
    // Liquid Glass cosmetic options. See BarChart for the same trio.
    public var liquidGlassPillWidth: Int = 24
    // Pill height. Default of 9pt matches BarChart so a single line/bar
    // pill looks identical across modules; the slider runs 4-14pt for
    // a slimmer or beefier indicator.
    public var liquidGlassPillHeight: Int = 9
    private var liquidGlassOutlineState: Bool = true
    private var liquidGlassOutlineColorKey: String = "utilization"
    private var colorState: SColor = .utilization
    private var historyCount: Int = 60
    private var scaleState: Scale = .none
    
    private var chart: LineChartView = LineChartView(frame: NSRect(
        x: 0,
        y: 0,
        width: 32,
        height: Constants.Widget.height - (2*Constants.Widget.margin.y)
    ), num: 60)
    private var colors: [SColor] = SColor.allCases.filter({ $0 != SColor.cluster })
    private var _value: Double = 0
    private var _splitSegments: [ColorValue] = []
    private var splitSegmentColorsState: Bool = true
    private var _pressureLevel: RAMPressure = .normal
    
    private var historyNumbers: [KeyValue_p] = [
        KeyValue_t(key: "30", value: "30"),
        KeyValue_t(key: "60", value: "60"),
        KeyValue_t(key: "90", value: "90"),
        KeyValue_t(key: "120", value: "120")
    ]
    private var width: CGFloat {
        get {
            switch self.historyCount {
            case 30:
                return 24
            case 60:
                return 32
            case 90:
                return 42
            case 120:
                return 52
            default:
                return 32
            }
        }
    }
    
    private var boxSettingsView: NSSwitch? = nil
    private var frameSettingsView: NSSwitch? = nil
    private var liquidGlassSettingsView: NSSwitch? = nil
    
    public var NSLabelCharts: [NSAttributedString] = []
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let label = config!["Label"] as? Bool {
                self.labelState = label
            }
            if let box = config!["Box"] as? Bool {
                self.boxState = box
            }
            if let value = config!["Value"] as? Bool {
                self.valueState = value
            }
            if let unsupportedColors = config!["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter{ !unsupportedColors.contains($0.key) }
            }
            if let color = config!["Color"] as? String {
                if let defaultColor = colors.first(where: { "\($0.self)" == color }) {
                    self.colorState = defaultColor
                }
            }
        }
        
        super.init(.lineChart, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: 32 + (Constants.Widget.margin.x*2),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.boxState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.frameState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_frame", defaultValue: self.frameState)
            self.valueState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_value", defaultValue: self.valueState)
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.valueColorState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_valueColor", defaultValue: self.valueColorState)
            self.liquidGlassState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_liquidGlass", defaultValue: self.liquidGlassState)
            self.liquidGlassWarningState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_liquidGlassWarning", defaultValue: self.liquidGlassWarningState)
            let storedOrange = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_colorZones_orange", defaultValue: Int(self._colorZones.orange * 100))
            let storedRed = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_colorZones_red", defaultValue: Int(self._colorZones.red * 100))
            self._colorZones = (Double(storedOrange) / 100.0, Double(storedRed) / 100.0)
            self.liquidGlassPillWidth = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillWidth", defaultValue: self.liquidGlassPillWidth)
            self.liquidGlassPillHeight = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillHeight", defaultValue: self.liquidGlassPillHeight)
            self.liquidGlassOutlineState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutline", defaultValue: self.liquidGlassOutlineState)
            self.liquidGlassOutlineColorKey = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutlineColor", defaultValue: self.liquidGlassOutlineColorKey)
            self.colorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
            self.historyCount = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_historyCount", defaultValue: self.historyCount)
            self.scaleState = Scale.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_scale", defaultValue: self.scaleState.key))
            
            self.chart.setScale(self.scaleState)
            self.chart.reinit(self.historyCount)
        }
        
        if self.labelState {
            self.setFrameSize(NSSize(width: Constants.Widget.width + 6 + (Constants.Widget.margin.x*2), height: self.frame.size.height))
        }
        
        if preview {
            var list: [DoubleValue] = []
            for _ in 0..<16 {
                list.append(DoubleValue(Double.random(in: 0..<1)))
            }
            self.chart.setPoints(list)
            self._value = 0.38
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        for char in String(self.title.prefix(3)).uppercased().reversed() {
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            self.NSLabelCharts.append(str)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        var value: Double = 0
        var splitSegments: [ColorValue] = []
        var pressureLevel: RAMPressure = .normal
        self.queue.sync {
            value = self._value
            splitSegments = self._splitSegments
            pressureLevel = self._pressureLevel
        }
        
        var width = self.width + (Constants.Widget.margin.x*2)
        var x: CGFloat = 0
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        var boxSize: CGSize = CGSize(width: self.width - (Constants.Widget.margin.x*2), height: self.frame.size.height)
        
        var color: NSColor = .controlAccentColor
        // Liquid Glass uses a unified color resolution shared with BarChart
        // (square). The classic line-chart path keeps its own switch below
        // so non-Liquid-Glass behavior is unchanged.
        if self.liquidGlassState {
            let total = splitSegments.isEmpty ? value : splitSegments.reduce(0.0) { $0 + $1.value }
            color = self.liquidGlassRowFillColor(rowTotal: total, pressureLevel: pressureLevel)
        } else {
            switch self.colorState {
            case .systemAccent:
                color = .controlAccentColor
            case .utilization: color = value.usageColor()
            case .pressure: color = pressureLevel.pressureColor()
            case .monochrome:
                if self.boxState {
                    color = (isDarkMode ? NSColor.black : NSColor.white)
                } else {
                    color = (isDarkMode ? NSColor.white : NSColor.black)
                }
            default: color = self.colorState.additional as? NSColor ?? .controlAccentColor
            }
        }
        
        // Liquid Glass: short-circuit the line chart and draw a single
        // horizontal pill whose fill grows left-to-right with the current
        // value. The classic line-chart code below is skipped entirely.
        if self.liquidGlassState {
            if !splitSegments.isEmpty {
                self.drawLiquidGlassSplitPill(segments: splitSegments, fallbackColor: color, x: &x, width: &width, lineWidth: lineWidth)
            } else {
                self.drawLiquidGlassPill(value: value, color: color, x: &x, width: &width, lineWidth: lineWidth)
            }
            self.setWidth(width)
            return
        }
        
        if self.labelState {
            let letterHeight = self.frame.height / 3
            let letterWidth: CGFloat = 6.0
            
            var yMargin: CGFloat = 0
            for char in self.NSLabelCharts {
                let rect = CGRect(x: x, y: yMargin, width: letterWidth, height: letterHeight)
                char.draw(with: rect)
                yMargin += letterHeight
            }
            
            width += letterWidth + Constants.Widget.spacing
            x = letterWidth + Constants.Widget.spacing
        }
        
        if self.valueState {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            
            var valueColor = isDarkMode ? NSColor.white : NSColor.black
            if self.valueColorState {
                valueColor = color
            }
            
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 8, weight: .regular),
                NSAttributedString.Key.foregroundColor: valueColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let rect = CGRect(x: x+2, y: boxSize.height-7, width: boxSize.width - 2, height: 7)
            let str = NSAttributedString.init(string: "\(Int((value.rounded(toPlaces: 2)) * 100))%", attributes: stringAttributes)
            str.draw(with: rect)
            
            boxSize.height = offset == 0.5 ? 10 : 9
        }
        
        let box = NSBezierPath(roundedRect: NSRect(
            x: x+offset,
            y: offset,
            width: self.width - offset*2,
            height: boxSize.height - (offset*2)
        ), xRadius: 2, yRadius: 2)
        
        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.stroke()
            box.fill()
            self.chart.setTransparent(false)
        } else if self.frameState {
            self.chart.setTransparent(true)
        } else {
            self.chart.setTransparent(true)
        }

        context.saveGState()
        context.translateBy(x: x+offset+lineWidth, y: offset)

        let chartSize = NSSize(
            width: box.bounds.width - (offset*2+lineWidth),
            height: box.bounds.height - offset
        )
        self.chart.setColor(color)
        self.chart.setFrameSize(chartSize)
        self.chart.draw(NSRect(origin: .zero, size: chartSize))

        context.restoreGState()
        
        if self.boxState || self.frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }
        
        self.setWidth(width)
    }
    
    /// Tahoe-style pill: a single horizontal capsule sized like the menu bar
    /// glyphs. The capsule is outlined and the fill grows from left to right
    /// in proportion to the current value, both in the same color.
    private func drawLiquidGlassPill(value: Double, color: NSColor, x: inout CGFloat, width: inout CGFloat, lineWidth: CGFloat) {
        let strokeWidth: CGFloat = 1.25
        let pillWidth: CGFloat = CGFloat(self.liquidGlassPillWidth)
        let pillHeight: CGFloat = CGFloat(self.liquidGlassPillHeight)
        
        let pillX = x + strokeWidth/2
        let pillY = (self.frame.size.height - pillHeight) / 2
        let radius = pillHeight / 2
        let trackRect = NSRect(x: pillX, y: pillY, width: pillWidth - strokeWidth, height: pillHeight)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: radius, yRadius: radius)
        
        // Outline mode: inset the fill so a small gap separates it from the
        // stroke, and round the inner fill so its ends mirror the outer pill
        // (battery-style). Off: legacy clip-to-outer behavior.
        let useInsetFill = self.liquidGlassOutlineState
        let fillInset: CGFloat = useInsetFill ? max(strokeWidth + 0.75, 1.5) : 0
        let innerRect = trackRect.insetBy(dx: fillInset, dy: fillInset)
        let innerRadius = useInsetFill ? max(radius - fillInset, 0) : radius
        let fillBaseWidth = useInsetFill ? innerRect.width : trackRect.width
        let pct = CGFloat(min(max(value, 0), 1))
        let fillWidth = fillBaseWidth * pct
        
        if fillWidth > 0 {
            NSGraphicsContext.saveGraphicsState()
            if useInsetFill {
                // Build a sub-pill the exact width of the fill so both ends
                // are rounded (not just the leading edge).
                let innerFillRect = NSRect(x: innerRect.origin.x, y: innerRect.origin.y, width: fillWidth, height: innerRect.height)
                let innerFillRadius = min(innerRadius, innerRect.height / 2)
                let innerFill = NSBezierPath(roundedRect: innerFillRect, xRadius: innerFillRadius, yRadius: innerFillRadius)
                color.setFill()
                innerFill.fill()
            } else {
                track.addClip()
                color.setFill()
                NSBezierPath(rect: NSRect(x: trackRect.origin.x, y: pillY, width: fillWidth, height: pillHeight)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // Outline color override: lets the user color-code stroke vs fill.
        let outlineColor = self.resolvedOutlineColor(fallback: color, rowTotal: value)
        outlineColor.setStroke()
        track.lineWidth = strokeWidth
        track.stroke()
        
        width = x + pillWidth + Constants.Widget.margin.x
    }

    /// Split-mode Tahoe pill: renders multiple colored segments separated by
    /// explicit vertical gaps so RAM App/Wired/Compressed parts stay legible
    /// in the rounded-bar style.
    private func drawLiquidGlassSplitPill(segments: [ColorValue], fallbackColor: NSColor, x: inout CGFloat, width: inout CGFloat, lineWidth: CGFloat) {
        let strokeWidth: CGFloat = 1.25
        let pillWidth: CGFloat = CGFloat(self.liquidGlassPillWidth)
        let pillHeight: CGFloat = CGFloat(self.liquidGlassPillHeight)

        let pillX = x + strokeWidth/2
        let pillY = (self.frame.size.height - pillHeight) / 2
        let radius = pillHeight / 2
        let trackRect = NSRect(x: pillX, y: pillY, width: pillWidth - strokeWidth, height: pillHeight)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: radius, yRadius: radius)

        let useInsetFill = self.liquidGlassOutlineState
        let fillInset: CGFloat = useInsetFill ? max(strokeWidth + 0.75, 1.5) : 0
        let innerRect = trackRect.insetBy(dx: fillInset, dy: fillInset)
        let fillBaseWidth = useInsetFill ? innerRect.width : trackRect.width
        let fillBaseY = useInsetFill ? innerRect.origin.y : trackRect.origin.y
        let fillBaseHeight = useInsetFill ? innerRect.height : trackRect.height

        let clampedSegments = segments.map { min(max($0.value, 0), 1) }
        let separatorWidth: CGFloat = clampedSegments.count > 1 ? max(1.25, strokeWidth) : 0
        let totalSeparatorWidth = separatorWidth * CGFloat(max(clampedSegments.count - 1, 0))
        let drawableFillWidth = max(fillBaseWidth - totalSeparatorWidth, 0)

        NSGraphicsContext.saveGraphicsState()
        if useInsetFill {
            NSBezierPath(roundedRect: innerRect, xRadius: max(radius - fillInset, 0), yRadius: max(radius - fillInset, 0)).addClip()
        } else {
            track.addClip()
        }

        var segX = useInsetFill ? innerRect.origin.x : trackRect.origin.x
        let nonZeroSegmentIndices = clampedSegments.enumerated()
            .filter { $0.element > 0 }
            .map { $0.offset }
        let lastVisibleSegmentIndex = nonZeroSegmentIndices.last

        for (idx, seg) in segments.enumerated() {
            let segWidth = drawableFillWidth * CGFloat(clampedSegments[idx])
            guard segWidth > 0 else { continue }

            let fillRect = NSRect(x: segX, y: fillBaseY, width: segWidth, height: fillBaseHeight)
            // Same color rules as BarChart:
            //   - colorState == .systemAccent : ALWAYS liquidGlassInk
            //     (overrides any per-segment color the module supplied).
            //   - split colors ON + per-seg color present : use seg.color
            //   - otherwise : the row's fallback color (already encodes the
            //     utilization threshold hue when colorState=.utilization).
            let segColor: NSColor
            if self.colorState == .systemAccent {
                segColor = Constants.liquidGlassInk
            } else if self.splitSegmentColorsState, let c = seg.color {
                segColor = c
            } else {
                segColor = fallbackColor
            }
            segColor.setFill()

            if idx == lastVisibleSegmentIndex {
                // Only the far-right edge should be rounded; the split edge
                // on the left stays flat so segment boundaries remain crisp.
                let tailRadius = min(fillRect.height / 2, fillRect.width / 2)
                if tailRadius > 0 {
                    let minX = fillRect.minX
                    let maxX = fillRect.maxX
                    let minY = fillRect.minY
                    let maxY = fillRect.maxY

                    let path = NSBezierPath()
                    path.move(to: NSPoint(x: minX, y: minY))
                    path.line(to: NSPoint(x: maxX - tailRadius, y: minY))
                    path.appendArc(withCenter: NSPoint(x: maxX - tailRadius, y: minY + tailRadius), radius: tailRadius, startAngle: 270, endAngle: 0)
                    path.line(to: NSPoint(x: maxX, y: maxY - tailRadius))
                    path.appendArc(withCenter: NSPoint(x: maxX - tailRadius, y: maxY - tailRadius), radius: tailRadius, startAngle: 0, endAngle: 90)
                    path.line(to: NSPoint(x: minX, y: maxY))
                    path.close()
                    path.fill()
                } else {
                    NSBezierPath(rect: fillRect).fill()
                }
            } else {
                NSBezierPath(rect: fillRect).fill()
            }

            segX += segWidth
            if idx < segments.count - 1 {
                segX += separatorWidth
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let outlineColor = self.resolvedOutlineColor(fallback: fallbackColor, rowTotal: segments.reduce(0.0) { $0 + $1.value })
        outlineColor.setStroke()
        track.lineWidth = strokeWidth
        track.stroke()

        width = x + pillWidth + Constants.Widget.margin.x
    }
    
    /// Resolve the base "row color" for the Liquid Glass pill, given the
    /// user's color preference and the row total (used for utilization
    /// thresholds). Mirrors `BarChart.liquidGlassRowFillColor` so square
    /// and rounded widgets behave identically.
    private func liquidGlassRowFillColor(rowTotal: Double, pressureLevel: RAMPressure) -> NSColor {
        switch self.colorState {
        case .systemAccent: return Constants.liquidGlassInk
        case .utilization:
            return Constants.liquidGlassWarningColor(
                value: rowTotal,
                warning: self._colorZones.orange,
                critical: self._colorZones.red
            )
        case .pressure:     return pressureLevel.pressureColor()
        case .monochrome:   return Constants.liquidGlassInk
        default:            return self.colorState.additional as? NSColor ?? Constants.liquidGlassInk
        }
    }
    
    /// Resolve the outline color override; "same" reuses the fill,
    /// "utilization" uses the threshold-driven warning color (system
    /// accent / yellow / red), otherwise the user's picked SColor.
    private func resolvedOutlineColor(fallback: NSColor, rowTotal: Double) -> NSColor {
        if self.liquidGlassOutlineColorKey == "same" {
            return fallback
        }
        if self.liquidGlassOutlineColorKey == "utilization" {
            return Constants.liquidGlassWarningColor(
                value: rowTotal,
                warning: self._colorZones.orange,
                critical: self._colorZones.red
            )
        }
        guard let picked = self.colors.first(where: { $0.key == self.liquidGlassOutlineColorKey }),
              let color = picked.additional as? NSColor
        else { return fallback }
        return color.withAlphaComponent(0.85)
    }
    
    public func setValue(_ newValue: Double) {
        DispatchQueue.main.async(execute: {
            self._value = newValue
            self._splitSegments = []
            self.tooltipCallback?("\(Int(newValue.rounded(toPlaces: 2) * 100))%")
            self.chart.addValue(newValue)
            self.display()
        })
    }

    public func setSegments(_ newSegments: [ColorValue]) {
        DispatchQueue.main.async(execute: {
            self._splitSegments = newSegments
            self._value = newSegments.reduce(0) { $0 + $1.value }
            self.tooltipCallback?("\(Int(self._value.rounded(toPlaces: 2) * 100))%")
            self.chart.addValue(self._value)
            self.display()
        })
    }

    public func setSplitColorized(_ state: Bool) {
        DispatchQueue.main.async(execute: {
            guard self.splitSegmentColorsState != state else { return }
            self.splitSegmentColorsState = state
            self.display()
        })
    }
    
    public func setPressure(_ newPressureLevel: RAMPressure) {
        DispatchQueue.main.async(execute: {
            guard self._pressureLevel != newPressureLevel else { return }
            self._pressureLevel = newPressureLevel
            self.display()
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        let box = switchView(
            action: #selector(self.toggleBox),
            state: self.boxState
        )
        self.boxSettingsView = box
        let frame = switchView(
            action: #selector(self.toggleFrame),
            state: self.frameState
        )
        self.frameSettingsView = frame
        let liquid = switchView(
            action: #selector(self.toggleLiquidGlass),
            state: self.liquidGlassState
        )
        self.liquidGlassSettingsView = liquid
        
        // Outline color picker: only real hues (semantic SColors like
        // Pressure / System accent / Monochrome are filtered).
        // "Same as fill" and "Based on utilization" are explicit sentinel options.
        let outlineExcluded: Set<String> = ["system", "monochrome", "utilization", "pressure", "cluster", "clear"]
        var outlineColors: [KeyValue_t] = [
            KeyValue_t(key: "same", value: "Same as fill"),
            KeyValue_t(key: "utilization", value: "Based on utilization")
        ]
        for c in self.colors where !outlineExcluded.contains(c.key) && !c.key.contains("separator") {
            outlineColors.append(KeyValue_t(key: c.key, value: c.value))
        }
        
        // Section 1: appearance — every control that affects how the chart
        // looks. Box/Frame is classic-mode only and the Bar width / Outline
        // / Outline color trio is Liquid Glass only; grouped here so the
        // user has a single place to tune visual style.
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Liquid Glass (Tahoe)"), component: liquid),
            PreferencesRow(localizedString("Label"), component: switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Value"), component: switchView(
                action: #selector(self.toggleValue),
                state: self.valueState
            )),
            PreferencesRow(localizedString("Color"), component: selectView(
                action: #selector(self.toggleColor),
                items: self.colors,
                selected: self.colorState.key
            )),
            PreferencesRow(localizedString("Colorize value"), component: switchView(
                action: #selector(self.toggleValueColor),
                state: self.valueColorState
            )),
            PreferencesRow(localizedString("Bar width"), component: sliderView(
                action: #selector(self.changeLiquidGlassPillWidth),
                value: self.liquidGlassPillWidth,
                initialValue: "\(self.liquidGlassPillWidth)",
                min: 16,
                max: 60
            )),
            PreferencesRow(localizedString("Bar height"), component: sliderView(
                action: #selector(self.changeLiquidGlassPillHeight),
                value: self.liquidGlassPillHeight,
                initialValue: "\(self.liquidGlassPillHeight)",
                min: 4,
                max: 14
            )),
            PreferencesRow(localizedString("Outline"), component: switchView(
                action: #selector(self.toggleLiquidGlassOutline),
                state: self.liquidGlassOutlineState
            )),
            PreferencesRow(localizedString("Outline color"), component: selectView(
                action: #selector(self.toggleLiquidGlassOutlineColor),
                items: outlineColors,
                selected: self.liquidGlassOutlineColorKey
            )),
            PreferencesRow(localizedString("Box"), component: box),
            PreferencesRow(localizedString("Frame"), component: frame),
            PreferencesRow(localizedString("Number of reads in the chart"), component: selectView(
                action: #selector(self.toggleHistoryCount),
                items: self.historyNumbers,
                selected: "\(self.historyCount)"
            )),
            PreferencesRow(localizedString("Scaling"), component: selectView(
                action: #selector(self.toggleScale),
                items: Scale.allCases.filter({ $0 != .fixed }),
                selected: self.scaleState.key
            ))
        ]))
        
        // Section 2: warning thresholds (mirrors the BarChart UI).
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Warning colors"), component: switchView(
                action: #selector(self.toggleLiquidGlassWarning),
                state: self.liquidGlassWarningState
            )),
            PreferencesRow(localizedString("Warning threshold"), component: sliderView(
                action: #selector(self.changeWarningThreshold),
                value: Int(self._colorZones.orange * 100),
                initialValue: "\(Int(self._colorZones.orange * 100))%"
            )),
            PreferencesRow(localizedString("Critical threshold"), component: sliderView(
                action: #selector(self.changeCriticalThreshold),
                value: Int(self._colorZones.red * 100),
                initialValue: "\(Int(self._colorZones.red * 100))%"
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        self.labelState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        self.display()
    }
    
    @objc private func toggleBox(_ sender: NSControl) {
        self.boxState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        
        if self.frameState {
            self.frameSettingsView?.state = .off
            self.frameState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        }
        
        self.display()
    }
    
    @objc private func toggleFrame(_ sender: NSControl) {
        self.frameState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        
        if self.boxState {
            self.boxSettingsView?.state = .off
            self.boxState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        }
        
        self.display()
    }
    
    @objc private func toggleValue(_ sender: NSControl) {
        self.valueState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_value", value: self.valueState)
        self.display()
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SColor.allCases.first(where: { $0.key == key }) {
            self.colorState = newColor
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: key)
        self.display()
    }
    
    @objc private func toggleValueColor(_ sender: NSControl) {
        self.valueColorState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_valueColor", value: self.valueColorState)
        self.display()
    }
    
    @objc private func toggleLiquidGlass(_ sender: NSControl) {
        self.liquidGlassState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlass", value: self.liquidGlassState)
        // The classic Box/Frame chrome would composite with the capsule; turn
        // them off when Liquid Glass is enabled to avoid double-stroking.
        if self.liquidGlassState {
            if self.boxState {
                self.boxState = false
                self.boxSettingsView?.state = .off
                Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
            }
            if self.frameState {
                self.frameState = false
                self.frameSettingsView?.state = .off
                Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
            }
        }
        self.display()
    }
    
    @objc private func toggleHistoryCount(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.historyCount = value
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_historyCount", value: value)
        self.chart.reinit(value)
        self.display()
    }
    
    @objc private func toggleScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.scaleState = value
        self.chart.setScale(value)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_scale", value: key)
        self.display()
    }
    
    @objc private func toggleLiquidGlassWarning(_ sender: NSControl) {
        self.liquidGlassWarningState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassWarning", value: self.liquidGlassWarningState)
        self.display()
    }
    
    @objc private func changeWarningThreshold(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        let clamped = min(newValue, Int(self._colorZones.red * 100) - 1)
        self._colorZones.orange = Double(clamped) / 100.0
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_colorZones_orange", value: clamped)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(clamped)%"
        }
        self.display()
    }
    
    @objc private func changeCriticalThreshold(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        let clamped = max(newValue, Int(self._colorZones.orange * 100) + 1)
        self._colorZones.red = Double(clamped) / 100.0
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_colorZones_red", value: clamped)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(clamped)%"
        }
        self.display()
    }
    
    @objc private func changeLiquidGlassPillWidth(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        self.liquidGlassPillWidth = newValue
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillWidth", value: newValue)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(newValue)"
        }
        self.display()
    }
    
    @objc private func changeLiquidGlassPillHeight(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        self.liquidGlassPillHeight = newValue
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillHeight", value: newValue)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(newValue)"
        }
        self.display()
    }
    
    @objc private func toggleLiquidGlassOutline(_ sender: NSControl) {
        self.liquidGlassOutlineState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutline", value: self.liquidGlassOutlineState)
        self.display()
    }
    
    @objc private func toggleLiquidGlassOutlineColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.liquidGlassOutlineColorKey = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutlineColor", value: key)
        self.display()
    }
}
