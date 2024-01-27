//
//  NetworkChart.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 19/01/2021.
//  Using Swift 5.0.
//  Running on macOS 11.1.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class NetworkChart: WidgetWrapper {
    private var boxState: Bool = false
    private var frameState: Bool = false
    private var labelState: Bool = false
    private var historyCount: Int = 60
    private var downloadColor: Color = .secondBlue
    private var uploadColor: Color = .secondRed
    private var scaleState: Scale = .linear
    private var commonScaleState: Bool = true
    private var reverseOrderState: Bool = false
    
    private var chart: NetworkChartView = NetworkChartView(
        frame: NSRect(x: 0, y: 0, width: 30, height: Constants.Widget.height - (2*Constants.Widget.margin.y)),
        num: 60, minMax: false, toolTip: false
    )
    private var width: CGFloat {
        get {
            switch self.historyCount {
            case 30:
                return 22
            case 60:
                return 30
            case 90:
                return 40
            case 120:
                return 50
            default:
                return 30
            }
        }
    }
    
    private var historyNumbers: [KeyValue_p] = [
        KeyValue_t(key: "30", value: "30"),
        KeyValue_t(key: "60", value: "60"),
        KeyValue_t(key: "90", value: "90"),
        KeyValue_t(key: "120", value: "120")
    ]
    private var colors: [Color] = Color.allCases
    
    private var boxSettingsView: NSView? = nil
    private var frameSettingsView: NSView? = nil
    
    public var NSLabelCharts: [NSAttributedString] = []
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if let config = config {
            if let titleFromConfig = config["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let unsupportedColors = config["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter{ !unsupportedColors.contains($0.key) }
            }
        }
        
        super.init(.networkChart, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: 30 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.boxState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.frameState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_frame", defaultValue: self.frameState)
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.historyCount = Store.shared.int(key: "\(self.title)_\(self.type.rawValue)_historyCount", defaultValue: self.historyCount)
            self.downloadColor = Color.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_downloadColor", defaultValue: self.downloadColor.key))
            self.uploadColor = Color.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_uploadColor", defaultValue: self.uploadColor.key))
            self.scaleState = Scale.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_scale", defaultValue: self.scaleState.key))
            self.commonScaleState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_commonScale", defaultValue: self.commonScaleState)
            self.reverseOrderState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_reverseOrder", defaultValue: self.reverseOrderState)
            
            if let downloadColor =  self.downloadColor.additional as? NSColor,
               let uploadColor = self.uploadColor.additional as? NSColor {
                self.chart.setColors(in: downloadColor, out: uploadColor)
            }
            self.chart.setScale(self.scaleState, self.commonScaleState)
            self.chart.reinit(self.historyCount)
            self.chart.setReverseOrder(self.reverseOrderState)
        }
        
        if preview {
            var list: [(Double, Double)] = []
            for _ in 0..<60 {
                list.append((Double.random(in: 0..<23), Double.random(in: 0..<23)))
            }
            self.chart.points = list
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
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        let boxSize: CGSize = CGSize(width: self.width - (Constants.Widget.margin.x*2), height: self.frame.size.height)
        var x: CGFloat = 0
        var width = self.width + (Constants.Widget.margin.x*2)
        
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
            width: self.width - offset*2,
            height: boxSize.height - (offset*2)
        ), xRadius: 2, yRadius: 2)
        
        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.stroke()
            box.fill()
        }
        
        context.saveGState()
        
        let chartFrame = NSRect(
            x: x+offset+lineWidth,
            y: offset,
            width: box.bounds.width - (offset*2+lineWidth),
            height: box.bounds.height - offset
        )
        self.chart.setFrameSize(NSSize(width: chartFrame.width, height: chartFrame.height))
        self.chart.setFrameOrigin(NSPoint(x: chartFrame.origin.x, y: chartFrame.origin.y))
        self.chart.draw(chartFrame)
        
        context.restoreGState()
        
        if self.boxState || self.frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }
        
        self.setWidth(width)
    }
    
    public func setValue(upload: Double, download: Double) {
        DispatchQueue.main.async(execute: {
            self.chart.addValue(upload: upload, download: download)
            self.display()
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Label"),
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        self.boxSettingsView = toggleSettingRow(
            title: localizedString("Box"),
            action: #selector(toggleBox),
            state: self.boxState
        )
        view.addArrangedSubview(self.boxSettingsView!)
        
        self.frameSettingsView = toggleSettingRow(
            title: localizedString("Frame"),
            action: #selector(toggleFrame),
            state: self.frameState
        )
        view.addArrangedSubview(self.frameSettingsView!)
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Color of download"),
            action: #selector(toggleDownloadColor),
            items: self.colors,
            selected: self.downloadColor.key
        ))
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Color of upload"),
            action: #selector(toggleUploadColor),
            items: self.colors,
            selected: self.uploadColor.key
        ))
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Number of reads in the chart"),
            action: #selector(toggleHistoryCount),
            items: self.historyNumbers,
            selected: "\(self.historyCount)"
        ))
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Scaling"),
            action: #selector(toggleScale),
            items: Scale.allCases.filter({ $0 != .none && $0 != .separator }),
            selected: self.scaleState.key
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Common scale"),
            action: #selector(toggleCommonScale),
            state: self.commonScaleState
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Reverse order"),
            action: #selector(toggleReverseOrder),
            state: self.reverseOrderState
        ))
        
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
            findAndToggleNSControlState(self.frameSettingsView, state: .off)
            self.frameState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        }
        
        self.display()
    }
    
    @objc private func toggleFrame(_ sender: NSControl) {
        self.frameState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        
        if self.boxState {
            findAndToggleNSControlState(self.boxSettingsView, state: .off)
            self.boxState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
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
    
    @objc private func toggleDownloadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = Color.allCases.first(where: { $0.key == key }) {
            self.downloadColor = newColor
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_downloadColor", value: newColor.key)
        }
        
        if let downloadColor =  self.downloadColor.additional as? NSColor  {
            self.chart.setColors(in: downloadColor)
        }
        self.display()
    }
    
    @objc private func toggleUploadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = Color.allCases.first(where: { $0.key == key }) {
            self.uploadColor = newColor
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_uploadColor", value: newColor.key)
        }
        
        if let uploadColor = self.uploadColor.additional as? NSColor {
            self.chart.setColors(out: uploadColor)
        }
        self.display()
    }
    
    @objc private func toggleScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.scaleState = value
        self.chart.setScale(value, self.commonScaleState)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_scale", value: key)
        self.display()
    }
    
    @objc private func toggleCommonScale(_ sender: NSControl) {
        self.commonScaleState = controlState(sender)
        self.chart.setScale(self.scaleState, self.commonScaleState)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_commonScale", value: self.commonScaleState)
        self.display()
    }
    
    @objc private func toggleReverseOrder(_ sender: NSControl) {
        self.reverseOrderState = controlState(sender)
        self.chart.setReverseOrder(self.reverseOrderState)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_reverseOrder", value: self.reverseOrderState)
        self.display()
    }
}
