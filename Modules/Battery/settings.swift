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
import StatsKit
import ModuleKit
import SystemConfiguration

internal class Settings: NSView, Settings_v {
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    
    private let title: String
    private var button: NSPopUpButton?
    
    private var numberOfProcesses: Int = 8
    private let lowLevelsList: [String] = ["Disabled", "0.03", "0.05", "0.1", "0.15", "0.2", "0.25", "0.3", "0.4", "0.5"]
    private let highLevelsList: [String] = ["Disabled", "0.5", "0.6", "0.7", "0.75", "0.8", "0.85", "0.9", "0.95", "0.97", "1.0"]
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
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        let num: CGFloat = widgets.filter{ $0 == .battery }.isEmpty ? 3 : 4
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * num) + Constants.Settings.margin
        
        let lowLevels: [String] = self.lowLevelsList.map { (v: String) -> String in
            if let level = Double(v) {
                return "\(Int(level*100))%"
            }
            return v
        }
        
        let highLevels: [String] = self.highLevelsList.map { (v: String) -> String in
            if let level = Double(v) {
                return "\(Int(level*100))%"
            }
            return v
        }
        
        self.addSubview(selectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-1),
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: localizedString("Low level notification"),
            action: #selector(changeUpdateIntervalLow),
            items: lowLevels,
            selected: self.lowLevelNotification == "Disabled" ? self.lowLevelNotification : "\(Int((Double(self.lowLevelNotification) ?? 0)*100))%"
        ))
        
        self.addSubview(selectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-2),
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: localizedString("High level notification"),
            action: #selector(changeUpdateIntervalHigh),
            items: highLevels,
            selected: self.highLevelNotification == "Disabled" ? self.highLevelNotification : "\(Int((Double(self.highLevelNotification) ?? 0)*100))%"
        ))
        
        self.addSubview(selectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-3),
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        if !widgets.filter({ $0 == .battery }).isEmpty {
            self.addSubview(selectRow(
                frame: NSRect(
                    x: Constants.Settings.margin,
                    y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 0,
                    width: self.frame.width - (Constants.Settings.margin*2),
                    height: rowHeight
                ),
                title: localizedString("Time format"),
                action: #selector(toggleTimeFormat),
                items: ShortLong,
                selected: self.timeFormat
            ))
        }
        
        self.setFrameSize(NSSize(width: self.frame.width, height: height))
    }
    
    @objc private func changeUpdateIntervalLow(_ sender: NSMenuItem) {
        if sender.title == "Disabled" {
            Store.shared.set(key: "\(self.title)_lowLevelNotification", value: sender.title)
        } else if let value = Double(sender.title.replacingOccurrences(of: "%", with: "")) {
            Store.shared.set(key: "\(self.title)_lowLevelNotification", value: "\(value/100)")
        }
    }
    
    @objc private func changeUpdateIntervalHigh(_ sender: NSMenuItem) {
        if sender.title == "Disabled" {
            Store.shared.set(key: "\(self.title)_highLevelNotification", value: sender.title)
        } else if let value = Double(sender.title.replacingOccurrences(of: "%", with: "")) {
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
