//
//  NetworkChart.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 19/01/2021.
//  Using Swift 5.0.
//  Running on macOS 11.1.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class NetworkChart: Widget {
    private var boxState: Bool = false
    private var frameState: Bool = false
    
    private let store: UnsafePointer<Store>?
    private var chart: NetworkChartView = NetworkChartView(
        frame: NSRect(
            x: 0,
            y: 0,
            width: 34,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ),
        num: 60, minMax: false
    )
    private let width: CGFloat = 34
    
    private var boxSettingsView: NSView? = nil
    private var frameSettingsView: NSView? = nil
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        var widgetTitle: String = title
        self.store = store
        if config != nil {
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
        }
        
        super.init(frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: self.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.preview = preview
        self.title = widgetTitle
        self.type = .networkChart
        self.wantsLayer = true
        self.canDrawConcurrently = true
        
        if self.store != nil && !preview {
            self.boxState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_box", defaultValue: self.boxState)
            self.frameState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_frame", defaultValue: self.frameState)
        }
        
        if preview {
            var list: [(Double, Double)] = []
            for _ in 0..<60 {
                list.append((Double.random(in: 0..<23), Double.random(in: 0..<23)))
            }
            self.chart.points = list
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        let boxSize: CGSize = CGSize(width: self.width - (Constants.Widget.margin.x*2), height: self.frame.size.height)
        
        let box = NSBezierPath(roundedRect: NSRect(
            x: offset,
            y: offset,
            width: boxSize.width - (offset*2),
            height: boxSize.height - (offset*2)
        ), xRadius: 2, yRadius: 2)
        
        if self.boxState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.stroke()
            box.fill()
        }
        
        context.saveGState()
        
        self.chart.draw(NSRect(
            x: 1,
            y: 1,
            width: box.bounds.width - ((box.bounds.origin.x + lineWidth)*2),
            height: box.bounds.height - ((box.bounds.origin.y + lineWidth)*2)
        ))
        
        context.restoreGState()
        
        if self.boxState || self.frameState {
            (isDarkMode ? NSColor.white : NSColor.black).set()
            box.lineWidth = lineWidth
            box.stroke()
        }
        
        self.setWidth(width)
    }
    
    public func setValue(upload: Double, download: Double) {
        DispatchQueue.main.async(execute: {
            self.chart.addValue(upload: upload, download: download)
            self.display()
        })
    }
    
    // MARK: - Settings
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let settingsNumber: CGFloat = 2
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * settingsNumber) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        self.boxSettingsView = ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 1, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Box"),
            action: #selector(toggleBox),
            state: self.boxState
        )
        view.addSubview(self.boxSettingsView!)
        
        self.frameSettingsView = ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Frame"),
            action: #selector(toggleFrame),
            state: self.frameState
        )
        view.addSubview(self.frameSettingsView!)
        
        superview.addSubview(view)
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
        
        if self.frameState {
            FindAndToggleNSControlState(self.frameSettingsView, state: .off)
            self.frameState = false
            self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        }
        
        self.display()
    }
    
    @objc private func toggleFrame(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.frameState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_frame", value: self.frameState)
        
        if self.boxState {
            FindAndToggleNSControlState(self.boxSettingsView, state: .off)
            self.boxState = false
            self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_box", value: self.boxState)
        }
        
        self.display()
    }
}
