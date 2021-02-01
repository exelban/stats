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
    private let store: UnsafePointer<Store>?
    private let defaultTitle: String
    
    private var labelState: Bool = true
    private var colorState: widget_c = .monochrome
    
    private var labelLayer: CATextLayer? = nil
    private var valueLayer: CATextLayer? = nil
    
    private let onlyValueWidth: CGFloat = 40
    private var colors: [widget_c] = widget_c.allCases
    
    private var value: Double = 0
    private var pressureLevel: Int = 0
    
    private var width: CGFloat {
        get {
            return (self.labelState ? 31 : 36) + (2*Constants.Widget.margin.x)
        }
    }
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        self.store = store
        var widgetTitle: String = title
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self.value = Double(value) ?? 0
                    }
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
        
        self.defaultTitle = widgetTitle
        super.init(.mini, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ), preview: preview)
        
        self.wantsLayer = true
        
        if let store = self.store {
            self.colorState = widget_c(rawValue: store.pointee.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.rawValue)) ?? self.colorState
            self.labelState = store.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let valueSize: CGFloat = self.labelState ? 12 : 14
        var origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: (Constants.Widget.height-valueSize)/2)
        let style = NSMutableParagraphStyle()
        style.alignment = self.labelState ? .left : .center
        
        if self.labelState {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let rect = CGRect(x: origin.x, y: 12, width: 20, height: 7)
            let str = NSAttributedString.init(string: self.title, attributes: stringAttributes)
            str.draw(with: rect)
            
            origin.y = 1
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
        let rect = CGRect(x: origin.x, y: origin.y, width: width - (Constants.Widget.margin.x*2), height: valueSize+1)
        let str = NSAttributedString.init(string: "\(Int(self.value.rounded(toPlaces: 2) * 100))%", attributes: stringAttributes)
        str.draw(with: rect)
        
        self.setWidth(width)
    }
    
    public func setValue(_ value: Double) {
        if self.value == value {
            return
        }
        
        self.value = value
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setPressure(_ level: Int) {
        if self.pressureLevel == level {
            return
        }
        
        self.pressureLevel = level
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setTitle(_ newTitle: String?) {
        var title = self.defaultTitle
        if newTitle != nil {
            title = newTitle!
        }
        
        if self.title == title {
            return
        }
        
        self.title = title
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings(superview: NSView) {
        let height: CGFloat = 60 + (Constants.Settings.margin*3)
        let rowHeight: CGFloat = 30
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: rowHeight + Constants.Settings.margin, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Label"),
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        view.addSubview(SelectColorRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Color"),
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
}
