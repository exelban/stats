//
//  AppSettings.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import os.log

class ApplicationSettings: NSScrollView {
    private var updateIntervalValue: AppUpdateInterval {
        get {
            return LocalizedString(store.string(key: "update-interval", defaultValue: AppUpdateIntervals.atStart.rawValue))
        }
    }
    
    private var temperatureUnitsValue: String {
        get {
            return store.string(key: "temperature_units", defaultValue: "system")
        }
        set {
            store.set(key: "temperature_units", value: newValue)
        }
    }
    
    private var updateButton: NSButton? = nil
    private let updateWindow: UpdateWindow = UpdateWindow()
    
    init() {
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: 540,
            height: 480
        ))
        
        self.drawsBackground = false
        self.borderType = .noBorder
        self.hasVerticalScroller = true
        self.hasHorizontalScroller = false
        self.autohidesScrollers = true
        self.horizontalScrollElasticity = .none
        self.automaticallyAdjustsContentInsets = false
        
        let versionsView = self.versions()
        let settingsView = self.settings()
        
        let grid: NSGridView = NSGridView(frame: NSRect(
            x: 0,
            y: 0,
            width: self.frame.width,
            height: versionsView.frame.height + settingsView.frame.height
        ))
        grid.rowSpacing = 0
        grid.yPlacement = .fill
        
        let separator = NSBox()
        separator.boxType = .separator
        
        grid.addRow(with: [versionsView])
        grid.addRow(with: [separator])
        grid.addRow(with: [settingsView])
        
        grid.row(at: 0).height = versionsView.frame.height
        grid.row(at: 2).height = settingsView.frame.height
        
        self.documentView = grid
        if let documentView = self.documentView {
            documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func versions() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 280))
        
        let h: CGFloat = 120+60+18
        let container: NSGridView = NSGridView(frame: NSRect(x: 0, y: (view.frame.height-h)/2, width: self.frame.width, height: h))
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let iconView: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        iconView.frame = NSRect(x: (view.frame.width - 50)/2, y: 0, width: 50, height: 50)
        
        let statsName: NSTextField = TextView(frame: NSRect(x: 0, y: 20, width: view.frame.width, height: 22))
        statsName.alignment = .center
        statsName.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        statsName.stringValue = "Stats"
        statsName.isSelectable = true
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let statsVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 16))
        statsVersion.alignment = .center
        statsVersion.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statsVersion.stringValue = "\(LocalizedString("Version")) \(versionNumber)"
        statsVersion.isSelectable = true
        statsVersion.toolTip = "Build number: \(buildNumber)"
        
        let button: NSButton = NSButton(frame: NSRect(x: (view.frame.width - 160)/2, y: 0, width: 160, height: 30))
        button.title = LocalizedString("Check for update")
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(updateAction)
        self.updateButton = button
        
        container.addRow(with: [iconView])
        container.addRow(with: [statsName])
        container.addRow(with: [statsVersion])
        container.addRow(with: [button])
        
        container.column(at: 0).width = self.frame.width
        container.row(at: 1).height = 22
        container.row(at: 2).height = 20
        container.row(at: 3).height = 30
        
        view.addSubview(container)
        return view
    }
    
    private func settings() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        
        let grid: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        grid.rowSpacing = 10
        grid.columnSpacing = 20
        grid.xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        let separator = NSBox()
        separator.boxType = .separator
        
        grid.addRow(with: self.updates())
        grid.addRow(with: self.temperature())
        grid.addRow(with: self.dockIcon())
        grid.addRow(with: self.startAtLogin())
        
        view.addSubview(grid)
        
        var height: CGFloat = (CGFloat(grid.numberOfRows)-2) * grid.rowSpacing
        for i in 0..<grid.numberOfRows {
            let row = grid.row(at: i)
            for a in 0..<row.numberOfCells {
                if let contentView = row.cell(at: a).contentView {
                    height += contentView.frame.height
                }
            }
        }
        view.setFrameSize(NSSize(width: view.frame.width, height: max(200, height)))
        
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        return view
    }
    
    // MARK: - Views
    
    private func updates() -> [NSView] {
        return [
            self.titleView(LocalizedString("Check for updates")),
            SelectView(
                action: #selector(self.toggleUpdateInterval),
                items: AppUpdateIntervals.allCases.map{ KeyValue_t(key: $0.rawValue, value: $0.rawValue) },
                selected: self.updateIntervalValue
            )
        ]
    }
    
    private func temperature() -> [NSView] {
        return [
            self.titleView(LocalizedString("Temperature")),
            SelectView(
                action: #selector(self.toggleTemperatureUnits),
                items: TemperatureUnits,
                selected: self.temperatureUnitsValue
            )
        ]
    }
    
    private func dockIcon() -> [NSView] {
        return [
            self.titleView(LocalizedString("Show icon in dock")),
            self.toggleView(
                action: #selector(self.toggleDock),
                state: store.bool(key: "dockIcon", defaultValue: false)
            )
        ]
    }
    
    private func startAtLogin() -> [NSView] {
        return [
            self.titleView(LocalizedString("Start at login")),
            self.toggleView(
                action: #selector(self.toggleLaunchAtLogin),
                state: LaunchAtLogin.isEnabled
            )
        ]
    }
    
    // MARK: - helpers
    
    private func titleView(_ value: String) -> NSTextField {
        let field: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 120, height: 17))
        field.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        field.textColor = .secondaryLabelColor
        field.stringValue = value
        
        return field
    }
    
    private func toggleView(action: Selector, state: Bool) -> NSView {
        let state: NSControl.StateValue = state ? .on : .off
        var toggle: NSControl = NSControl()
        
        if #available(OSX 11.0, *) {
            let switchButton = NSSwitch(frame: NSRect(x: 0, y: 0, width: 50, height: 20))
            switchButton.state = state
            switchButton.action = action
            switchButton.target = self
            
            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
            button.setButtonType(.switch)
            button.state = state
            button.title = ""
            button.action = action
            button.isBordered = false
            button.isTransparent = true
            button.target = self
            
            toggle = button
        }
        
        return toggle
    }
    
    @objc func updateAction(_ sender: NSObject) {
        updater.check() { result, error in
            if error != nil {
                os_log(.error, log: log, "error updater.check(): %s", "\(error!.localizedDescription)")
                return
            }
            
            guard error == nil, let version: version_s = result else {
                os_log(.error, log: log, "download error(): %s", "\(error!.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async(execute: {
                self.updateWindow.open(version)
                return
            })
        }
    }
    
    @objc private func toggleUpdateInterval(_ sender: NSMenuItem) {
        if let newUpdateInterval = AppUpdateIntervals(rawValue: sender.title) {
            store.set(key: "update-interval", value: newUpdateInterval.rawValue)
            NotificationCenter.default.post(name: .changeCronInterval, object: nil, userInfo: nil)
        }
    }
    
    @objc private func toggleTemperatureUnits(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.temperatureUnitsValue = key
    }
    
    @objc func toggleDock(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 11.0, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        if state != nil {
            store.set(key: "dockIcon", value: state! == NSControl.StateValue.on)
        }
        let dockIconStatus = state == NSControl.StateValue.on ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
        NSApp.setActivationPolicy(dockIconStatus)
        if state == .off {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 11.0, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        LaunchAtLogin.isEnabled = state! == NSControl.StateValue.on
        if !store.exist(key: "runAtLoginInitialized") {
            store.set(key: "runAtLoginInitialized", value: true)
        }
    }
}
