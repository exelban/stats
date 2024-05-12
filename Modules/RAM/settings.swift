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
        
        super.init(frame: NSRect.zero)
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Update interval"), component: selectView(
                action: #selector(self.changeUpdateInterval),
                items: ReaderUpdateIntervals,
                selected: "\(self.updateIntervalValue)"
            )),
            PreferencesRow(localizedString("Update interval for top processes"), component: selectView(
                action: #selector(self.changeUpdateTopInterval),
                items: ReaderUpdateIntervals,
                selected: "\(self.updateTopIntervalValue)"
            ))
        ]))
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Number of top processes"), component: selectView(
                action: #selector(changeNumberOfProcesses),
                items: NumbersOfProcesses.map{ KeyValue_t(key: "\($0)", value: "\($0)") },
                selected: "\(self.numberOfProcesses)"
            ))
        ]))
        
        if !widgets.filter({ $0 == .barChart }).isEmpty {
            self.addArrangedSubview(PreferencesSection([
                PreferencesRow(localizedString("Split the value (App/Wired/Compressed)"), component: switchView(
                    action: #selector(toggleSplitValue),
                    state: self.splitValueState
                ))
            ]))
        }
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
    @objc private func toggleSplitValue(_ sender: NSControl) {
        self.splitValueState = controlState(sender)
        Store.shared.set(key: "\(self.title)_splitValue", value: self.splitValueState)
        self.callback()
    }
}
