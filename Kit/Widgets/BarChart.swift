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
    private var colorState: Color = .systemAccent
    
    private var colors: [Color] = Color.allCases
    private var value: [[ColorValue]] = [[]]
    private var pressureLevel: DispatchSource.MemoryPressureEvent = .normal
    private var colorZones: colorZones = (0.6, 0.8)
    
    private var boxSettingsView: NSView? = nil
    private var frameSettingsView: NSView? = nil
    
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
                        self.value = value.split(separator: ",").map{ ([ColorValue(Double($0) ?? 0)]) }
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
                if let defaultColor = colors.first(where: { "\($0.self)" == color }) {
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
            self.colorState = Color.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
        }
        
        if preview {
            if self.value.isEmpty {
                self.value = [[ColorValue(0.72)], [ColorValue(0.38)]]
            }
            self.setFrameSize(NSSize(width: 36, height: self.frame.size.height))
            self.invalidateIntrinsicContentSize()
            self.display()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var width: CGFloat = Constants.Widget.margin.x*2
        var x: CGFloat = 0
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        
        switch self.value.count {
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
        let partitionsMargin: CGFloat = (CGFloat(self.value.count - 1)) * partitionMargin / CGFloat(self.value.count - 1)
        let partitionWidth: CGFloat = (widthForBarChart / CGFloat(self.value.count)) - CGFloat(partitionsMargin.isNaN ? 0 : partitionsMargin)
        let maxPartitionHeight: CGFloat = box.bounds.height
        
        x += offset
        for i in 0..<self.value.count {
            var y = offset
            for a in 0..<self.value[i].count {
                let partitionValue = self.value[i][a]
                let partitionHeight = maxPartitionHeight * CGFloat(partitionValue.value)
                let partition = NSBezierPath(rect: NSRect(x: x, y: y, width: partitionWidth, height: partitionHeight))
                
                if partitionValue.color == nil {
                    switch self.colorState {
                    case .systemAccent: NSColor.controlAccentColor.set()
                    case .utilization: partitionValue.value.usageColor(zones: self.colorZones, reversed: self.title == "Battery").set()
                    case .pressure: self.pressureLevel.pressureColor().set()
                    case .cluster: (partitionValue.value.clusterColor(i) ?? .controlAccentColor).set()
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
    
    public func setValue(_ value: [[ColorValue]]) {
        guard self.value != value else {
            return
        }
        
        self.value = value
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setPressure(_ level: DispatchSource.MemoryPressureEvent) {
        guard self.pressureLevel != level else {
            return
        }
        
        self.pressureLevel = level
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setColorZones(_ zones: colorZones) {
        guard self.colorZones != zones else {
            return
        }
        
        self.colorZones = zones
        DispatchQueue.main.async(execute: {
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
            title: localizedString("Color"),
            action: #selector(toggleColor),
            items: self.colors,
            selected: self.colorState.key
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
            findAndToggleNSControlState(self.frameSettingsView, state: .off)
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
            findAndToggleNSControlState(self.boxSettingsView, state: .off)
            self.boxState = false
            Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        }
        
        self.display()
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        if let newColor = self.colors.first(where: { $0.key == key }) {
            self.colorState = newColor
        }
        
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: key)
        self.display()
    }
}
