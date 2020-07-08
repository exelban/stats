//
//  Mini.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class Mini: Widget {
    public var labelState: Bool = true
    private var colorState: widget_c = .monochrome
    
    private let onlyValueWidth: CGFloat = 38
    private var value: Double = 0
    private let store: UnsafePointer<Store>?
    private var colors: [widget_c] = widget_c.allCases
    private var pressureLevel: Int = 0
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        var widgetTitle: String = title
        self.store = store
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self.value = Double(value) ?? 0.38
                    } else {
                        self.value = 0.38
                    }
                } else {
                    self.value = 0.38
                }
            }
            
            if let titleFromConfig = configuration["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
            if let colorsToDisable = configuration["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter { (color: widget_c) -> Bool in
                    return !colorsToDisable.contains("\(color.self)")
                }
            }
            if let color = configuration["Color"] as? String {
                if let defaultColor = colors.first(where: { "\($0.self)" == color }) {
                    self.colorState = defaultColor
                }
            }
        }
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = widgetTitle
        self.type = .mini
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.colorState = widget_c(rawValue: store!.pointee.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.rawValue)) ?? self.colorState
            self.labelState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var width: CGFloat = onlyValueWidth
        let x: CGFloat = Constants.Widget.margin
        var valueSize: CGFloat = 13
        var y: CGFloat = (Constants.Widget.height-valueSize)/2
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        if self.labelState {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let rect = CGRect(x: x, y: 12, width: 20, height: 7)
            let str = NSAttributedString.init(string: self.title, attributes: stringAttributes)
            str.draw(with: rect)
            
            y = 1
            valueSize = 11
            width = Constants.Widget.width
            style.alignment = .left
        }
        
        var color: NSColor = NSColor.controlAccentColor
        switch self.colorState {
        case .systemAccent: color = NSColor.controlAccentColor
        case .utilization: color = value.usageColor()
        case .pressure: color = self.pressureLevel.pressureColor()
        case .monochrome: color = (isDarkMode ? NSColor.white : NSColor.black)
        default: color = colorFromString("\(self.colorState.self)")
        }
        
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let rect = CGRect(x: x, y: y, width: width - (Constants.Widget.margin*2), height: valueSize)
        let str = NSAttributedString.init(string: "\(Int(self.value.rounded(toPlaces: 2) * 100))%", attributes: stringAttributes)
        str.draw(with: rect)
        
        self.setWidth(width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func settings(superview: NSView) {
        let height: CGFloat = 60 + (Constants.Settings.margin*3)
        let rowHeight: CGFloat = 30
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: rowHeight + Constants.Settings.margin, width: view.frame.width, height: rowHeight),
            title: "Label",
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        view.addSubview(SelectColorRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: "Color",
            action: #selector(toggleColor),
            items: self.colors.map{ $0.rawValue },
            selected: self.colorState.rawValue
        ))
        
        superview.addSubview(view)
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        if let newColor = widget_c.allCases.first(where: { $0.rawValue == sender.title }) {
            self.colorState = newColor
            self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState.rawValue)
            self.display()
        }
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
    
    public func setValue(_ value: Double, sufix: String) {
        if value == self.value {
            return
        }
        
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
}
