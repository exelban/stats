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

class ApplicationSettings: NSView {
    private let width: CGFloat = 540
    private let height: CGFloat = 480
    private let deviceInfoHeight: CGFloat = 300
    
    private var updateIntervalValue: AppUpdateInterval {
        get {
            return store.string(key: "update-interval", defaultValue: AppUpdateIntervals.atStart.rawValue)
        }
    }
    
    private var updateButton: NSButton? = nil
    private let updateWindow: UpdateWindow = UpdateWindow()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        self.wantsLayer = true
        self.layer?.backgroundColor = .clear
        
        self.addDeviceInfo()
        self.addSettings()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidMoveToWindow() {
        if let button = self.updateButton, let version = updater.latest {
            if version.newest {
                button.title = LocalizedString("Update application")
            } else {
                button.title = LocalizedString("Check for update")
            }
        }
    }
    
    private func addSettings() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 1, width: self.width-1, height: self.height - self.deviceInfoHeight))
        let rowHeight: CGFloat = 40
        let rowHorizontalPadding: CGFloat = 16
        
        let leftPanel: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width/2, height: view.frame.height))
        leftPanel.wantsLayer = true
        
        var processorInfo = ""
        if systemKit.device.info?.cpu?.name != "" {
            processorInfo += "\(systemKit.device.info?.cpu?.name ?? LocalizedString("Unknown"))\n"
        }
        processorInfo += "\(systemKit.device.info?.cpu?.physicalCores ?? 0) cores (\(systemKit.device.info?.cpu?.logicalCores ?? 0) threads)"
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*3, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight+8),
            title: LocalizedString("Processor"),
            value: processorInfo
        ))
        
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useGB]
        sizeFormatter.countStyle = .memory
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*2, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: LocalizedString("Memory"),
            value: "\(sizeFormatter.string(fromByteCount: Int64(systemKit.device.info?.ram?.total ?? 0)))"
        ))
        
        let gpus = systemKit.device.info?.gpu
        var gpu: String = LocalizedString("Unknown")
        if gpus != nil {
            if gpus?.count == 1 {
                gpu = gpus![0].name
            } else {
                gpu = ""
                gpus!.forEach{ gpu += "\($0.name)\n" }
            }
        }
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*1, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: LocalizedString("Graphics"),
            value: gpu
        ))
        
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: 0, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: LocalizedString("Disk"),
            value: "\(systemKit.device.info?.disk?.model ?? systemKit.device.info?.disk?.name ?? LocalizedString("Unknown"))"
        ))
        
        let rightPanel: NSView = NSView(frame: NSRect(x: self.width/2, y: 0, width: view.frame.width/2, height: view.frame.height))
        
        rightPanel.addSubview(makeSelectRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*2, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: LocalizedString("Check for updates"),
            action: #selector(self.toggleUpdateInterval),
            items: AppUpdateIntervals.allCases.map{ $0.rawValue },
            selected: self.updateIntervalValue
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*1, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: LocalizedString("Show icon in dock"),
            action: #selector(self.toggleDock),
            state: store.bool(key: "dockIcon", defaultValue: false)
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: 0, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: LocalizedString("Start at login"),
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled
        ))
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        self.addSubview(view)
    }
    
    func makeSelectRow(frame: NSRect, title: String, action: Selector, items: [String], selected: String) -> NSView {
        let row: NSView = NSView(frame: frame)
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (row.frame.height - 32)/2, width: row.frame.width - 52, height: 32), title)
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .secondaryLabelColor
        
        let select: NSPopUpButton = NSPopUpButton(frame: NSRect(x: row.frame.width - 50, y: (row.frame.height-28)/2, width: 50, height: 28))
        select.target = self
        select.action = action
        
        let menu = NSMenu()
        items.forEach { (color: String) in
            if color.contains("separator") {
                menu.addItem(NSMenuItem.separator())
            } else {
                let interfaceMenu = NSMenuItem(title: color, action: nil, keyEquivalent: "")
                menu.addItem(interfaceMenu)
                if selected == color {
                    interfaceMenu.state = .on
                }
            }
        }
        
        select.menu = menu
        select.sizeToFit()
        
        rowTitle.setFrameSize(NSSize(width: row.frame.width - select.frame.width, height: rowTitle.frame.height))
        select.setFrameOrigin(NSPoint(x: row.frame.width - select.frame.width, y: select.frame.origin.y))
        
        row.addSubview(select)
        row.addSubview(rowTitle)
        
        return row
    }
    
    private func makeInfoRow(frame: NSRect, title: String, value: String) -> NSView {
        let row: NSView = NSView(frame: frame)
        let titleWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 10
        
        let rowTitle: NSTextField = TextView(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: titleWidth, height: 17))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .secondaryLabelColor
        rowTitle.stringValue = title
        
        let rowValue: NSTextField = TextView(frame: NSRect(x: titleWidth, y: (row.frame.height - 16)/2, width: row.frame.width - titleWidth, height: 17))
        rowValue.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowValue.alignment = .right
        rowValue.stringValue = value
        rowValue.isSelectable = true
        
        if value.contains("\n") {
            rowValue.frame = NSRect(x: titleWidth, y: 0, width: rowValue.frame.width, height: row.frame.height)
        }
        
        row.addSubview(rowTitle)
        row.addSubview(rowValue)
        
        return row
    }
    
    private func makeSettingRow(frame: NSRect, title: String, action: Selector, state: Bool) -> NSView {
        let row: NSView = NSView(frame: frame)
        let state: NSControl.StateValue = state ? .on : .off
        
        let rowTitle: NSTextField = TextView(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .secondaryLabelColor
        rowTitle.stringValue = title
        
        var toggle: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: row.frame.width - 50, y: 0, width: 50, height: row.frame.height))
            switchButton.state = state
            switchButton.action = action
            switchButton.target = self

            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: row.frame.width - 30, y: 0, width: 30, height: row.frame.height))
            button.setButtonType(.switch)
            button.state = state
            button.title = ""
            button.action = action
            button.isBordered = false
            button.isTransparent = true
            button.target = self
            
            toggle = button
        }

        row.addSubview(toggle)
        row.addSubview(rowTitle)
        
        return row
    }
    
    private func addDeviceInfo() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.height - self.deviceInfoHeight, width: self.width, height: self.deviceInfoHeight))
        let leftPanel: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.width/2, height: self.deviceInfoHeight))
        
        let deviceImageView: NSImageView = NSImageView(image: systemKit.device.model.icon)
        deviceImageView.frame = NSRect(x: (leftPanel.frame.width - 160)/2, y: ((self.deviceInfoHeight - 120)/2) + 22, width: 160, height: 120)
        
        let deviceNameField: NSTextField = TextView(frame: NSRect(x: 0, y: 72, width: leftPanel.frame.width, height: 20))
        deviceNameField.alignment = .center
        deviceNameField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        deviceNameField.stringValue = systemKit.device.model.name
        deviceNameField.isSelectable = true
        deviceNameField.toolTip = systemKit.device.modelIdentifier
        
        let osField: NSTextField = TextView(frame: NSRect(x: 0, y: 52, width: leftPanel.frame.width, height: 18))
        osField.alignment = .center
        osField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        osField.stringValue = "macOS \(systemKit.device.os?.name ?? LocalizedString("Unknown")) (\(systemKit.device.os?.version.getFullVersion() ?? ""))"
        osField.isSelectable = true
        
        leftPanel.addSubview(deviceImageView)
        leftPanel.addSubview(deviceNameField)
        leftPanel.addSubview(osField)
        
        let rightPanel: NSView = NSView(frame: NSRect(x: self.width/2, y: 0, width: self.width/2, height: self.deviceInfoHeight))
        
        let iconView: NSImageView = NSImageView(frame: NSRect(x: (leftPanel.frame.width - 100)/2, y: ((self.deviceInfoHeight - 100)/2) + 32, width: 100, height: 100))
        iconView.image = NSImage(named: NSImage.Name("AppIcon"))!
        
        let infoView: NSView = NSView(frame: NSRect(x: 0, y: 54, width: self.width/2, height: 42))
        
        let statsName: NSTextField = TextView(frame: NSRect(x: 0, y: 20, width: leftPanel.frame.width, height: 22))
        statsName.alignment = .center
        statsName.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        statsName.stringValue = "Stats"
        statsName.isSelectable = true
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let statsVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: leftPanel.frame.width, height: 16))
        statsVersion.alignment = .center
        statsVersion.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statsVersion.stringValue = "\(LocalizedString("Version")) \(versionNumber)"
        statsVersion.isSelectable = true
        statsVersion.toolTip = "Build number: \(buildNumber)"
        
        infoView.addSubview(statsName)
        infoView.addSubview(statsVersion)
        
        let button: NSButton = NSButton(frame: NSRect(x: (rightPanel.frame.width - 160)/2, y: 20, width: 160, height: 28))
        button.title = LocalizedString("Check for update")
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(updateAction)
        self.updateButton = button
        
        rightPanel.addSubview(iconView)
        rightPanel.addSubview(infoView)
        rightPanel.addSubview(button)
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        
        self.addSubview(view)
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
    
    @objc func toggleDock(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
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
        if #available(OSX 10.15, *) {
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
