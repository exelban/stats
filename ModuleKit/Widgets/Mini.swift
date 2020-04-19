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
    public var valueView: NSTextField = NSTextField()
    public var labelView: NSTextField = NSTextField()
    
    public var color: Bool = true
    public var label: Bool = true
    
    private let onlyValueWidth: CGFloat = 42
    private var value: Double = 0
    private let store: UnsafePointer<Store>?
    
    public init(preview: Bool, title: String, store: UnsafePointer<Store>?) {
        self.store = store
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = title
        self.type = .mini
        self.preview = preview
        self.wantsLayer = true
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.color = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.color)
            self.label = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.label)
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
        
        if self.label {
            let labelView = NSTextField(frame: NSMakeRect(xOffset, 11, width, 8))
            labelView.isEditable = false
            labelView.isSelectable = false
            labelView.isBezeled = false
            labelView.wantsLayer = true
            labelView.textColor = .labelColor
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
        valueView.textColor = self.value.usageColor(color: self.color)
        valueView.backgroundColor = .controlColor
        valueView.canDrawSubviewsIntoLayer = true
        valueView.alignment = valueAligment
        valueView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        valueView.stringValue = "\(Int(self.value.rounded(toPlaces: 2) * 100))%"
        valueView.addSubview(NSView())
        
        if self.preview {
            valueView.stringValue = "38%"
            valueView.textColor = 0.38.usageColor(color: true)
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
        superview.setFrameOrigin(NSPoint(x: superview.frame.origin.x, y: superview.frame.origin.y - height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(makeSettingsRow(
            frame: NSRect(x: 0, y: rowHeight + Constants.Settings.margin, width: view.frame.width, height: rowHeight),
            title: "Label",
            action: #selector(toggleLabel),
            state: self.label
        ))
        
        view.addSubview(makeSettingsRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: rowHeight),
            title: "Colorize",
            action: #selector(toggleColors),
            state: self.color
        ))
        
        superview.addSubview(view)
    }
    
    @objc func toggleColors(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.color = state! == .on ? true : false
        self.valueView.textColor = value.usageColor(color: self.color)
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.color)
    }
    
    @objc func toggleLabel(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.label = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.label)
        self.subviews.forEach{ $0.removeFromSuperview() }
        self.build()
    }
    
    private func makeSettingsRow(frame: NSRect, title: String, action: Selector, state: Bool) -> NSView {
        let row: NSView = NSView(frame: frame)
        let state: NSControl.StateValue = state ? .on : .off
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17), title)
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .secondaryLabelColor
        
        var toggle: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: row.frame.width - 50, y: 0, width: 50, height: row.frame.height))
            switchButton.state = state
            switchButton.action = action
            switchButton.target = self

            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: row.frame.width - 30, y: 0, width: 30, height: row.frame.height))
            button.setButtonType(.switch)
            button.state = state
            button.title = ""
            button.action = action
            button.isBordered = false
            button.isTransparent = true
            
            toggle = button
        }

        row.addSubview(toggle)
        row.addSubview(rowTitle)
        
        return row
    }
    
    public func setValue(_ value: Double?, sufix: String) {
        if value == self.value || value == nil {
            return
        }
        
        self.value = value!
        DispatchQueue.main.async(execute: {
            self.valueView.stringValue = "\(Int((value!.rounded(toPlaces: 2)) * 100))\(sufix)"
            self.valueView.textColor = value!.usageColor(color: self.color)
        })
    }
}
