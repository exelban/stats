//
//  Chart.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class LineChart: WidgetWrapper {
    private var labelState: Bool = true
    private var boxState: Bool = true
    private var frameState: Bool = false
    private var valueState: Bool = false
    private var valueColorState: Bool = false
    private var colorState: widget_c = .systemAccent
    
    private let width: CGFloat = 34
    
    private var chart: LineChartView = LineChartView(frame: NSRect(
        x: 0,
        y: 0,
        width: 34,
        height: Constants.Widget.height - (2*Constants.Widget.margin.y)
    ), num: 60)
    private var colors: [widget_c] = widget_c.allCases
    private var value: Double = 0
    private var pressureLevel: Int = 0
    
    private var boxSettingsView: NSView? = nil
    private var frameSettingsView: NSView? = nil
    
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
            if let colorsToDisable = config!["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter { (color: widget_c) -> Bool in
                    return !colorsToDisable.contains("\(color.self)")
                }
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
            width: self.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.boxState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.frameState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_frame", defaultValue: self.frameState)
            self.valueState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_value", defaultValue: self.valueState)
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.valueColorState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_valueColor", defaultValue: self.valueColorState)
            self.colorState = widget_c(rawValue: Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.rawValue)) ?? self.colorState
        }
        
        if self.labelState {
            self.setFrameSize(NSSize(width: Constants.Widget.width + 6 + (Constants.Widget.margin.x*2), height: self.frame.size.height))
        }
        
        if preview {
            var list: [Double] = []
            for _ in 0..<16 {
                list.append(Double(CGFloat(Float(arc4random()) / Float(UINT32_MAX))))
            }
            self.chart.points = list
            self.value = 0.38
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        var width = self.width
        var x: CGFloat = 0
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        var boxSize: CGSize = CGSize(width: self.width - (Constants.Widget.margin.x*2), height: self.frame.size.height)
        
        var color: NSColor = NSColor.controlAccentColor
        switch self.colorState {
        case .systemAccent: color = NSColor.controlAccentColor
        case .utilization: color = value.usageColor()
        case .pressure: color = self.pressureLevel.pressureColor()
        case .monochrome:
            if self.boxState {
                color = (isDarkMode ? NSColor.black : NSColor.white)
            } else {
                color = (isDarkMode ? NSColor.white : NSColor.black)
            }
        default: color = colorFromString("\(self.colorState.self)")
        }
        
        if self.labelState {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .regular),
                NSAttributedString.Key.foregroundColor: NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let letterHeight = self.frame.height / 3
            let letterWidth: CGFloat = 6.0
            
            var yMargin: CGFloat = 0
            for char in String(self.title.prefix(3)).uppercased().reversed() {
                let rect = CGRect(x: x, y: yMargin, width: letterWidth, height: letterHeight)
                let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
                str.draw(with: rect)
                yMargin += letterHeight
            }
            width = width + letterWidth + Constants.Widget.spacing
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
            
            let rect = CGRect(x: x, y: boxSize.height-7, width: boxSize.width-1, height: 7)
            let str = NSAttributedString.init(string: "\(Int((value.rounded(toPlaces: 2)) * 100))%", attributes: stringAttributes)
            str.draw(with: rect)
            
            boxSize.height = offset == 0.5 ? 10 : 9
        }
        
        let box = NSBezierPath(roundedRect: NSRect(
            x: x + offset,
            y: offset,
            width: boxSize.width - (offset*2),
            height: boxSize.height - (offset*2)
        ), xRadius: 2, yRadius: 2)
        
        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.stroke()
            box.fill()
            self.chart.transparent = false
        } else if self.frameState {
            self.chart.transparent = true
        } else {
            self.chart.transparent = true
        }
        
        context.saveGState()
        
        let chartFrame = NSRect(
            x: x+offset,
            y: 1,
            width: box.bounds.width,
            height: box.bounds.height-1
        )
        self.chart.color = color
        self.chart.setFrameSize(NSSize(width: chartFrame.width, height: chartFrame.height))
        self.chart.draw(chartFrame)
        
        context.restoreGState()
        
        if self.boxState || self.frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }
        
        self.setWidth(width)
    }
    
    public override func setValues(_ values: [value_t]) {
        let historyValues = values.map{ $0.widget_value }.suffix(60)
        let end = self.chart.points.count
        
        if historyValues.count != 0 {
            self.chart.points.replaceSubrange(end-historyValues.count...end-1, with: historyValues)
        }
        
        self.display()
    }
    
    public func setValue(_ value: Double) {
        guard self.value != value else {
            return
        }
        
        self.value = value
        DispatchQueue.main.async(execute: {
            self.chart.addValue(value)
            self.display()
        })
    }
    
    public func setPressure(_ level: Int) {
        guard self.pressureLevel != level else {
            return
        }
        
        self.pressureLevel = level
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    // MARK: - Settings
    
    public override func settings(width: CGFloat) -> NSView {
        let rowHeight: CGFloat = 30
        let settingsNumber: CGFloat = 6
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * settingsNumber) + Constants.Settings.margin
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: width - (Constants.Settings.margin*2),
            height: height
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 5, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Label"),
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 4, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Value"),
            action: #selector(toggleValue),
            state: self.valueState
        ))
        
        self.boxSettingsView = ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 3, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Box"),
            action: #selector(toggleBox),
            state: self.boxState
        )
        view.addSubview(self.boxSettingsView!)
        
        self.frameSettingsView = ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 2, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Frame"),
            action: #selector(toggleFrame),
            state: self.frameState
        )
        view.addSubview(self.frameSettingsView!)
        
        view.addSubview(SelectColorRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 1, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Color"),
            action: #selector(toggleColor),
            items: self.colors.map{ $0.rawValue },
            selected: self.colorState.rawValue
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Colorize value"),
            action: #selector(toggleValueColor),
            state: self.valueColorState
        ))
        
        return view
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.labelState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        self.display()
    }
    
    @objc private func toggleBox(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.boxState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        
        if self.frameState {
            FindAndToggleNSControlState(self.frameSettingsView, state: .off)
            self.frameState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        }
        
        self.display()
    }
    
    @objc private func toggleFrame(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.frameState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        
        if self.boxState {
            FindAndToggleNSControlState(self.boxSettingsView, state: .off)
            self.boxState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        }
        
        self.display()
    }
    
    @objc private func toggleValue(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.valueState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_value", value: self.valueState)
        self.display()
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        if let newColor = widget_c.allCases.first(where: { $0.rawValue == sender.title }) {
            self.colorState = newColor
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState.rawValue)
            self.display()
        }
    }
    
    @objc private func toggleValueColor(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.valueColorState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_valueColor", value: self.valueColorState)
        self.display()
    }
}
