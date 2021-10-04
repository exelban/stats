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
import Kit

internal class Settings: NSView, Settings_v {
    private var updateIntervalValue: Int = 3
    
    private let title: String
    private var button: NSPopUpButton?
    private let list: [Sensor_p]
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ title: String, list: [Sensor_p]) {
        self.title = title
        self.list = list
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
        
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        guard !self.list.isEmpty else {
            return
        }
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        var types: [SensorType] = []
        self.list.forEach { (s: Sensor_p) in
            if !types.contains(s.type) {
                types.append(s.type)
            }
        }
        
        let rowHeight: CGFloat = 30
        let settingsHeight: CGFloat = (rowHeight*1) + Constants.Settings.margin
        let sensorsListHeight: CGFloat = (rowHeight+Constants.Settings.margin) * CGFloat(self.list.count) + ((rowHeight+Constants.Settings.margin) * CGFloat(types.count) + 1)
        let height: CGFloat = settingsHeight + sensorsListHeight
        let x: CGFloat = height < 360 ? 0 : Constants.Settings.margin
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: self.frame.width - (Constants.Settings.margin*2) - x,
            height: height
        ))
        
        self.addSubview(selectTitleRow(
            frame: NSRect(x: Constants.Settings.margin, y: height - rowHeight, width: view.frame.width, height: rowHeight),
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        var y: CGFloat = 0
        types.reversed().forEach { (typ: SensorType) in
            let filtered = self.list.filter{ $0.type == typ }
            var groups: [SensorGroup] = []
            filtered.forEach { (s: Sensor_p) in
                if !groups.contains(s.group) {
                    groups.append(s.group)
                }
            }
            
            groups.reversed().forEach { (group: SensorGroup) in
                filtered.reversed().filter{ $0.group == group }.forEach { (s: Sensor_p) in
                    let row: NSView = toggleTitleRow(
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
            let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (rowHeight-19)/2, width: view.frame.width, height: 19), localizedString(typ.rawValue))
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
    
    @objc private func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        Store.shared.set(key: "sensor_\(id.rawValue)", value: state! == NSControl.StateValue.on)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
}
