//
//  settings.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 23/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

internal class Settings: NSView, Settings_v {
    private var updateIntervalValue: String = "3"
    private let listOfUpdateIntervals: [String] = ["1", "2", "3", "5", "10", "15", "30"]
    
    private let title: String
    private let store: UnsafePointer<Store>
    private var button: NSPopUpButton?
    private let list: UnsafeMutablePointer<[Sensor_t]>
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Double) -> Void) = {_ in }
    
    public init(_ title: String, store: UnsafePointer<Store>, list: UnsafeMutablePointer<[Sensor_t]>) {
        self.title = title
        self.store = store
        self.list = list
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
        
        self.updateIntervalValue = store.pointee.string(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func load(widget: widget_t) {
        guard !self.list.pointee.isEmpty else {
            return
        }
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        var types: [SensorType_t] = []
        self.list.pointee.forEach { (s: Sensor_t) in
            if !types.contains(s.type) {
                types.append(s.type)
            }
        }
        
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight+Constants.Settings.margin) * CGFloat(self.list.pointee.count) + rowHeight) + ((rowHeight+Constants.Settings.margin) * CGFloat(types.count) + 1)
        let x: CGFloat = height < 360 ? 0 : Constants.Settings.margin
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: self.frame.width - (Constants.Settings.margin*2) - x, height: height))
        
        self.addSubview(SelectTitleRow(
            frame: NSRect(x: Constants.Settings.margin, y: height - rowHeight, width: view.frame.width, height: rowHeight),
            title: "Update interval",
            action: #selector(changeUpdateInterval),
            items: self.listOfUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        var y: CGFloat = 0
        types.reversed().forEach { (typ: SensorType_t) in
            let filtered = self.list.pointee.filter{ $0.type == typ }
            var groups: [SensorGroup_t] = []
            filtered.forEach { (s: Sensor_t) in
                if !groups.contains(s.group) {
                    groups.append(s.group)
                }
            }
            
            groups.reversed().forEach { (group: SensorGroup_t) in
                filtered.reversed().filter{ $0.group == group }.forEach { (s: Sensor_t) in
                    let row: NSView = ToggleTitleRow(
                        frame: NSRect(x: 0, y: y, width: view.frame.width, height: rowHeight),
                        title: s.name,
                        action: #selector(self.handleSelection),
                        state: s.state
                    )
                    row.subviews.filter{ $0 is NSControl }.forEach { (control: NSView) in
                        control.identifier = NSUserInterfaceItemIdentifier(rawValue: s.key)
                    }
                    view.addSubview(row)
                    y += rowHeight + Constants.Settings.margin
                }
            }
            
            let rowTitleView: NSView = NSView(frame: NSRect(x: 0, y: y, width: view.frame.width, height: rowHeight))
            let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (rowHeight-19)/2, width: view.frame.width, height: 19), typ)
            rowTitle.font = NSFont.systemFont(ofSize: 14, weight: .regular)
            rowTitle.textColor = .secondaryLabelColor
            rowTitle.alignment = .center
            rowTitleView.addSubview(rowTitle)
            
            view.addSubview(rowTitleView)
            y += rowHeight + Constants.Settings.margin
        }
        
        self.addSubview(view)
        self.setFrameSize(NSSize(width: self.frame.width, height: height + (Constants.Settings.margin*1)))
    }
    
    @objc func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.store.pointee.set(key: "sensor_\(id.rawValue)", value:  state! == NSControl.StateValue.on)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        let newUpdateInterval = sender.title.replacingOccurrences(of: " sec", with: "")
        self.updateIntervalValue = newUpdateInterval
        store.pointee.set(key: "\(self.title)_updateInterval", value: self.updateIntervalValue)
        
        if let value = Double(self.updateIntervalValue) {
            self.setInterval(value)
        }
    }
}
