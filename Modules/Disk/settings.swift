//
//  settings.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 12/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var removableState: Bool = false
    private var updateIntervalValue: Int = 10
    private var notificationLevel: String = "Disabled"
    
    public var selectedDiskHandler: (String) -> Void = {_ in }
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    private let title: String
    private var selectedDisk: String
    private var button: NSPopUpButton?
    private var intervalSelectView: NSView? = nil
    
    private var list: [String] = []
    
    public init(_ title: String) {
        self.title = title
        self.selectedDisk = Store.shared.string(key: "\(self.title)_disk", defaultValue: "")
        self.removableState = Store.shared.bool(key: "\(self.title)_removable", defaultValue: self.removableState)
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.notificationLevel = Store.shared.string(key: "\(self.title)_notificationLevel", defaultValue: self.notificationLevel)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.wantsLayer = true
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
        
        self.intervalSelectView = selectSettingsRowV1(
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        )
        self.addArrangedSubview(self.intervalSelectView!)
        
        self.addDiskSelector()
        
        self.addArrangedSubview(toggleSettingRow(
            title: localizedString("Show removable disks"),
            action: #selector(toggleRemovable),
            state: self.removableState
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Notification level"),
            action: #selector(changeNotificationLevel),
            items: notificationLevels,
            selected: self.notificationLevel == "Disabled" ? self.notificationLevel : "\(Int((Double(self.notificationLevel) ?? 0)*100))%"
        ))
    }
    
    private func addDiskSelector() {
        let view: NSStackView = NSStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: Constants.Settings.row).isActive = true
        view.orientation = .horizontal
        view.alignment = .centerY
        view.distribution = .fill
        view.spacing = 0
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 17), localizedString("Disk to show"))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        self.button = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 0, height: 30))
        self.button!.target = self
        self.button?.action = #selector(self.handleSelection)
        self.button?.addItems(withTitles: list)
        
        view.addArrangedSubview(rowTitle)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(self.button!)
        
        self.addArrangedSubview(view)
    }
    
    internal func setList(_ list: Disks) {
        let disks = list.map{ $0.mediaName }
        DispatchQueue.main.async(execute: {
            if self.button?.itemTitles.count != disks.count {
                self.button?.removeAllItems()
            }
            
            if disks != self.button?.itemTitles {
                self.button?.addItems(withTitles: disks)
                self.list = disks
                if self.selectedDisk != "" {
                    self.button?.selectItem(withTitle: self.selectedDisk)
                }
            }
        })
    }
    
    @objc private func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        self.selectedDisk = item.title
        Store.shared.set(key: "\(self.title)_disk", value: item.title)
        self.selectedDiskHandler(item.title)
    }
    
    @objc private func toggleRemovable(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.removableState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_removable", value: self.removableState)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.setUpdateInterval(value: value)
        }
    }
    
    @objc func changeNotificationLevel(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        
        if key == "Disabled" {
            Store.shared.set(key: "\(self.title)_notificationLevel", value: key)
        } else if let value = Double(key.replacingOccurrences(of: "%", with: "")) {
            Store.shared.set(key: "\(self.title)_notificationLevel", value: "\(value/100)")
        }
    }
    
    public func setUpdateInterval(value: Int) {
        self.updateIntervalValue = value
        Store.shared.set(key: "\(self.title)_updateInterval", value: value)
        self.setInterval(value)
    }
}
