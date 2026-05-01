//
//  BarChart.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 26/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class BarChart: WidgetWrapper {
    private var labelState: Bool = false
    private var boxState: Bool = true
    private var frameState: Bool = false
    // Liquid Glass / macOS Tahoe pill style: full-radius capsule, thicker outline,
    // single accent color used for both stroke and fill, fully transparent empty space.
    // Default is on for macOS 26 (Tahoe) and later, off on older systems so the
    // widget keeps its classic appearance there.
    public var liquidGlassState: Bool = Constants.isTahoe
    // When the Liquid Glass style is on with the default (system accent)
    // color, the existing `colorZones` thresholds are reused to tint a row
    // yellow / red as it approaches saturation. The toggle below lets the
    // user disable that behavior; the actual breakpoints come from the
    // shared `_colorZones` ivar.
    private var liquidGlassWarningState: Bool = true
    // Liquid Glass cosmetic options. Width is the per-pill horizontal size,
    // outline draws the stroke offset slightly from the fill (battery-style)
    // and outlineColor lets the user color-code the stroke independently of
    // the fill (e.g. orange CPU outline vs blue GPU outline).
    public var liquidGlassPillWidth: Int = 24
    // Per-row pill height. Default of 9pt sits between the historical
    // multi-row (6pt) and single-row (10pt) caps; the slider lets the
    // user push it shorter for a slimmer indicator or taller (up to 14pt)
    // for a beefier one. Multi-row stacks (e.g. CPU per-core, network
    // up/down) are bounded by `rawRowHeight` so this cap effectively
    // only changes the single-row look.
    public var liquidGlassPillHeight: Int = 9
    private var liquidGlassOutlineState: Bool = true
    // "same" is a sentinel meaning "use the same color as the fill".
    private var liquidGlassOutlineColorKey: String = "same"
    public var colorState: SColor = .systemAccent
    private var colors: [SColor] = SColor.allCases
    
    private var _value: [[ColorValue]] = [[]]
    private var _pressureLevel: RAMPressure = .normal
    private var _colorZones: colorZones = (0.6, 0.8)
    
    private var boxSettingsView: NSSwitch? = nil
    private var frameSettingsView: NSSwitch? = nil
    private var liquidGlassSettingsView: NSSwitch? = nil
    
    public var NSLabelCharts: [NSAttributedString] = []
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        
        if config != nil {
            var configuration = config!
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self._value = value.split(separator: ",").map{ ([ColorValue(Double($0) ?? 0)]) }
                    }
                }
            }
            
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
            if let box = configuration["Box"] as? Bool {
                self.boxState = box
            }
            if let unsupportedColors = configuration["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter{ !unsupportedColors.contains($0.key) }
            }
            if let color = configuration["Color"] as? String {
                if let defaultColor = self.colors.first(where: { "\($0.self)" == color }) {
                    self.colorState = defaultColor
                }
            }
        }
        
        super.init(.barChart, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.boxState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.frameState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_frame", defaultValue: self.frameState)
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.liquidGlassState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_liquidGlass", defaultValue: self.liquidGlassState)
            self.liquidGlassWarningState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_liquidGlassWarning", defaultValue: self.liquidGlassWarningState)
            // `colorZones` is persisted as two integer percentages so it
            // survives relaunches. Modules may still override these with
            // `setColorZones(_:)` for their domain-specific defaults.
            let storedOrange = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_colorZones_orange", defaultValue: Int(self._colorZones.orange * 100))
            let storedRed = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_colorZones_red", defaultValue: Int(self._colorZones.red * 100))
            self._colorZones = (Double(storedOrange) / 100.0, Double(storedRed) / 100.0)
            self.liquidGlassPillWidth = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillWidth", defaultValue: self.liquidGlassPillWidth)
            self.liquidGlassPillHeight = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillHeight", defaultValue: self.liquidGlassPillHeight)
            self.liquidGlassOutlineState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutline", defaultValue: self.liquidGlassOutlineState)
            self.liquidGlassOutlineColorKey = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutlineColor", defaultValue: self.liquidGlassOutlineColorKey)
            self.colorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
        }
        
        if preview {
            if self._value.isEmpty {
                self._value = [[ColorValue(0.72)], [ColorValue(0.38)]]
            }
            self.setFrameSize(NSSize(width: 36, height: self.frame.size.height))
            self.invalidateIntrinsicContentSize()
            self.display()
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
        
        var value: [[ColorValue]] = []
        var pressureLevel: RAMPressure = .normal
        var colorZones: colorZones = (0.6, 0.8)
        self.queue.sync {
            value = self._value
            pressureLevel = self._pressureLevel
            colorZones = self._colorZones
        }
        
        guard !value.isEmpty else {
            self.setWidth(0)
            return
        }
        
        if self.liquidGlassState {
            self.drawLiquidGlass(value: value, pressureLevel: pressureLevel, colorZones: colorZones)
            return
        }
        
        var width: CGFloat = Constants.Widget.margin.x*2
        var x: CGFloat = 0
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        
        switch value.count {
        case 0, 1:
            width += 10 + (offset*2)
        case 2:
            width += 22
        case 3...4: // 3,4
            width += 30
        case 5...8: // 5,6,7,8
            width += 40
        case 9...12: // 9..12
            width += 50
        case 13...16: // 13..16
            width += 76
        case 17...32: // 17..32
            width += 84
        default: // > 32
            width += 118
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
        
        let box = NSBezierPath(roundedRect: NSRect(
            x: x + offset,
            y: offset,
            width: width - x - (offset*2) - (Constants.Widget.margin.x*2),
            height: self.frame.size.height - (offset*2)
        ), xRadius: 2, yRadius: 2)
        
        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.stroke()
            box.fill()
        }
        
        let widthForBarChart = box.bounds.width
        let partitionMargin: CGFloat = 0.5
        let partitionsMargin: CGFloat = (CGFloat(value.count - 1)) * partitionMargin / CGFloat(value.count - 1)
        let partitionWidth: CGFloat = (widthForBarChart / CGFloat(value.count)) - CGFloat(partitionsMargin.isNaN ? 0 : partitionsMargin)
        let maxPartitionHeight: CGFloat = box.bounds.height
        
        x += offset
        for i in 0..<value.count {
            var y = offset
            for a in 0..<value[i].count {
                let partitionValue = value[i][a]
                let partitionHeight = maxPartitionHeight * CGFloat(partitionValue.value)
                let partition = NSBezierPath(rect: NSRect(x: x, y: y, width: partitionWidth, height: partitionHeight))
                
                if partitionValue.color == nil {
                    switch self.colorState {
                    case .systemAccent: NSColor.controlAccentColor.set()
                    case .utilization: partitionValue.value.usageColor(zones: colorZones, reversed: self.title == "Battery").set()
                    case .pressure: pressureLevel.pressureColor().set()
                    case .monochrome:
                        if self.boxState {
                            (isDarkMode ? NSColor.black : NSColor.white).set()
                        } else {
                            (isDarkMode ? NSColor.white : NSColor.black).set()
                        }
                    default: (self.colorState.additional as? NSColor ?? .controlAccentColor).set()
                    }
                } else {
                    partitionValue.color?.set()
                }
                
                partition.fill()
                partition.close()
                
                y += partitionHeight
            }
            
            x += partitionWidth + partitionMargin
        }
        
        if self.boxState || self.frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }
        
        self.setWidth(width)
    }
    
    // MARK: - Liquid Glass (macOS Tahoe) draw path
    
    /// Resolves the color to use for an individual bar segment when the
    /// pill style is enabled. If a per-value color is specified it is used
    /// verbatim; otherwise the user's color preference is honored.
    /// Liquid Glass defaults to white when no explicit accent has been chosen,
    /// matching the monochrome glyphs in the Tahoe menu bar.
    private func liquidGlassColor(_ partition: ColorValue, pressureLevel: RAMPressure, colorZones: colorZones) -> NSColor {
        if let c = partition.color { return c }
        switch self.colorState {
        case .systemAccent: return Constants.liquidGlassInk
        case .utilization:  return partition.value.usageColor(zones: colorZones, reversed: self.title == "Battery")
        case .pressure:     return pressureLevel.pressureColor()
        case .monochrome:   return Constants.liquidGlassInk
        default:            return self.colorState.additional as? NSColor ?? Constants.liquidGlassInk
        }
    }
    
    /// Resolve the ink color for a single Liquid Glass row, applying the
    /// per-widget warning / critical thresholds when the user has enabled
    /// them and is using the default (system accent) color. The row's total
    /// fill is what's evaluated against the thresholds, so multi-segment
    /// stacks light up based on the combined utilization.
    private func liquidGlassRowColor(rowTotal: Double) -> NSColor? {
        guard self.liquidGlassWarningState, self.colorState == .systemAccent else { return nil }
        return Constants.liquidGlassWarningColor(
            value: rowTotal,
            warning: self._colorZones.orange,
            critical: self._colorZones.red
        )
    }
    
    /// Resolve the outline color for a Liquid Glass row. Returns the user's
    /// chosen `liquidGlassOutlineColorKey` (if it maps to a real `SColor`),
    /// otherwise falls back to the same color as the fill so the legacy
    /// look is preserved by default.
    private func resolvedOutlineColor(fallback: NSColor) -> NSColor {
        guard self.liquidGlassOutlineColorKey != "same",
              let picked = self.colors.first(where: { $0.key == self.liquidGlassOutlineColorKey }),
              let color = picked.additional as? NSColor
        else { return fallback }
        return color.withAlphaComponent(0.85)
    }
    
    /// Tahoe-style rendering: each value becomes a *horizontal* pill stacked
    /// vertically. The pill outline is thick and the fill grows left-to-right
    /// in the same color, transparent interior — like the new menu bar
    /// indicators in macOS Tahoe.
    private func drawLiquidGlass(value: [[ColorValue]], pressureLevel: RAMPressure, colorZones: colorZones) {
        let strokeWidth: CGFloat = 1.25
        let interRowSpacing: CGFloat = 2.0
        let outerMargin: CGFloat = Constants.Widget.margin.x
        
        // Single-row layouts get a noticeably wider pill so the lone capsule
        // reads as a horizontal progress bar (not a circle). Multi-row widths
        // were unchanged historically; now the user can override either
        // through the settings slider.
        let count = max(value.count, 1)
        let pillWidth: CGFloat = CGFloat(self.liquidGlassPillWidth)
        
        var x: CGFloat = outerMargin
        var totalWidth: CGFloat = (outerMargin * 2) + pillWidth
        
        // Optional title-letter column (matches classic mode for consistency).
        if self.labelState {
            let letterHeight = self.frame.height / 3
            let letterWidth: CGFloat = 6.0
            var yMargin: CGFloat = 0
            for char in self.NSLabelCharts {
                char.draw(with: CGRect(x: x - outerMargin, y: yMargin, width: letterWidth, height: letterHeight))
                yMargin += letterHeight
            }
            x += letterWidth + Constants.Widget.spacing
            totalWidth += letterWidth + Constants.Widget.spacing
        }
        
        // Stack pills vertically. Multi-row layouts keep the original 6pt
        // cap so CPU-style stacks look identical to before. Single-row
        // layouts (e.g. GPU usage) get a taller cap so the lone pill fills
        // the available menu bar height nicely.
        let availableHeight = self.frame.size.height - (strokeWidth * 2)
        let totalSpacing = interRowSpacing * CGFloat(max(count - 1, 0))
        let rawRowHeight = (availableHeight - totalSpacing) / CGFloat(count)
        let maxRowHeight: CGFloat = CGFloat(self.liquidGlassPillHeight)
        let rowHeight = max(3.0, min(rawRowHeight, maxRowHeight))
        let stackHeight = (rowHeight * CGFloat(count)) + totalSpacing
        let stackOriginY = ((self.frame.size.height - stackHeight) / 2)
        // Rounded-rectangle corners (not full capsule). Cap the radius so the
        // ends look softly chamfered rather than perfectly round.
        let radius = min(rowHeight / 2, 1.5)
        
        for i in 0..<count {
            // Top row should reflect the first value, so iterate downward.
            let segments = value[i]
            let rowY = stackOriginY + CGFloat(count - 1 - i) * (rowHeight + interRowSpacing)
            
            let rowTotal = segments.reduce(0.0) { $0 + $1.value }
            // When the warning thresholds are active, the row's fill flips
            // to the warning / critical hue. The outline color picker takes
            // priority for the outline itself so user-assigned color codes
            // stay stable across alert states.
            let warningColor = self.liquidGlassRowColor(rowTotal: rowTotal)
            let baseColor = self.liquidGlassColor(
                segments.last ?? ColorValue(0),
                pressureLevel: pressureLevel,
                colorZones: colorZones
            )
            let outlineColor = self.resolvedOutlineColor(fallback: warningColor ?? baseColor)
            
            let trackRect = NSRect(x: x + strokeWidth/2, y: rowY, width: pillWidth - strokeWidth, height: rowHeight)
            let track = NSBezierPath(roundedRect: trackRect, xRadius: radius, yRadius: radius)
            
            // When the outline mode is on, the fill is inset slightly inside
            // the stroke (battery-style gap) and given the same corner
            // radius as the outer track so the inner bar mirrors the outer
            // pill / rounded-rect. When off, the fill spans the full track
            // and is clipped to the outer shape (legacy look).
            let useInsetFill = self.liquidGlassOutlineState
            let fillInset: CGFloat = useInsetFill ? max(strokeWidth + 0.75, 1.5) : 0
            let innerRect = trackRect.insetBy(dx: fillInset, dy: fillInset)
            let innerRadius = useInsetFill
                ? max(radius - fillInset/2, 0)
                : radius
            
            NSGraphicsContext.saveGraphicsState()
            if useInsetFill {
                // Clip to the inner pill shape so per-segment rectangles
                // get the same rounded ends as the outer outline.
                NSBezierPath(roundedRect: innerRect, xRadius: innerRadius, yRadius: innerRadius).addClip()
            } else {
                // Legacy behavior: clip to the outer track.
                track.addClip()
            }
            var segX = useInsetFill ? innerRect.origin.x : trackRect.origin.x
            let fillBaseWidth = useInsetFill ? innerRect.width : trackRect.width
            let fillBaseY = useInsetFill ? innerRect.origin.y : rowY
            let fillBaseHeight = useInsetFill ? innerRect.height : rowHeight
            for seg in segments {
                let segWidth = fillBaseWidth * CGFloat(min(max(seg.value, 0), 1))
                guard segWidth > 0 else { continue }
                let fillRect = NSRect(x: segX, y: fillBaseY, width: segWidth, height: fillBaseHeight)
                let color = warningColor ?? self.liquidGlassColor(seg, pressureLevel: pressureLevel, colorZones: colorZones)
                color.setFill()
                NSBezierPath(rect: fillRect).fill()
                segX += segWidth
            }
            NSGraphicsContext.restoreGraphicsState()
            
            // Thick outline, transparent interior.
            outlineColor.setStroke()
            track.lineWidth = strokeWidth
            track.stroke()
        }
        
        self.setWidth(totalWidth)
    }
    
    public func setValue(_ newValue: [[ColorValue]]) {
        DispatchQueue.main.async(execute: {
            let tolerance: CGFloat = 0.01
            let isDifferent = self._value.count != newValue.count || zip(self._value, newValue).contains { row1, row2 in
                row1.count != row2.count || zip(row1, row2).contains { val1, val2 in
                    abs(val1.value - val2.value) > tolerance || val1.color != val2.color
                }
            }
            guard isDifferent else { return }
            self._value = newValue
            // Tooltip: average of the first column (most modules feed a
            // single column so this matches what the user sees).
            if let first = newValue.first, !first.isEmpty {
                let avg = first.reduce(0.0) { $0 + $1.value } / Double(first.count)
                self.tooltipCallback?("\(Int(avg.rounded(toPlaces: 2) * 100))%")
            }
            self.redraw()
        })
    }
    
    public func setPressure(_ newPressureLevel: RAMPressure) {
        DispatchQueue.main.async(execute: {
            guard self._pressureLevel != newPressureLevel else { return }
            self._pressureLevel = newPressureLevel
            self.redraw()
        })
    }
    
    public func setColorZones(_ newColorZones: colorZones) {
        // Module-supplied defaults must not clobber user choices made via the
        // settings sliders. The slider handlers `set(...)` the keys below on
        // every change, so their presence in Store marks the value as
        // user-customized and we skip the override.
        let userKeyOrange = "\(self.title)_\(self.type.rawValue)_colorZones_orange"
        let userKeyRed = "\(self.title)_\(self.type.rawValue)_colorZones_red"
        if Store.shared.exist(key: userKeyOrange) || Store.shared.exist(key: userKeyRed) {
            return
        }
        DispatchQueue.main.async(execute: {
            guard self._colorZones != newColorZones else { return }
            self._colorZones = newColorZones
            self.redraw()
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
        
        // Build the outline color picker: only real hues are exposed, so
        // semantic SColors like "Utilization", "Pressure", "System accent"
        // and "Monochrome" (which only make sense as a fill mode) are
        // filtered out. A "Same as fill" sentinel is the default.
        let outlineExcluded: Set<String> = ["system", "monochrome", "utilization", "pressure", "cluster", "clear"]
        var outlineColors: [KeyValue_t] = [KeyValue_t(key: "same", value: "Same as fill")]
        for c in self.colors where !outlineExcluded.contains(c.key) && !c.key.contains("separator") {
            outlineColors.append(KeyValue_t(key: c.key, value: c.value))
        }
        
        // Section 1: appearance — every control that affects how the bar
        // looks. Box/Frame is classic-mode only and Bar width / Outline /
        // Outline color is Liquid Glass only; they're grouped here so the
        // user has a single place to tune visual style.
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Liquid Glass (Tahoe)"), component: liquid),
            PreferencesRow(localizedString("Label"), component: switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Color"), component: selectView(
                action: #selector(self.toggleColor),
                items: self.colors,
                selected: self.colorState.key
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
            PreferencesRow(localizedString("Frame"), component: frame)
        ]))
        
        // Section 2: warning thresholds. Reuses the existing `_colorZones`
        // tuple so the same breakpoints feed both the classic Utilization
        // color mode and the Liquid Glass warning hues.
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
        self.redraw()
    }
    
    @objc private func toggleBox(_ sender: NSControl) {
        self.boxState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        
        if self.frameState {
            self.frameSettingsView?.state = .off
            self.frameState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        }
        
        self.redraw()
    }
    
    @objc private func toggleFrame(_ sender: NSControl) {
        self.frameState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        
        if self.boxState {
            self.boxSettingsView?.state = .off
            self.boxState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        }
        
        self.redraw()
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = self.colors.first(where: { $0.key == key }) {
            self.colorState = newColor
        }
        
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: key)
        self.redraw()
    }
    
    @objc private func toggleLiquidGlass(_ sender: NSControl) {
        self.liquidGlassState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlass", value: self.liquidGlassState)
        // When enabling Liquid Glass, the classic Box/Frame chrome would
        // double-stroke the capsule, so silently turn them off.
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
        self.redraw()
    }
    
    @objc private func toggleLiquidGlassWarning(_ sender: NSControl) {
        self.liquidGlassWarningState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassWarning", value: self.liquidGlassWarningState)
        self.redraw()
    }
    
    @objc private func changeWarningThreshold(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        // Keep warning < critical so the slider pair always reads top-to-bottom.
        let clamped = min(newValue, Int(self._colorZones.red * 100) - 1)
        self._colorZones.orange = Double(clamped) / 100.0
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_colorZones_orange", value: clamped)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(clamped)%"
        }
        self.redraw()
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
        self.redraw()
    }
    
    @objc private func changeLiquidGlassPillWidth(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        self.liquidGlassPillWidth = newValue
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillWidth", value: newValue)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(newValue)"
        }
        self.redraw()
    }
    
    @objc private func changeLiquidGlassPillHeight(_ sender: NSSlider) {
        let newValue = Int(sender.intValue)
        self.liquidGlassPillHeight = newValue
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassPillHeight", value: newValue)
        if let stack = sender.superview as? NSStackView,
           let label = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first {
            label.stringValue = "\(newValue)"
        }
        self.redraw()
    }
    
    @objc private func toggleLiquidGlassOutline(_ sender: NSControl) {
        self.liquidGlassOutlineState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutline", value: self.liquidGlassOutlineState)
        self.redraw()
    }
    
    @objc private func toggleLiquidGlassOutlineColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.liquidGlassOutlineColorKey = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_liquidGlassOutlineColor", value: key)
        self.redraw()
    }
}
