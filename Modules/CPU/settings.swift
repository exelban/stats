//
//  Settings.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var usagePerCoreState: Bool = false
    private var hyperthreadState: Bool = false
    private var splitValueState: Bool = false
    private var IPGState: Bool = false
    private var updateIntervalValue: Int = 1
    private var updateTopIntervalValue: Int = 1
    private var numberOfProcesses: Int = 8
    private var notificationLevel: String = "Disabled"
    private var clustersGroupState: Bool = false
    
    private let title: String
    private var hasHyperthreadingCores = false
    
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    public var IPGCallback: ((_ state: Bool) -> Void) = {_ in }
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    public var setTopInterval: ((_ value: Int) -> Void) = {_ in }
    
    private var hyperthreadView: NSView? = nil
    private var splitValueView: NSView? = nil
    private var usagePerCoreView: NSView? = nil
    private var groupByClustersView: NSView? = nil
    
    public init(_ title: String) {
        self.title = title
        self.hyperthreadState = Store.shared.bool(key: "\(self.title)_hyperhreading", defaultValue: self.hyperthreadState)
        self.usagePerCoreState = Store.shared.bool(key: "\(self.title)_usagePerCore", defaultValue: self.usagePerCoreState)
        self.splitValueState = Store.shared.bool(key: "\(self.title)_splitValue", defaultValue: self.splitValueState)
        self.IPGState = Store.shared.bool(key: "\(self.title)_IPG", defaultValue: self.IPGState)
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.updateTopIntervalValue = Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: self.updateTopIntervalValue)
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.notificationLevel = Store.shared.string(key: "\(self.title)_notificationLevel", defaultValue: self.notificationLevel)
        if !self.usagePerCoreState {
            self.hyperthreadState = false
        }
        self.hasHyperthreadingCores = sysctlByName("hw.physicalcpu") != sysctlByName("hw.logicalcpu")
        self.clustersGroupState = Store.shared.bool(key: "\(self.title)_clustersGroup", defaultValue: self.clustersGroupState)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        var hasIPG = false
        #if arch(x86_64)
        let path: CFString = "/Library/Frameworks/IntelPowerGadget.framework" as CFString
        let bundleURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, CFURLPathStyle.cfurlposixPathStyle, true)
        hasIPG = CFBundleCreate(kCFAllocatorDefault, bundleURL) != nil
        #endif
        
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
        
        if !widgets.filter({ $0 == .barChart }).isEmpty {
            self.usagePerCoreView = toggleSettingRow(
                title: localizedString("Show usage per core"),
                action: #selector(toggleUsagePerCore),
                state: self.usagePerCoreState
            )
            self.addArrangedSubview(self.usagePerCoreView!)
            
            #if arch(arm64)
            self.groupByClustersView = toggleSettingRow(
                title: localizedString("Cluster grouping"),
                action: #selector(toggleClustersGroup),
                state: self.clustersGroupState
            )
            self.addArrangedSubview(self.groupByClustersView!)
            #endif
            
            if self.hasHyperthreadingCores {
                self.hyperthreadView = toggleSettingRow(
                    title: localizedString("Show hyper-threading cores"),
                    action: #selector(toggleMultithreading),
                    state: self.hyperthreadState
                )
                if !self.usagePerCoreState {
                    findAndToggleEnableNSControlState(self.hyperthreadView, state: false)
                    findAndToggleNSControlState(self.hyperthreadView, state: .off)
                }
                self.addArrangedSubview(self.hyperthreadView!)
            }
            
            self.splitValueView = toggleSettingRow(
                title: localizedString("Split the value (System/User)"),
                action: #selector(toggleSplitValue),
                state: self.splitValueState
            )
            if self.usagePerCoreState || self.clustersGroupState {
                findAndToggleEnableNSControlState(self.splitValueView, state: false)
                findAndToggleNSControlState(self.splitValueView, state: .off)
            }
            self.addArrangedSubview(self.splitValueView!)
        }
        
        #if arch(x86_64)
        if hasIPG {
            self.addArrangedSubview(toggleSettingRow(
                title: "\(localizedString("CPU frequency")) (IPG)",
                action: #selector(toggleIPG),
                state: self.IPGState
            ))
        }
        #endif
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
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
    
    @objc func toggleUsagePerCore(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.usagePerCoreState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_usagePerCore", value: self.usagePerCoreState)
        self.callback()
        
        findAndToggleEnableNSControlState(self.hyperthreadView, state: self.usagePerCoreState)
        findAndToggleEnableNSControlState(self.splitValueView, state: !(self.usagePerCoreState || self.clustersGroupState))
        
        if !self.usagePerCoreState {
            self.hyperthreadState = false
            Store.shared.set(key: "\(self.title)_hyperhreading", value: self.hyperthreadState)
            findAndToggleNSControlState(self.hyperthreadView, state: .off)
        } else {
            self.splitValueState = false
            Store.shared.set(key: "\(self.title)_splitValue", value: self.splitValueState)
            findAndToggleNSControlState(self.splitValueView, state: .off)
        }
        
        if self.clustersGroupState && self.usagePerCoreState {
            self.clustersGroupState = false
            Store.shared.set(key: "\(self.title)_clustersGroup", value: self.clustersGroupState)
            findAndToggleNSControlState(self.groupByClustersView, state: .off)
        }
    }
    
    @objc func toggleMultithreading(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.hyperthreadState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_hyperhreading", value: self.hyperthreadState)
        self.callback()
    }
    
    @objc func toggleIPG(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.IPGState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_IPG", value: self.IPGState)
        self.IPGCallback(self.IPGState)
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
    
    @objc func toggleClustersGroup(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.clustersGroupState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_clustersGroup", value: self.clustersGroupState)
        
        findAndToggleEnableNSControlState(self.splitValueView, state: !(self.usagePerCoreState || self.clustersGroupState))
        
        if self.clustersGroupState && self.usagePerCoreState {
            if #available(macOS 10.15, *) {
                findAndToggleNSControlState(self.usagePerCoreView, state: .off)
                let toggle: NSSwitch = NSSwitch()
                toggle.state = .off
                self.toggleUsagePerCore(toggle)
            }
        }
        
        self.callback()
    }
}
