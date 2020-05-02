//
//  Chart.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class LineChart: Widget {
    private var labelState: Bool = true
    private var boxState: Bool = true
    private var valueState: Bool = true
    private var colorState: Bool = true
    
    private let store: UnsafePointer<Store>?
    private var chart: LineChartView
    private var value: Double = 0
    
    public init(preview: Bool, title: String, store: UnsafePointer<Store>?) {
        self.store = store
        self.chart = LineChartView(frame: NSRect(x: 0, y: 0, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)), num: 60)
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.preview = preview
        self.title = title
        self.type = .lineChart
        self.canDrawConcurrently = true
        
        if self.store != nil && !preview {
            self.boxState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.valueState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_value", defaultValue: self.valueState)
            self.labelState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.colorState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState)
        }
        
        if self.labelState {
            self.setFrameSize(NSSize(width: Constants.Widget.width + 6 + (Constants.Widget.margin*2), height: self.frame.size.height))
        }
        
        if preview {
            var list: [Double] = []
            for _ in 0..<16 {
                list.append(Double(CGFloat(Float(arc4random()) / Float(UINT32_MAX))))
            }
            self.chart.points = list
            self.value = 0.38
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        
        var width = Constants.Widget.width
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
        
        let box = NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: Constants.Widget.width - (Constants.Widget.margin*2), height: self.frame.size.height), xRadius: 2, yRadius: 2)
        
        var color = isDarkMode ? NSColor.white : NSColor.black
        if self.boxState {
            NSColor.black.set()
            box.stroke()
            box.fill()
            self.chart.transparent = false
            color = NSColor.white
            chartPadding = 1
        } else {
            self.chart.transparent = true
        }
        
        if self.colorState {
            color = self.value.usageColor(reversed: false, color: self.colorState)
        }
        
        var height = box.bounds.height - chartPadding
        if self.valueState {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .regular),
                NSAttributedString.Key.foregroundColor: color,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let rect = CGRect(x: x, y: height-7+chartPadding, width: box.bounds.width - chartPadding, height: 7)
            let str = NSAttributedString.init(string: "\(Int((value.rounded(toPlaces: 2)) * 100))%", attributes: stringAttributes)
            str.draw(with: rect)
            
            height = 8
        }
        
        chart.setFrameSize(NSSize(width: box.bounds.width - chartPadding, height: height))
        chart.draw(NSRect(x: box.bounds.origin.x + 1, y: chartPadding, width: box.bounds.width - chartPadding, height: height))
        
        ctx.restoreGState()
        self.setWidth(width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 4) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(self.makeSettingsRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 3, width: view.frame.width, height: rowHeight),
            title: "Label",
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        view.addSubview(self.makeSettingsRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 2, width: view.frame.width, height: rowHeight),
            title: "Box",
            action: #selector(toggleBox),
            state: self.boxState
        ))
        
        view.addSubview(self.makeSettingsRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 1, width: view.frame.width, height: rowHeight),
            title: "Value",
            action: #selector(toggleValue),
            state: self.valueState
        ))
        
        view.addSubview(self.makeSettingsRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: "Color",
            action: #selector(toggleColor),
            state: self.colorState
        ))
        
        superview.addSubview(view)
    }
    
    public override func setValues(_ values: [value_t]) {
        let historyValues = values.map{ $0.widget_value }.prefix(60)
        let end = self.chart.points!.count
        self.chart.points!.replaceSubrange(end-historyValues.count...end-1, with: historyValues)
        self.display()
    }
    
    public func setValue(_ value: Double) {
        self.value = value
        DispatchQueue.main.async(execute: {
            self.chart.addValue(value)
            self.display()
        })
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
    
    @objc private func toggleValue(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.valueState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_value", value: self.valueState)
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
        self.display()
    }
}
