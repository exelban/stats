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

internal class Settings: NSView, Settings_v {
    private var usagePerCoreState: Bool = false
    private var hyperthreadState: Bool = false
    private var IPGState: Bool = false
    private var updateIntervalValue: Int = 1
    private var numberOfProcesses: Int = 8
    
    private let title: String
    private var hasHyperthreadingCores = false
    
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    public var IPGCallback: ((_ state: Bool) -> Void) = {_ in }
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    private var hyperthreadView: NSView? = nil
    
    public init(_ title: String) {
        self.title = title
        self.hyperthreadState = Store.shared.bool(key: "\(self.title)_hyperhreading", defaultValue: self.hyperthreadState)
        self.usagePerCoreState = Store.shared.bool(key: "\(self.title)_usagePerCore", defaultValue: self.usagePerCoreState)
        self.IPGState = Store.shared.bool(key: "\(self.title)_IPG", defaultValue: self.IPGState)
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        if !self.usagePerCoreState {
            self.hyperthreadState = false
        }
        self.hasHyperthreadingCores = sysctlByName("hw.physicalcpu") != sysctlByName("hw.logicalcpu")
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // swiftlint:disable function_body_length
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }

        var hasIPG = false
        
        #if arch(x86_64)
        let path: CFString = "/Library/Frameworks/IntelPowerGadget.framework" as CFString
        let bundleURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, CFURLPathStyle.cfurlposixPathStyle, true)
        hasIPG = CFBundleCreate(kCFAllocatorDefault, bundleURL) != nil
        #endif
        
        let rowHeight: CGFloat = 30
        var num: CGFloat = !widgets.filter{ $0 == .barChart }.isEmpty ? self.hasHyperthreadingCores ? 3 : 2 : 1
        if hasIPG {
            num += 1
        }
        
        self.addSubview(selectTitleRow(
            frame: NSRect(
                x: Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * num,
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        if !widgets.filter({ $0 == .barChart }).isEmpty {
            self.addSubview(toggleTitleRow(
                frame: NSRect(
                    x: Constants.Settings.margin,
                    y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-1),
                    width: self.frame.width - (Constants.Settings.margin*2),
                    height: rowHeight
                ),
                title: localizedString("Show usage per core"),
                action: #selector(toggleUsagePerCore),
                state: self.usagePerCoreState
            ))
            
            if self.hasHyperthreadingCores {
                self.hyperthreadView = toggleTitleRow(
                    frame: NSRect(
                        x: Constants.Settings.margin,
                        y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * (num-2),
                        width: self.frame.width - (Constants.Settings.margin*2),
                        height: rowHeight
                    ),
                    title: localizedString("Show hyper-threading cores"),
                    action: #selector(toggleMultithreading),
                    state: self.hyperthreadState
                )
                if !self.usagePerCoreState {
                    findAndToggleEnableNSControlState(self.hyperthreadView, state: false)
                    findAndToggleNSControlState(self.hyperthreadView, state: .off)
                }
                self.addSubview(self.hyperthreadView!)
            }
        }
        
        if hasIPG {
            self.addSubview(toggleTitleRow(
                frame: NSRect(
                    x: Constants.Settings.margin,
                    y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 1,
                    width: self.frame.width - (Constants.Settings.margin*2),
                    height: rowHeight
                ),
                title: "\(localizedString("CPU frequency")) (IPG)",
                action: #selector(toggleIPG),
                state: self.IPGState
            ))
        }
        
        self.addSubview(selectTitleRow(
            frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: self.frame.width - (Constants.Settings.margin*2), height: rowHeight),
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        self.setFrameSize(NSSize(width: self.frame.width, height: (rowHeight*(num+1)) + (Constants.Settings.margin*(2+num))))
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
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
        if !self.usagePerCoreState {
            self.hyperthreadState = false
            Store.shared.set(key: "\(self.title)_hyperhreading", value: self.hyperthreadState)
            findAndToggleNSControlState(self.hyperthreadView, state: .off)
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
}
