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
    public var colorState: SColor = .systemAccent
    private var colors: [SColor] = SColor.allCases
    
    private var _value: [[ColorValue]] = [[]]
    private var _pressureLevel: RAMPressure = .normal
    private var _colorZones: colorZones = (0.6, 0.8)
    
    private var boxSettingsView: NSSwitch? = nil
    private var frameSettingsView: NSSwitch? = nil
    
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
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Label"), component: switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Color"), component: selectView(
                action: #selector(self.toggleColor),
                items: self.colors,
                selected: self.colorState.key
            )),
            PreferencesRow(localizedString("Box"), component: box),
            PreferencesRow(localizedString("Frame"), component: frame)
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
}

public class LatencyBarsWidget: WidgetWrapper {
    private static let sizeOptions: [Int] = [15, 25, 35, 50, 70]
    private static let barPitch: Int = 3 // 2px bar + 1px spacing

    private var widthPx: Int = 35
    private var thresholds: LatencyThresholds = .default
    private var boxState: Bool = false
    private var frameState: Bool = false
    private var showValueState: Bool = false

    private var boxSettingsView: NSSwitch? = nil
    private var frameSettingsView: NSSwitch? = nil

    private var _bars: [LatencyBucket] = []
    private var _latestLatency: Double? = nil
    private var _latestOnline: Bool = true

    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if let titleFromConfig = config?["Title"] as? String {
            widgetTitle = titleFromConfig
        }

