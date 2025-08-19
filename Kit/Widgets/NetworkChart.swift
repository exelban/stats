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
    private var downloadColor: SColor = .secondBlue
    private var uploadColor: SColor = .secondRed
    private var scaleState: Scale = .linear
    private var reverseOrderState: Bool = false
    
    private var points: [(Double, Double)] = Array(repeating: (0, 0), count: 60)
    
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
    private var colors: [SColor] = SColor.allCases
    
    private var boxSettingsView: NSSwitch? = nil
    private var frameSettingsView: NSSwitch? = nil
    
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
            self.downloadColor = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_downloadColor", defaultValue: self.downloadColor.key))
            self.uploadColor = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_uploadColor", defaultValue: self.uploadColor.key))
            self.scaleState = Scale.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_scale", defaultValue: self.scaleState.key))
            self.reverseOrderState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_reverseOrder", defaultValue: self.reverseOrderState)
        }
        
        if preview {
            var list: [(Double, Double)] = []
            for _ in 0..<60 {
                list.append((Double.random(in: 0..<23), Double.random(in: 0..<23)))
            }
            self.points = list
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
        
        var points: [(Double, Double)] = []
        var labelState: Bool = false
        var boxState: Bool = false
        var frameState: Bool = false
        var scaleState: Scale = .linear
        var reverseOrderState: Bool = false
        var originWidth: CGFloat = 0
        var labelString: [NSAttributedString] = []
        var downloadColor: SColor = .secondBlue
        var uploadColor: SColor = .secondRed
        self.queue.sync {
            points = self.points
            labelState = self.labelState
            boxState = self.boxState
            frameState = self.frameState
            scaleState = self.scaleState
            reverseOrderState = self.reverseOrderState
            labelString = self.NSLabelCharts
            originWidth = self.width
            downloadColor = self.downloadColor
            uploadColor = self.uploadColor
        }
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        let boxSize: CGSize = CGSize(width: originWidth - (Constants.Widget.margin.x*2), height: self.frame.size.height)
        var x: CGFloat = 0
        var width = originWidth + (Constants.Widget.margin.x*2)
        
        if labelState {
            let letterHeight = self.frame.height / 3
            let letterWidth: CGFloat = 6.0
            
            var yMargin: CGFloat = 0
            for char in labelString {
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
            width: originWidth - offset*2,
            height: boxSize.height - (offset*2)
        ), xRadius: 2, yRadius: 2)
        
        if boxState {
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
        var topMax: Double = (reverseOrderState ? points.map{ $0.1 }.max() : points.map{ $0.0 }.max()) ?? 0
        var bottomMax: Double = (reverseOrderState ? points.map{ $0.0 }.max() : points.map{ $0.1 }.max()) ?? 0
        if topMax == 0 {
            topMax = 1
        }
        if bottomMax == 0 {
            bottomMax = 1
        }
        
        let zero: CGFloat = (chartFrame.height/2) + chartFrame.origin.y
        let xRatio: CGFloat = (chartFrame.width + (lineWidth*3)) / CGFloat(points.count)
        let xCenter: CGFloat = chartFrame.height/2 + chartFrame.origin.y
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return (CGFloat(point) * xRatio) + (chartFrame.origin.x - lineWidth)
        }
        
        let topYPoint = { (point: Int) -> CGFloat in
            let value = reverseOrderState ? points[point].1 : points[point].0
            return scaleValue(scale: scaleState, value: value, maxValue: topMax, zeroValue: 256.0, maxHeight: chartFrame.height/2, limit: 1) + xCenter
        }
        let bottomYPoint = { (point: Int) -> CGFloat in
            let value = reverseOrderState ? points[point].0 : points[point].1
            return xCenter - scaleValue(scale: scaleState, value: value, maxValue: bottomMax, zeroValue: 256.0, maxHeight: chartFrame.height/2, limit: 1)
        }
        
        let topLinePath = NSBezierPath()
        topLinePath.move(to: CGPoint(x: columnXPoint(0), y: topYPoint(0)))
        let bottomLinePath = NSBezierPath()
        bottomLinePath.move(to: CGPoint(x: columnXPoint(0), y: bottomYPoint(0)))
        
        for i in 1..<points.count {
            topLinePath.line(to: CGPoint(x: columnXPoint(i), y: topYPoint(i)))
            bottomLinePath.line(to: CGPoint(x: columnXPoint(i), y: bottomYPoint(i)))
        }
        
        let topColor = (reverseOrderState ? self.uploadColor : downloadColor).additional as? NSColor
        let bottomColor = (reverseOrderState ? self.downloadColor : uploadColor).additional as? NSColor
        
        bottomColor?.setStroke()
        topLinePath.lineWidth = lineWidth
        topLinePath.stroke()
        
        topColor?.setStroke()
        bottomLinePath.lineWidth = lineWidth
        bottomLinePath.stroke()
        
        context.restoreGState()
        context.saveGState()
        
        guard let topUnderLinePath = topLinePath.copy() as? NSBezierPath else { return }
        topUnderLinePath.line(to: CGPoint(x: columnXPoint(points.count - 1), y: zero))
        topUnderLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        topUnderLinePath.close()
        topUnderLinePath.addClip()
        bottomColor?.withAlphaComponent(0.5).setFill()
        let topFillRect = NSRect(x: chartFrame.origin.x - lineWidth, y: chartFrame.origin.y, width: chartFrame.width + (lineWidth*3), height: chartFrame.height)
        NSBezierPath(rect: topFillRect).fill()
        
        context.restoreGState()
        context.saveGState()
        
        guard let bottomUnderLinePath = bottomLinePath.copy() as? NSBezierPath else { return }
        bottomUnderLinePath.line(to: CGPoint(x: columnXPoint(points.count - 1), y: zero))
        bottomUnderLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        bottomUnderLinePath.close()
        bottomUnderLinePath.addClip()
        topColor?.withAlphaComponent(0.5).setFill()
        let bottomFillRect = NSRect(x: chartFrame.origin.x - lineWidth, y: chartFrame.origin.y, width: chartFrame.width + (lineWidth*3), height: chartFrame.height)
        NSBezierPath(rect: bottomFillRect).fill()
        
        context.restoreGState()
        
        if boxState || frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }
        
        self.setWidth(width)
    }
    
    public func setValue(upload: Double, download: Double) {
        self.points.remove(at: 0)
        self.points.append((upload, download))
        
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                self.display()
            }
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
            PreferencesRow(localizedString("Box"), component: box),
            PreferencesRow(localizedString("Frame"), component: frame),
            PreferencesRow(localizedString("Reverse order"), component: switchView(
                action: #selector(self.toggleReverseOrder),
                state: self.reverseOrderState
            )),
            PreferencesRow(localizedString("Color of download"), component: selectView(
                action: #selector(self.toggleDownloadColor),
                items: self.colors,
                selected: self.downloadColor.key
            )),
            PreferencesRow(localizedString("Color of upload"), component: selectView(
                action: #selector(self.toggleUploadColor),
                items: self.colors,
                selected: self.uploadColor.key
            )),
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
    
    @objc private func toggleHistoryCount(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let num = Int(key) else { return }
        self.historyCount = num
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_historyCount", value: self.historyCount)
        
        if num < self.points.count {
            self.points = Array(self.points.suffix(num))
        } else if num > self.points.count {
            self.points = Array(repeating: (0, 0), count: num - self.points.count) + self.points
        }
        
        self.display()
    }
    
    @objc private func toggleDownloadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SColor.allCases.first(where: { $0.key == key }) {
            self.downloadColor = newColor
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_downloadColor", value: newColor.key)
        }
        self.display()
    }
    
    @objc private func toggleUploadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SColor.allCases.first(where: { $0.key == key }) {
            self.uploadColor = newColor
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_uploadColor", value: newColor.key)
        }
        self.display()
    }
    
    @objc private func toggleScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.scaleState = value
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_scale", value: key)
        self.display()
    }
    
    @objc private func toggleReverseOrder(_ sender: NSControl) {
        self.reverseOrderState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_reverseOrder", value: self.reverseOrderState)
        self.display()
    }
}
