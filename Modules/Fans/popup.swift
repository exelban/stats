//
//  settings.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 21/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSView {
    private var list: [Int: FanView] = [:]
    
    public init() {
        super.init(frame: NSRect( x: 0, y: 0, width: Constants.Popup.width, height: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func setup(_ values: [Fan]?) {
        guard values != nil else {
            return
        }
        
        self.subviews.forEach { (v: NSView) in
            v.removeFromSuperview()
        }
        
        let fanViewHeight: CGFloat = 40
        let view: NSView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: self.frame.width,
            height: ((fanViewHeight+Constants.Popup.margins)*CGFloat(values!.count))-Constants.Popup.margins
        ))
        var i: CGFloat = 0
        
        values!.reversed().forEach { (f: Fan) in
            let fanView = FanView(
                NSRect(
                    x: 0,
                    y: (fanViewHeight + Constants.Popup.margins) * i,
                    width: self.frame.width,
                    height: fanViewHeight
                ),
                fan: f
            )
            self.list[f.id] = fanView
            view.addSubview(fanView)
            i += 1
        }
        self.addSubview(view)
        
        self.setFrameSize(NSSize(width: self.frame.width, height: view.frame.height))
    }
    
    internal func usageCallback(_ values: [Fan]) {
        values.forEach { (f: Fan) in
            if self.list[f.id] != nil {
                DispatchQueue.main.async(execute: {
                    if f.value != nil && (self.window?.isVisible ?? false) {
                        self.list[f.id]?.update(f)
                    }
                })
            }
        }
    }
}

internal class FanView: NSView {
    private let fan: Fan
    private var mainView: NSView
    
    private var valueField: NSTextField? = nil
    private var percentageField: NSTextField? = nil
    
    private var ready: Bool = false
    
    public init(_ frame: NSRect, fan: Fan) {
        self.fan = fan
        self.mainView = NSView(frame: NSRect(x: 5, y: 5, width: frame.width - 10, height: frame.height - 10))
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.addFirstRow()
        self.addSecondRow()
        
        self.addSubview(self.mainView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    private func addFirstRow() {
        let row: NSView = NSView(frame: NSRect(x: 0, y: 14, width: self.mainView.frame.width, height: 16))
        
        let value = self.fan.formattedValue ?? "0 RPM"
        let valueWidth: CGFloat = 80
        
        let nameField: NSTextField = TextView(frame: NSRect(
            x: 0,
            y: 0,
            width: self.mainView.frame.width - valueWidth,
            height: row.frame.height
        ))
        nameField.stringValue = self.fan.name
        nameField.cell?.truncatesLastVisibleLine = true
        
        let valueField: NSTextField = TextView(frame: NSRect(
            x: self.mainView.frame.width - valueWidth,
            y: 0,
            width: valueWidth,
            height: row.frame.height
        ))
        valueField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        valueField.stringValue = value
        valueField.alignment = .right
        
        row.addSubview(nameField)
        row.addSubview(valueField)
        
        self.mainView.addSubview(row)
        self.valueField = valueField
    }
    
    private func addSecondRow() {
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.mainView.frame.width, height: 14))
        
        let value = (self.fan.value ?? 0)
        let percentage = "\((100*Int(value)) / self.fan.maxSpeed)%"
        let percentageWidth: CGFloat = 40
        
        let percentageField: NSTextField = TextView(frame: NSRect(
            x: self.mainView.frame.width - percentageWidth,
            y: 0,
            width: percentageWidth,
            height: row.frame.height
        ))
        percentageField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        percentageField.textColor = .secondaryLabelColor
        percentageField.stringValue = percentage
        percentageField.alignment = .right
        
        row.addSubview(percentageField)
        self.mainView.addSubview(row)
        self.percentageField = percentageField
    }
    
    public func update(_ value: Fan) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.ready {
                
                if let view = self.valueField, let value = value.formattedValue {
                    view.stringValue = value
                }
                
                if let view = self.percentageField, let value = value.value {
                    view.stringValue = "\((100*Int(value)) / self.fan.maxSpeed)%"
                }
                
                self.ready = true
            }
        })
    }
}
