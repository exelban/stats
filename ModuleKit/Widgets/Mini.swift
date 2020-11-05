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
    
    private var labelState: Bool = true
    private var colorState: widget_c = .monochrome
    
    private var labelLayer: CATextLayer? = nil
    private var valueLayer: CATextLayer? = nil
    
    private let onlyValueWidth: CGFloat = 40
    private var colors: [widget_c] = widget_c.allCases
    
    private var value: Double = 0
    private var pressureLevel: Int = 0
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        self.store = store
        var widgetTitle: String = title
        var widgetValue: String = "0%"
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        widgetValue = "\(Int((Double(value) ?? 0)*100))%"
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
        
        super.init(frame: CGRect(
            x: 0,
            y: Constants.Widget.margin,
            width: Constants.Widget.width,
            height: Constants.Widget.height - (2*Constants.Widget.margin)
        ))
        
        self.title = widgetTitle
        self.type = .mini
        
        if let store = self.store {
            self.colorState = widget_c(rawValue: store.pointee.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.rawValue)) ?? self.colorState
            self.labelState = store.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
        
        self.draw(widgetValue)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func draw(_ val: String = "") {
        let (alignment, valueSize, width, origin) = self.changing()
        
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: width, height: self.frame.height)
        
        let label = CAText(fontSize: 7)
        label.frame = CGRect(x: origin.x, y: 11, width: width - (Constants.Widget.margin*2), height: 8)
        label.string = self.title
        label.alignmentMode = .left
        label.isHidden = true
        label.foregroundColor = NSColor.labelColor.cgColor
        label.isHidden = !self.labelState
        
        let value = CAText(fontSize: valueSize)
        value.frame = CGRect(x: origin.x, y: origin.y, width: width - (Constants.Widget.margin*2), height: valueSize)
        value.string = val
        value.font = NSFont.systemFont(ofSize: valueSize, weight: .medium)
        value.fontSize = valueSize
        value.alignmentMode = alignment
        
        layer.addSublayer(label)
        layer.addSublayer(value)
        
        self.layer = layer
        self.labelLayer = label
        self.valueLayer = value
        
        self.setFrameSize(NSSize(width: width, height: self.frame.height)) // ensure right width when initializing
    }
    
    private func changing() -> (CATextLayerAlignmentMode, CGFloat, CGFloat, CGPoint) {
        var alignment: CATextLayerAlignmentMode = .center
        var valueSize: CGFloat = 14
        var origin: CGPoint = CGPoint(x: Constants.Widget.margin, y: (Constants.Widget.height-valueSize)/2)
        var width: CGFloat = onlyValueWidth
        
        if self.labelState {
            origin.y = 1
            valueSize = 12
            width = Constants.Widget.width + 4
            alignment = .left
        }
        
        // change widget size
        if let layer = self.layer {
            layer.frame = CGRect(x: 0, y: 0, width: width, height: self.frame.height)
        }
        self.setWidth(width)
        
        return (alignment, valueSize, width, origin)
    }
    
    private func ensureColors() {
        let labelColor = self.isDarkMode ? NSColor.lightGray.cgColor : NSColor.darkGray.cgColor
        var valueColor: NSColor = NSColor(cgColor: self.valueLayer?.foregroundColor ?? NSColor.textColor.cgColor) ?? NSColor.textColor
        switch self.colorState {
        case .systemAccent: valueColor = NSColor.controlAccentColor
        case .utilization: valueColor = self.value.usageColor()
        case .pressure: valueColor = self.pressureLevel.pressureColor()
        case .monochrome: valueColor = (isDarkMode ? NSColor.white : NSColor.black)
        default: valueColor = colorFromString("\(self.colorState.self)")
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        CATransaction.setAnimationDuration(0)
        if let layer = self.valueLayer {
            if layer.foregroundColor != valueColor.cgColor {
                layer.foregroundColor = valueColor.cgColor
            }
        }
        if let layer = self.labelLayer {
            if layer.foregroundColor != labelColor {
                layer.foregroundColor = labelColor
            }
        }
        CATransaction.commit()
    }
    
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
    
    public func setValue(_ value: Double) {
        self.value = value
        DispatchQueue.main.async(execute: {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            CATransaction.setAnimationDuration(0)
            self.valueLayer?.string = "\(Int(value.rounded(toPlaces: 2) * 100))%"
            CATransaction.commit()
            
            self.ensureColors()
        })
    }
    public func setPressure(_ level: Int) {
        self.pressureLevel = level
        DispatchQueue.main.async(execute: {
            self.ensureColors()
        })
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        if let newColor = widget_c.allCases.first(where: { $0.rawValue == sender.title }) {
            self.colorState = newColor
            self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState.rawValue)
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
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        CATransaction.setAnimationDuration(0)
        let (alignment, valueSize, width, origin) = self.changing()
        self.labelLayer?.isHidden = !self.labelState
        self.valueLayer?.frame = CGRect(x: origin.x, y: origin.y, width: width - (Constants.Widget.margin*2), height: valueSize)
        self.valueLayer?.fontSize = valueSize
        self.valueLayer?.alignmentMode = alignment
        CATransaction.commit()
    }
}
