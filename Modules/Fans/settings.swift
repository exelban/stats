//
//  settings.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 20/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 1
    private var labelState: Bool = false
    private var speedState: Bool = false
    
    private let title: String
    private var button: NSPopUpButton?
    private let list: UnsafeMutablePointer<[Fan]>
    
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ title: String, list: UnsafeMutablePointer<[Fan]>) {
        self.title = title
        self.list = list
        
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
        
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.labelState = Store.shared.bool(key: "\(self.title)_label", defaultValue: self.labelState)
        self.speedState = Store.shared.bool(key: "\(self.title)_speed", defaultValue: self.labelState)
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
        
        self.addArrangedSubview(toggleSettingRow(
            title: localizedString("Label"),
            action: #selector(toggleLabelState),
            state: self.labelState
        ))
        
        self.addArrangedSubview(toggleSettingRow(
            title: localizedString("Save the fan speed"),
            action: #selector(toggleSpeedState),
            state: self.speedState
        ))
        
        let header = NSStackView()
        header.heightAnchor.constraint(equalToConstant: Constants.Settings.row).isActive = true
        header.spacing = 0
        
        let titleField: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0), localizedString("Fans"))
        titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = .labelColor
        
        header.addArrangedSubview(titleField)
        header.addArrangedSubview(NSView())
        
        self.addArrangedSubview(header)
        
        let container = NSStackView()
        container.orientation = .vertical
        container.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Settings.margin,
            bottom: 0,
            right: Constants.Settings.margin
        )
        container.spacing = 0
        
        self.list.pointee.forEach { (f: Fan) in
            let row: NSView = toggleSettingRow(
                title: f.name,
                action: #selector(self.handleSelection),
                state: f.state
            )
            row.subviews.filter{ $0 is NSControl }.forEach { (control: NSView) in
                control.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(f.id)")
            }
            container.addArrangedSubview(row)
        }
        
        self.addArrangedSubview(container)
    }
    
    @objc private func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        Store.shared.set(key: "fan_\(id.rawValue)", value: state! == NSControl.StateValue.on)
        self.callback()
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
    
    @objc private func toggleLabelState(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.labelState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_label", value: self.labelState)
        self.callback()
    }
    
    @objc private func toggleSpeedState(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.speedState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_speed", value: self.speedState)
        self.callback()
    }
}