        super.init(.latencyBars, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: 35 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))

        self.canDrawConcurrently = true

        if !preview {
            self.widthPx = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_size", defaultValue: self.widthPx)
            self.boxState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.frameState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_frame", defaultValue: self.frameState)
            self.showValueState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_showValue", defaultValue: self.showValueState)
            self.thresholds = currentLatencyThresholds(module: self.title)
        }

        self._bars = Array(repeating: .empty, count: self.barCount)

        if preview {
            let pattern: [Double] = [30, 45, 80, 60, 40, 55, 90, 120, 250, 180, 90, 50, 70, 30, 40]
            for i in 0..<self._bars.count {
                self._bars[i] = LatencyBucket(latency: pattern[i % pattern.count], online: true, hasData: true)
            }
            self.display()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var barCount: Int {
        max(1, self.widthPx / Self.barPitch)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var bars: [LatencyBucket] = []
        var latestLatency: Double? = nil
        var latestOnline: Bool = true
        self.queue.sync {
            bars = self._bars
            latestLatency = self._latestLatency
            latestOnline = self._latestOnline
        }
        guard !bars.isEmpty else {
            self.setWidth(0)
            return
        }

        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        let contentWidth = CGFloat(self.widthPx)

        var labelWidth: CGFloat = 0
        var valueStr: NSAttributedString? = nil
        var unitStr: NSAttributedString? = nil
        if self.showValueState {
            let valueText: String
            let unitText: String
            var color: NSColor = .textColor
            if !latestOnline {
                valueText = "!!"
                unitText = ""
                color = .systemRed
            } else if let l = latestLatency, l > 0 {
                valueText = "\(Int(l.rounded()))"
                unitText = "ms"
                color = latencyColor(for: l, thresholds: self.thresholds)
            } else {
                valueText = "—"
                unitText = ""
            }
            let valueFont: NSFont = !latestOnline
                ? NSFont.systemFont(ofSize: 14, weight: .heavy)
                : NSFont.systemFont(ofSize: 10, weight: .regular)
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: color
            ]
            let unitAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7, weight: .regular),
                .foregroundColor: color.withAlphaComponent(0.75)
            ]
            valueStr = NSAttributedString(string: valueText, attributes: valueAttrs)
            if !unitText.isEmpty {
                unitStr = NSAttributedString(string: unitText, attributes: unitAttrs)
            }
            let vW = valueStr?.size().width ?? 0
            let uW = unitStr?.size().width ?? 0
            let refAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular)
            ]
            let refWidth = NSAttributedString(string: "000", attributes: refAttrs).size().width
            labelWidth = ceil(max(refWidth, vW, uW))
        }

        let labelGap: CGFloat = (labelWidth > 0) ? Constants.Widget.spacing : 0
        let totalWidth: CGFloat = labelWidth + labelGap + contentWidth + (Constants.Widget.margin.x * 2) + (offset * 2)
        let labelOriginX = offset + contentWidth + labelGap

        if let valueStr {
            let frameH = self.frame.size.height
            let vSize = valueStr.size()
            if let unitStr {
                let uSize = unitStr.size()
                let vGap: CGFloat = -2
                let totalH = ceil(vSize.height) + ceil(uSize.height) + vGap
                let yBottom = (frameH - totalH) / 2
                let xUnit = labelOriginX + (labelWidth - uSize.width) / 2
                unitStr.draw(at: CGPoint(x: xUnit, y: yBottom))
                let xValue = labelOriginX + (labelWidth - vSize.width) / 2
                valueStr.draw(at: CGPoint(x: xValue, y: yBottom + ceil(uSize.height) + vGap))
            } else {
                let yCenter = (frameH - vSize.height) / 2
                let xValue = labelOriginX + (labelWidth - vSize.width) / 2
                valueStr.draw(at: CGPoint(x: xValue, y: yCenter))
            }
        }

        let boxRect = NSRect(
            x: offset,
            y: offset,
            width: contentWidth,
            height: self.frame.size.height - (offset * 2)
        )
        let box = NSBezierPath(roundedRect: boxRect, xRadius: 2, yRadius: 2)

        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.fill()
        }

        renderLatencyBars(in: boxRect, bars: bars, thresholds: self.thresholds)

        if self.boxState || self.frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }

        self.setWidth(totalWidth)
    }

    public func setValue(latency: Double?, online: Bool) {
        let bucket = LatencyBucket(LatencySample(latency: latency, online: online))
        self.queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            guard !self._bars.isEmpty else { return }
            self._bars.removeFirst()
            self._bars.append(bucket)
            self._latestLatency = bucket.hasData ? bucket.latency : nil
            self._latestOnline = bucket.online
            self.redraw()
        }
    }

    private func resampleBars(newCount: Int) {
        let newSize = max(newCount, 1)
        self.queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            if newSize == self._bars.count { return }
            if self._bars.isEmpty {
                self._bars = Array(repeating: .empty, count: newSize)
            } else if self._bars.count >= newSize {
                self._bars = Array(self._bars.suffix(newSize))
            } else {
                self._bars = Array(repeating: .empty, count: newSize - self._bars.count) + self._bars
            }
        }
    }

    public override func settings() -> NSView {
        let view = SettingsContainerView()

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Size"), component: selectView(
                action: #selector(self.toggleSize),
                items: Self.sizeOptions.map { KeyValue_t(key: "\($0)", value: "\($0) px") },
                selected: "\(self.widthPx)"
            ))
        ]))

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Thresholds (ms)"), component: self.buildThresholdsRow())
        ]))

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Value"), component: switchView(
                action: #selector(self.toggleShowValue),
                state: self.showValueState
            )),
            PreferencesRow(localizedString("Box"), component: self.installedBoxSwitch()),
            PreferencesRow(localizedString("Frame"), component: self.installedFrameSwitch())
        ]))

        return view
    }

    private func installedBoxSwitch() -> NSSwitch {
        let s = switchView(action: #selector(self.toggleBox), state: self.boxState)
        self.boxSettingsView = s
        return s
    }

    private func installedFrameSwitch() -> NSSwitch {
        let s = switchView(action: #selector(self.toggleFrame), state: self.frameState)
        self.frameSettingsView = s
        return s
    }

    @objc private func toggleShowValue(_ sender: NSControl) {
        self.showValueState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_showValue", value: self.showValueState)
        self.redraw()
    }

    private static let thresholdInputWidth: CGFloat = 100
    private static let thresholdSpecs: [(key: String, color: NSColor, value: (LatencyThresholds) -> Double)] = [
        ("green",  .systemGreen,  { $0.green }),
        ("yellow", .systemYellow, { $0.yellow }),
        ("red",    .systemRed,    { $0.red })
    ]

    private func buildThresholdsRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 6
        for spec in Self.thresholdSpecs {
            row.addArrangedSubview(self.thresholdInput(color: spec.color, key: spec.key, value: Int(spec.value(self.thresholds))))
        }
        return row
    }

    private func thresholdInput(color: NSColor, key: String, value: Int) -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 3
        container.alignment = .centerY

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let le = NSTextField(labelWithString: "\u{2264}")
        le.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        le.textColor = .secondaryLabelColor

        let stepper = StepperInput(
            value,
            range: NSRange(location: 1, length: 4999),
            unit: "",
            callback: { [weak self] v in self?.setThreshold(key: key, value: v) }
        )

        container.addArrangedSubview(dot)
        container.addArrangedSubview(le)
        container.addArrangedSubview(stepper)
        container.widthAnchor.constraint(equalToConstant: Self.thresholdInputWidth).isActive = true
        return container
    }

    @objc private func toggleSize(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let px = Int(key), Self.sizeOptions.contains(px) else { return }
        self.widthPx = px
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_size", value: px)
        self.resampleBars(newCount: self.barCount)
        self.redraw()
    }

    private func setThreshold(key: String, value: Int) {
        let v = Double(value)
        switch key {
        case "green":  self.thresholds.green  = min(v, self.thresholds.yellow - 1)
        case "yellow": self.thresholds.yellow = min(max(v, self.thresholds.green + 1), self.thresholds.red - 1)
        case "red":    self.thresholds.red    = max(v, self.thresholds.yellow + 1)
        default: return
        }
        Store.shared.set(key: "\(self.title)_latencyThreshold_green",  value: Int(self.thresholds.green))
        Store.shared.set(key: "\(self.title)_latencyThreshold_yellow", value: Int(self.thresholds.yellow))
        Store.shared.set(key: "\(self.title)_latencyThreshold_red",    value: Int(self.thresholds.red))
        self.redraw()
    }

    @objc private func toggleBox(_ sender: NSControl) {
        self.boxState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        if self.boxState && self.frameState {
            self.frameState = false
            self.frameSettingsView?.state = .off
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        }
        self.redraw()
    }

    @objc private func toggleFrame(_ sender: NSControl) {
        self.frameState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        if self.frameState && self.boxState {
            self.boxState = false
            self.boxSettingsView?.state = .off
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        }
        self.redraw()
    }
}
