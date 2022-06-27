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

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 3
    private var hidState: Bool
    private var fanSpeedState: Bool = false
    private var fansSyncState: Bool = false
    
    private let title: String
    private var button: NSPopUpButton?
    private var list: [Sensor_p]
    private var widgets: [widget_t] = []
    public var callback: (() -> Void) = {}
    public var HIDcallback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ title: String, list: [Sensor_p]) {
        self.title = title
        self.list = list
        self.hidState = isM1 ? true : false
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.wantsLayer = true
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.translatesAutoresizingMaskIntoConstraints = false
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
        
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.hidState = Store.shared.bool(key: "\(self.title)_hid", defaultValue: self.hidState)
        self.fanSpeedState = Store.shared.bool(key: "\(self.title)_speed", defaultValue: self.fanSpeedState)
        self.fansSyncState = Store.shared.bool(key: "\(self.title)_fansSync", defaultValue: self.fansSyncState)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        guard !self.list.isEmpty else {
            return
        }
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        self.addArrangedSubview(toggleSettingRow(
            title: localizedString("Save the fan speed"),
            action: #selector(toggleSpeedState),
            state: self.fanSpeedState
        ))
        
        self.addArrangedSubview(toggleSettingRow(
            title: localizedString("Synchronize the fans control"),
            action: #selector(toggleFansSync),
            state: self.fansSyncState
        ))
        
        if isARM {
            self.addArrangedSubview(toggleSettingRow(
                title: localizedString("HID sensors"),
                action: #selector(toggleHID),
                state: self.hidState
            ))
        }
        
        var types: [SensorType] = []
        self.list.forEach { (s: Sensor_p) in
            if !types.contains(s.type) {
                types.append(s.type)
            }
        }
        
        types.forEach { (typ: SensorType) in
            let header = NSStackView()
            header.heightAnchor.constraint(equalToConstant: Constants.Settings.row).isActive = true
            header.spacing = 0
            
            let titleField: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0), localizedString(typ.rawValue))
            titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            titleField.textColor = .labelColor
            
            header.addArrangedSubview(titleField)
            header.addArrangedSubview(NSView())
            
            self.addArrangedSubview(header)
            
            let filtered = self.list.filter{ $0.type == typ }
            var groups: [SensorGroup] = []
            filtered.forEach { (s: Sensor_p) in
                if !groups.contains(s.group) {
                    groups.append(s.group)
                }
            }
            
            let container = NSStackView()
            container.orientation = .vertical
            container.edgeInsets = NSEdgeInsets(
                top: 0,
                left: Constants.Settings.margin,
                bottom: 0,
                right: Constants.Settings.margin
            )
            container.spacing = 0
            
            groups.forEach { (group: SensorGroup) in
                filtered.filter{ $0.group == group }.forEach { (s: Sensor_p) in
                    let row: NSView = toggleSettingRow(
                        title: s.name,
                        action: #selector(self.handleSelection),
                        state: s.state
                    )
                    row.subviews.filter{ $0 is NSControl }.forEach { (control: NSView) in
                        control.identifier = NSUserInterfaceItemIdentifier(rawValue: s.key)
                    }
                    container.addArrangedSubview(row)
                }
            }

            self.addArrangedSubview(container)
        }
        
        self.widgets = widgets
    }
    
    public func setList(list: [Sensor_p]) {
        self.list = list
        self.load(widgets: self.widgets)
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
    
    @objc private func toggleSpeedState(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.fanSpeedState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_speed", value: self.fanSpeedState)
        self.callback()
    }
    
    @objc func toggleHID(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.hidState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_hid", value: self.hidState)
        self.HIDcallback()
    }
    
    @objc func toggleFansSync(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.fansSyncState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_fansSync", value: self.fansSyncState)
    }
}
