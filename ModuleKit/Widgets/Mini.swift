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
    private var valueView: NSTextField = NSTextField()
    private var labelView: NSTextField = NSTextField()
    
    public var colorState: Bool = false
    public var labelState: Bool = true
    
    private let onlyValueWidth: CGFloat = 42
    private var value: Double = 0
    private let store: UnsafePointer<Store>?
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        var widgetTitle: String = title
        self.store = store
        if config != nil {
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let label = config!["Label"] as? Bool {
                self.labelState = label
            }
            if let color = config!["Color"] as? Bool {
                self.colorState = color
            }
        }
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = widgetTitle
        self.type = .mini
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.colorState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState)
            self.labelState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
        
        self.build()
    }
    
    private func build() {
        var xOffset: CGFloat = 1
        var width: CGFloat = self.frame.size.width
        var height: CGFloat = 10
        var y: CGFloat = 1
        var fontSize: CGFloat = 10
        var valueAligment: NSTextAlignment = .natural
        
        if self.labelState {
            let labelView = NSTextField(frame: NSMakeRect(xOffset, 11, width, 8))
            labelView.isEditable = false
            labelView.isSelectable = false
            labelView.isBezeled = false
            labelView.wantsLayer = true
            labelView.textColor = .textColor
            labelView.backgroundColor = .controlColor
            labelView.canDrawSubviewsIntoLayer = true
            labelView.alignment = .natural
            labelView.font = NSFont.systemFont(ofSize: 8, weight: .light)
            labelView.stringValue = self.title
            labelView.addSubview(NSView())
            
            self.labelView = labelView
            self.addSubview(self.labelView)
            self.setWidth(Constants.Widget.width)
        } else {
            xOffset = 0
            width = self.onlyValueWidth
            height = self.frame.height - 2
            y = 1
            fontSize = 13
            valueAligment = .center
            self.setWidth(self.onlyValueWidth)
        }
        
        let valueView = NSTextField(frame: NSMakeRect(xOffset, y, width, height))
        valueView.isEditable = false
        valueView.isSelectable = false
        valueView.isBezeled = false
        valueView.wantsLayer = true
        valueView.textColor = self.value.textUsageColor(color: self.colorState)
        valueView.backgroundColor = .controlColor
        valueView.canDrawSubviewsIntoLayer = true
        valueView.alignment = valueAligment
        valueView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        valueView.stringValue = "\(Int(self.value.rounded(toPlaces: 2) * 100))%"
        valueView.addSubview(NSView())
        
        if self.preview {
            valueView.stringValue = "38%"
            valueView.textColor = 0.38.textUsageColor(color: false)
        }
        
        self.valueView = valueView
        self.addSubview(self.valueView)
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
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: rowHeight),
            title: "Colorize",
            action: #selector(toggleColor),
            state: self.colorState
        ))
        
        superview.addSubview(view)
    }
    
    @objc private func toggleColor(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.colorState = state! == .on ? true : false
        self.valueView.textColor = value.textUsageColor(color: self.colorState)
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState)
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
        self.subviews.forEach{ $0.removeFromSuperview() }
        self.build()
    }
    
    public func setValue(_ value: Double, sufix: String) {
        if value == self.value {
            return
        }
        
        self.value = value
        DispatchQueue.main.async(execute: {
            self.valueView.stringValue = "\(Int((value.rounded(toPlaces: 2)) * 100))\(sufix)"
            self.valueView.textColor = value.textUsageColor(color: self.colorState)
        })
    }
}
