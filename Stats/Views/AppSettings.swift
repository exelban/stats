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

class ApplicationSettings: NSView {
    private let width: CGFloat = 540
    private let height: CGFloat = 480
    private let deviceInfoHeight: CGFloat = 300
    
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
    
    private func addSettings() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 1, width: self.width-1, height: self.height - self.deviceInfoHeight))
        let rowHeight: CGFloat = 40
        let rowHorizontalPadding: CGFloat = 16
        
        let leftPanel: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width/2, height: view.frame.height))
        leftPanel.wantsLayer = true
        
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*3, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Processor",
            value: "\(systemKit.device.info?.cpu?.physicalCores ?? 0) cores (\(systemKit.device.info?.cpu?.logicalCores ?? 0) threads)"
        ))
        
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useGB]
        sizeFormatter.countStyle = .memory
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*2, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Memory",
            value: "\(sizeFormatter.string(fromByteCount: Int64(systemKit.device.info?.ram?.total ?? 0)))"
        ))
        
        let gpus = systemKit.device.info?.gpu
        var gpu: String = "Unknown"
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
            title: "GPU",
            value: gpu
        ))
        
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: 0, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Disk",
            value: "\(systemKit.device.info?.disk?.model ?? systemKit.device.info?.disk?.name ?? "Unknown")"
        ))
        
        let rightPanel: NSView = NSView(frame: NSRect(x: self.width/2, y: 0, width: view.frame.width/2, height: view.frame.height))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*2, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Check for updates on start",
            action: #selector(self.toggleUpdates),
            state: store.bool(key: "checkUpdatesOnLogin", defaultValue: true)
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*1, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Show icon in dock",
            action: #selector(self.toggleDock),
            state: store.bool(key: "dockIcon", defaultValue: false)
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: 0, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Start at login",
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled
        ))
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        self.addSubview(view)
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

        let osField: NSTextField = TextView(frame: NSRect(x: 0, y: 52, width: leftPanel.frame.width, height: 18))
        osField.alignment = .center
        osField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        osField.stringValue = "macOS \(systemKit.device.os?.name ?? "Unknown") (\(systemKit.device.os?.version.getFullVersion() ?? ""))"
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
        
        let statsVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: leftPanel.frame.width, height: 16))
        statsVersion.alignment = .center
        statsVersion.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        statsVersion.stringValue = "Version \(versionNumber)"
        statsVersion.isSelectable = true
        
        infoView.addSubview(statsName)
        infoView.addSubview(statsVersion)
        
        let button: NSButton = NSButton(frame: NSRect(x: (rightPanel.frame.width - 160)/2, y: 20, width: 160, height: 28))
        button.title = "Check for updates"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(checkNewVersion)
        
        rightPanel.addSubview(iconView)
        rightPanel.addSubview(infoView)
        rightPanel.addSubview(button)
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        
        self.addSubview(view)
    }
    
    @objc func checkNewVersion(_ sender: NSObject) {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil, userInfo: nil)
    }
    
    @objc func toggleUpdates(_ sender: NSObject) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        if state != nil {
            store.set(key: "checkUpdatesOnLogin", value: state! == NSControl.StateValue.on)
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
