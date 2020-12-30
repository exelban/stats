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
    private let store: UnsafePointer<Store>
    private var button: NSPopUpButton?
    
    private var numberOfProcesses: Int = 8
    private let levelsList: [String] = [LocalizedString("Disabled"), "0.03", "0.05", "0.1", "0.15", "0.2", "0.25", "0.3", "0.4", "0.5"]
    private var lowLevelNotification: String {
        get {
            return self.store.pointee.string(key: "\(self.title)_lowLevelNotification", defaultValue: "0.15")
        }
    }
    private var timeFormat: String = "short"
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        self.numberOfProcesses = store.pointee.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.timeFormat = store.pointee.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
        
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
    
    public func load(widget: widget_t) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        let num: CGFloat = widget == .battery ? 3 : 2
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * num) + Constants.Settings.margin
        
        let levels: [String] = self.levelsList.map { (v: String) -> String in
            if let level = Double(v) {
                return "\(Int(level*100))%"
            }
            return v
        }
        
        self.addSubview(SelectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-1),
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: LocalizedString("Low level notification"),
            action: #selector(changeUpdateInterval),
            items: levels,
            selected: self.lowLevelNotification == "Disabled" ? LocalizedString("Disabled") : "\(Int((Double(self.lowLevelNotification) ?? 0)*100))%"
        ))
        
        self.addSubview(SelectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-2),
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: LocalizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        if widget == .battery {
            self.addSubview(SelectRow(
                frame: NSRect(
                    x: Constants.Settings.margin,
                    y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 0,
                    width: self.frame.width - (Constants.Settings.margin*2),
                    height: rowHeight
                ),
                title: LocalizedString("Time format"),
                action: #selector(toggleTimeFormat),
                items: ShortLong,
                selected: self.timeFormat
            ))
        }
        
        self.setFrameSize(NSSize(width: self.frame.width, height: height))
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if sender.title == LocalizedString("Disabled") {
            store.pointee.set(key: "\(self.title)_lowLevelNotification", value: "Disabled")
        } else if let value = Double(sender.title.replacingOccurrences(of: "%", with: "")) {
            store.pointee.set(key: "\(self.title)_lowLevelNotification", value: "\(value/100)")
        }
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            self.store.pointee.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    
    @objc private func toggleTimeFormat(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.timeFormat = key
        self.store.pointee.set(key: "\(self.title)_timeFormat", value: key)
        self.callback()
    }
}
