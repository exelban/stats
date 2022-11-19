//
//  settings.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 1
    private var selectedGPU: String
    private var showTypeValue: Bool = false
    private var notificationLevel: String = "Disabled"
    
    private let title: String
    
    public var selectedGPUHandler: (String) -> Void = {_ in }
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    private var hyperthreadView: NSView? = nil
    private var button: NSPopUpButton?
    
    public init(_ title: String) {
        self.title = title
        self.selectedGPU = Store.shared.string(key: "\(self.title)_gpu", defaultValue: "")
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.showTypeValue = Store.shared.bool(key: "\(self.title)_showType", defaultValue: self.showTypeValue)
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
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        if !widgets.filter({ $0 == .mini }).isEmpty {
            self.addArrangedSubview(toggleSettingRow(
                title: localizedString("Show GPU type"),
                action: #selector(toggleShowType),
                state: self.showTypeValue
            ))
        }
        
        self.addGPUSelector()
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Notification level"),
            action: #selector(changeNotificationLevel),
            items: notificationLevels,
            selected: self.notificationLevel == "disabled" ? self.notificationLevel : "\(Int((Double(self.notificationLevel) ?? 0)*100))%"
        ))
    }
    
    private func addGPUSelector() {
        let view: NSStackView = NSStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: Constants.Settings.row).isActive = true
        view.orientation = .horizontal
        view.alignment = .centerY
        view.distribution = .fill
        view.spacing = 0
        
        let title: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 17), localizedString("GPU to show"))
        title.font = NSFont.systemFont(ofSize: 13, weight: .light)
        title.textColor = .textColor
        
        let container: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width - 100, height: 26))
        container.yPlacement = .center
        container.xPlacement = .trailing
        let button = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        button.target = self
        button.action = #selector(self.handleSelection)
        self.button = button
        container.addRow(with: [button])
        
        view.addArrangedSubview(title)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(container)
        
        self.addArrangedSubview(view)
    }
    
    internal func setList(_ gpus: GPUs) {
        var list: [KeyValue_t] = [
            KeyValue_t(key: "automatic", value: "Automatic"),
            KeyValue_t(key: "separator", value: "separator")
        ]
        gpus.active().forEach{ list.append(KeyValue_t(key: $0.model, value: $0.model)) }
        
        DispatchQueue.main.async(execute: {
            guard let button = self.button else {
                return
            }
            
            if button.menu?.items.count != list.count {
                let menu = NSMenu()
                
                list.forEach { (item) in
                    if item.key.contains("separator") {
                        menu.addItem(NSMenuItem.separator())
                    } else {
                        let interfaceMenu = NSMenuItem(title: localizedString(item.value), action: nil, keyEquivalent: "")
                        interfaceMenu.representedObject = item.key
                        menu.addItem(interfaceMenu)
                        if self.selectedGPU == item.key {
                            interfaceMenu.state = .on
                        }
                    }
                }
                
                button.menu = menu
                button.sizeToFit()
            }
        })
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
    
    @objc private func handleSelection(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        
        self.selectedGPU = key
        Store.shared.set(key: "\(self.title)_gpu", value: key)
        self.selectedGPUHandler(key)
    }
    
    @objc func toggleShowType(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.showTypeValue = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_showType", value: self.showTypeValue)
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
}
