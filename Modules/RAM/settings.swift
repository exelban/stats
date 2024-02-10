//
//  settings.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 11/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 1
    private var updateTopIntervalValue: Int = 1
    private var numberOfProcesses: Int = 8
    private var splitValueState: Bool = false
    private var notificationLevel: String = "Disabled"
    
    private let title: String
    
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    public var setTopInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ module: ModuleType) {
        self.title = module.rawValue
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.updateTopIntervalValue = Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: self.updateTopIntervalValue)
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.splitValueState = Store.shared.bool(key: "\(self.title)_splitValue", defaultValue: self.splitValueState)
        self.notificationLevel = Store.shared.string(key: "\(self.title)_notificationLevel", defaultValue: self.notificationLevel)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Update interval for top processes"),
            action: #selector(changeUpdateTopInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateTopIntervalValue) sec"
        ))
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        if !widgets.filter({ $0 == .barChart }).isEmpty {
            self.addArrangedSubview(toggleSettingRow(
                title: localizedString("Split the value (App/Wired/Compressed)"),
                action: #selector(toggleSplitValue),
                state: self.splitValueState
            ))
        }
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Notification level"),
            action: #selector(changeNotificationLevel),
            items: notificationLevels,
            selected: self.notificationLevel == "disabled" ? self.notificationLevel : "\(Int((Double(self.notificationLevel) ?? 0)*100))%"
        ))
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
    
    @objc private func changeUpdateTopInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateTopIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateTopInterval", value: value)
            self.setTopInterval(value)
        }
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    
    @objc func toggleSplitValue(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.splitValueState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_splitValue", value: self.splitValueState)
        self.callback()
    }
    
    @objc func changeNotificationLevel(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        
        if key == "Disabled" {
            Store.shared.set(key: "\(self.title)_notificationLevel", value: key)
        } else if let value = Double(key.replacingOccurrences(of: "%", with: "")) {
            Store.shared.set(key: "\(self.title)_notificationLevel", value: "\(value/100)")
        }
    }
}
