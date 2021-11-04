//
//  settings.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 15/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit
import SystemConfiguration

internal class Settings: NSStackView, Settings_v {
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    
    private let title: String
    private var button: NSPopUpButton?
    
    private var numberOfProcesses: Int = 8
    private let lowLevelsList: [KeyValue_t] = [
        KeyValue_t(key: "Disabled", value: "Disabled"),
        KeyValue_t(key: "3%", value: "3%"),
        KeyValue_t(key: "5%", value: "5%"),
        KeyValue_t(key: "10%", value: "10%"),
        KeyValue_t(key: "15%", value: "15%"),
        KeyValue_t(key: "20%", value: "20%"),
        KeyValue_t(key: "25%", value: "25%"),
        KeyValue_t(key: "30%", value: "30%"),
        KeyValue_t(key: "40%", value: "40%"),
        KeyValue_t(key: "50%", value: "50%")
    ]
    private let highLevelsList: [KeyValue_t] = [
        KeyValue_t(key: "Disabled", value: "Disabled"),
        KeyValue_t(key: "50%", value: "50%"),
        KeyValue_t(key: "60%", value: "60%"),
        KeyValue_t(key: "70%", value: "70%"),
        KeyValue_t(key: "75%", value: "75%"),
        KeyValue_t(key: "80%", value: "80%"),
        KeyValue_t(key: "85%", value: "85%"),
        KeyValue_t(key: "90%", value: "90%"),
        KeyValue_t(key: "95%", value: "95%"),
        KeyValue_t(key: "97%", value: "97%"),
        KeyValue_t(key: "100%", value: "100%")
    ]
    private var lowLevelNotification: String {
        get {
            return Store.shared.string(key: "\(self.title)_lowLevelNotification", defaultValue: "0.15")
        }
    }
    private var highLevelNotification: String {
        get {
            return Store.shared.string(key: "\(self.title)_highLevelNotification", defaultValue: "Disabled")
        }
    }
    private var timeFormat: String = "short"
    
    public init(_ title: String) {
        self.title = title
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.timeFormat = Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
        
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
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Low level notification"),
            action: #selector(changeUpdateIntervalLow),
            items: self.lowLevelsList,
            selected: self.lowLevelNotification == "Disabled" ? self.lowLevelNotification : "\(Int((Double(self.lowLevelNotification) ?? 0)*100))%"
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("High level notification"),
            action: #selector(changeUpdateIntervalHigh),
            items: self.highLevelsList,
            selected: self.highLevelNotification == "Disabled" ? self.highLevelNotification : "\(Int((Double(self.highLevelNotification) ?? 0)*100))%"
        ))
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        if !widgets.filter({ $0 == .battery }).isEmpty {
            self.addArrangedSubview(selectSettingsRow(
                title: localizedString("Time format"),
                action: #selector(toggleTimeFormat),
                items: ShortLong,
                selected: self.timeFormat
            ))
        }
    }
    
    @objc private func changeUpdateIntervalLow(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        
        if key == "Disabled" {
            Store.shared.set(key: "\(self.title)_lowLevelNotification", value: key)
        } else if let value = Double(key.replacingOccurrences(of: "%", with: "")) {
            Store.shared.set(key: "\(self.title)_lowLevelNotification", value: "\(value/100)")
        }
    }
    
    @objc private func changeUpdateIntervalHigh(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        
        if key == "Disabled" {
            Store.shared.set(key: "\(self.title)_highLevelNotification", value: key)
        } else if let value = Double(key.replacingOccurrences(of: "%", with: "")) {
            Store.shared.set(key: "\(self.title)_highLevelNotification", value: "\(value/100)")
        }
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    
    @objc private func toggleTimeFormat(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.timeFormat = key
        Store.shared.set(key: "\(self.title)_timeFormat", value: key)
        self.callback()
    }
}
