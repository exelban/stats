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
    private let title: String
    
    private var removableState: Bool = false
    private var updateIntervalValue: Int = 10
    private var numberOfProcesses: Int = 5
    private var baseValue: String = "byte"
    private var SMARTState: Bool = true
    
    public var selectedDiskHandler: (String) -> Void = {_ in }
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    
    private var selectedDisk: String
    private var button: NSPopUpButton?
    
    private var list: [String] = []
    
    public init(_ module: ModuleType) {
        self.title = module.stringValue
        
        self.selectedDisk = Store.shared.string(key: "\(self.title)_disk", defaultValue: "")
        self.removableState = Store.shared.bool(key: "\(self.title)_removable", defaultValue: self.removableState)
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.baseValue = Store.shared.string(key: "\(self.title)_base", defaultValue: self.baseValue)
        self.SMARTState = Store.shared.bool(key: "\(self.title)_SMART", defaultValue: self.SMARTState)
        
        super.init(frame: NSRect.zero)
        
        self.orientation = .vertical
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
            ))
        ]))
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Number of top processes"), component: selectView(
                action: #selector(self.changeNumberOfProcesses),
                items: NumbersOfProcesses.map{ KeyValue_t(key: "\($0)", value: "\($0)") },
                selected: "\(self.numberOfProcesses)"
            ))
        ]))
        
        self.button = selectView(
            action: #selector(self.handleSelection),
            items: [],
            selected: ""
        )
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Disk to show"), component: self.button!),
            PreferencesRow(localizedString("Show removable disks"), component: switchView(
                action: #selector(self.toggleRemovable),
                state: self.removableState
            ))
        ]))
        
        if widgets.contains(where: { $0 == .speed }) {
            self.addArrangedSubview(PreferencesSection([
                PreferencesRow(localizedString("Base"), component: selectView(
                    action: #selector(self.toggleBase),
                    items: SpeedBase,
                    selected: self.baseValue
                ))
            ]))
        }
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("SMART data"), component: switchView(
                action: #selector(self.toggleSMART),
                state: self.SMARTState
            ))
        ]))
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
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    @objc private func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        self.selectedDisk = item.title
        Store.shared.set(key: "\(self.title)_disk", value: item.title)
        self.selectedDiskHandler(item.title)
    }
    @objc private func toggleRemovable(_ sender: NSControl) {
        self.removableState = controlState(sender)
        Store.shared.set(key: "\(self.title)_removable", value: self.removableState)
        self.callback()
    }
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.setUpdateInterval(value: value)
        }
    }
    public func setUpdateInterval(value: Int) {
        self.updateIntervalValue = value
        Store.shared.set(key: "\(self.title)_updateInterval", value: value)
        self.setInterval(value)
    }
    
    @objc private func toggleBase(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.baseValue = key
        Store.shared.set(key: "\(self.title)_base", value: self.baseValue)
    }
    @objc private func toggleSMART(_ sender: NSControl) {
        self.SMARTState = controlState(sender)
        Store.shared.set(key: "\(self.title)_SMART", value: self.SMARTState)
        self.callback()
    }
}
