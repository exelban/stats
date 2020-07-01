//
//  BarChart.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 26/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class BarChart: Widget {
    private var labelState: Bool = true
    private var boxState: Bool = true
    private var colorState: Bool = false
    private var pressureState: Bool = false
    
    private let store: UnsafePointer<Store>?
    private var value: [Double] = []
    private var pressureLevel: Int = 0
    
    private var pressureLevelSettingsView: NSView? = nil
    private var colorizeSettingsView: NSView? = nil
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        var widgetTitle: String = title
        self.store = store
        if config != nil {
            var configuration = config!
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self.value = value.split(separator: ",").map{ (Double($0) ?? 0) }
                    }
                }
            }
            
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
            if let box = configuration["Box"] as? Bool {
                self.boxState = box
            }
            if let color = configuration["Color"] as? Bool {
                self.colorState = color
            }
        }
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.preview = preview
        self.title = widgetTitle
        self.type = .barChart
        self.canDrawConcurrently = true
        
        if self.store != nil && !preview {
            self.boxState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.labelState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.colorState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState)
            self.pressureState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_pressure", defaultValue: self.pressureState)
        }
        
        if preview {
            if self.value.count == 0 {
                self.value = [0.72, 0.38]
            }
            self.setFrameSize(NSSize(width: 36, height: self.frame.size.height))
            self.invalidateIntrinsicContentSize()
            self.pressureState = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        
        var width: CGFloat = 0
        var x: CGFloat = Constants.Widget.margin
        var chartPadding: CGFloat = 0
        
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
            width = width + letterWidth + (Constants.Widget.margin*2)
            x = letterWidth + (Constants.Widget.margin*3)
        }
        
        switch self.value.count {
        case 0, 1:
            width += 14
            break
        case 2:
            width += 26
            break
        case 3...4: // 3,4
            width += 32
            break
        case 5...8: // 5,6,7,8
            width += 42
            break
        case 9...12: // 9..12
            width += 52
            break
        case 13...16: // 13..16
            width += 78
            break
        case 17...32: // 17..32
            width += 86
            break
        default: // > 32
            width += 120
            break
        }
        
        let box = NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: width - x - Constants.Widget.margin, height: self.frame.size.height), xRadius: 2, yRadius: 2)
        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.stroke()
            box.fill()
            chartPadding = 1
        }
        
        let widthForBarChart = box.bounds.width - chartPadding
        let partitionMargin: CGFloat = 0.5
        let partitionsMargin: CGFloat = (CGFloat(self.value.count - 1)) * partitionMargin / CGFloat(self.value.count - 1)
        let partitionWidth: CGFloat = (widthForBarChart / CGFloat(self.value.count)) - CGFloat(partitionsMargin.isNaN ? 0 : partitionsMargin)
        let maxPartitionHeight: CGFloat = box.bounds.height - (chartPadding*2)
        
        x += partitionMargin
        for i in 0..<self.value.count {
            let partitionValue = self.value[i]
            let partitonHeight = maxPartitionHeight * CGFloat(partitionValue)
            let partition = NSBezierPath(rect: NSRect(x: x, y: chartPadding, width: partitionWidth, height: partitonHeight))
            
            if self.colorState {
                partitionValue.usageColor().setFill()
            } else if self.pressureState {
                self.pressureLevel.pressureColor().setFill()
            } else {
                NSColor.controlAccentColor.set()
            }
            partition.fill()
            partition.close()
            
            x += partitionWidth + partitionMargin
        }
        
        ctx.restoreGState()
        self.setWidth(width)
    }
    
    public func setValue(_ value: [Double]) {
        self.value = value
        DispatchQueue.main.async(execute: {
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
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let settingsNumber: CGFloat = self.title == "RAM" ? 4 : 3
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * settingsNumber) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        if self.title == "RAM" {
            self.pressureLevelSettingsView = ToggleTitleRow(
                frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 3, width: view.frame.width, height: rowHeight),
                title: "Pressure level",
                action: #selector(togglePressure),
                state: self.pressureState
            )
            view.addSubview(self.pressureLevelSettingsView!)
        }
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 2, width: view.frame.width, height: rowHeight),
            title: "Label",
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 1, width: view.frame.width, height: rowHeight),
            title: "Box",
            action: #selector(toggleBox),
            state: self.boxState
        ))
        
        self.colorizeSettingsView = ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: "Colorize",
            action: #selector(toggleColor),
            state: self.colorState
        )
        view.addSubview(self.colorizeSettingsView!)
        
        superview.addSubview(view)
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.labelState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
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
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        self.display()
    }
    
    @objc private func toggleColor(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.colorState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState)
        
        if self.colorState {
            self.pressureState = false
            self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_pressure", value: self.pressureState)
            FindAndToggleNSControlState(self.pressureLevelSettingsView, state: .off)
        }
        
        self.display()
    }
    
    @objc private func togglePressure(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.pressureState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_pressure", value: self.pressureState)
        
        if self.pressureState {
            self.colorState = false
            self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState)
            FindAndToggleNSControlState(self.colorizeSettingsView, state: .off)
        }
        
        self.display()
    }
}
