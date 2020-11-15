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
    
    private var width: CGFloat {
        get {
            return self.labelState ? Constants.Widget.width + (2*Constants.Widget.margin) : 40
        }
    }
    
    open override var wantsUpdateLayer: Bool {
        return true
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
        
        super.init(frame: CGRect(
            x: 0,
            y: Constants.Widget.margin,
            width: Constants.Widget.width + (2*Constants.Widget.margin),
            height: Constants.Widget.height - (2*Constants.Widget.margin)
        ))
        
        self.title = widgetTitle
        self.type = .mini
        
        if let store = self.store {
            self.colorState = widget_c(rawValue: store.pointee.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.rawValue)) ?? self.colorState
            self.labelState = store.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
        
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        self.draw()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func updateLayer() {
        var valueColor: NSColor = NSColor(cgColor: self.valueLayer?.foregroundColor ?? NSColor.textColor.cgColor) ?? NSColor.textColor
        switch self.colorState {
        case .systemAccent: valueColor = NSColor.controlAccentColor
        case .utilization: valueColor = self.value.usageColor()
        case .pressure: valueColor = self.pressureLevel.pressureColor()
        case .monochrome: valueColor = NSColor.textColor
        default: valueColor = colorFromString("\(self.colorState.self)")
        }
        
        if let layer = self.valueLayer {
            if layer.foregroundColor != valueColor.cgColor {
                layer.foregroundColor = valueColor.cgColor
            }
        }
        if let layer = self.labelLayer {
            let labelColor = NSColor.textColor
            if layer.foregroundColor != labelColor.cgColor {
                layer.foregroundColor = labelColor.cgColor
            }
        }
    }
    
    public override func layout() {
        if self.labelLayer!.isHidden != !self.labelState {
            let alignment: CATextLayerAlignmentMode = self.labelState ? .left : .center
            let valueSize: CGFloat = self.labelState ? 12 : 14
            var origin: CGPoint = CGPoint(x: Constants.Widget.margin, y: (Constants.Widget.height-valueSize)/2)
            if self.labelState {
                origin.y = 1
            }
            
            if var frame = self.layer?.frame {
                frame.size = CGSize(width: width, height: frame.height)
                self.layer?.frame = frame
            }
            
            self.labelLayer?.isHidden = !self.labelState
            if var frame = self.valueLayer?.frame {
                frame.origin = CGPoint(x: origin.x, y: origin.y-1)
                frame.size = CGSize(width: width - (Constants.Widget.margin*2), height: valueSize+1)
                self.valueLayer?.frame = frame
            }
            self.valueLayer?.fontSize = valueSize
            self.valueLayer?.alignmentMode = alignment
        }
        
        super.layout()
    }
    
    private func draw() {
        let alignment: CATextLayerAlignmentMode = self.labelState ? .left : .center
        let valueSize: CGFloat = self.labelState ? 12 : 14
        var origin: CGPoint = CGPoint(x: Constants.Widget.margin, y: (Constants.Widget.height-valueSize)/2)
        if self.labelState {
            origin.y = 1
        }
        
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: self.width, height: self.frame.height)
        
        let label = CAText(fontSize: 7, weight: .medium)
        label.frame = CGRect(x: origin.x, y: 12, width: self.width - (Constants.Widget.margin*2), height: 7)
        label.string = self.title
        label.alignmentMode = .left
        label.foregroundColor = NSColor.textColor.cgColor
        label.isHidden = !self.labelState
        
        let value = CAText(fontSize: valueSize)
        value.frame = CGRect(x: origin.x, y: origin.y-1, width: self.width - (Constants.Widget.margin*2), height: valueSize+1)
        value.font = NSFont.systemFont(ofSize: valueSize, weight: .medium)
        value.string = "\(Int(self.value.rounded(toPlaces: 2) * 100))%"
        value.fontSize = valueSize
        value.alignmentMode = alignment
        
        layer.addSublayer(label)
        layer.addSublayer(value)
        
        self.labelLayer = label
        self.valueLayer = value
        
        self.layer?.addSublayer(layer)
        self.setFrameSize(NSSize(width: self.width, height: self.frame.size.height))
    }
    
    public func setValue(_ value: Double) {
        if self.value == value {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.value = value
            CATransaction.disableAnimations {
                self.valueLayer?.string = "\(Int(self.value.rounded(toPlaces: 2) * 100))%"
            }
            self.needsDisplay = true
        })
    }
    
    public func setPressure(_ level: Int) {
        if self.pressureLevel == level {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.pressureLevel = level
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
            
            self.wantsLayer = true
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
        
        self.setWidth(self.width)
        self.needsLayout = true
    }
}
