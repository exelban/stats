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
    
    private let store: UnsafePointer<Store>?
    private var value: [Double] = []
    
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
            if let box = config!["Box"] as? Bool {
                self.boxState = box
            }
            if let color = config!["Color"] as? Bool {
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
        }
        
        if preview {
            self.value = [0.72, 0.38]
            self.setFrameSize(NSSize(width: 36, height: self.frame.size.height))
            self.invalidateIntrinsicContentSize()
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
                NSAttributedString.Key.foregroundColor: NSColor.labelColor,
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
            width += 64
            break
        case 17...32: // 17..32
            width += 72
            break
        default: // > 32
            width += 120
            break
        }
        
        let box = NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: width - x - Constants.Widget.margin, height: self.frame.size.height), xRadius: 2, yRadius: 2)
        var gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8)
        if self.boxState {
            NSColor.black.set()
            box.stroke()
            box.fill()
            chartPadding = 1
            gradientColor = NSColor(hexString: "#5c91f4")
        }
        
        if self.colorState {
            let newGradientColor = self.value[0].usageColor(color: self.colorState)
            if newGradientColor != NSColor.systemGreen {
                gradientColor = newGradientColor
            }
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
            gradientColor.setFill()
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
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 3) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
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
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: "Colorize",
            action: #selector(toggleColor),
            state: self.colorState
        ))
        
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
    }
}
