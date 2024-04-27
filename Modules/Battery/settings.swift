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
import Kit
import SystemConfiguration

internal class Settings: NSStackView, Settings_v {
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    
    private let title: String
    private var button: NSPopUpButton?
    
    private var numberOfProcesses: Int = 8
    private var timeFormat: String = "short"
    
    public init(_ module: ModuleType) {
        self.title = module.rawValue
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.timeFormat = Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
        
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
            PreferencesRow(localizedString("Number of top processes"), component: selectView(
                action: #selector(self.changeNumberOfProcesses),
                items: NumbersOfProcesses.map{ KeyValue_t(key: "\($0)", value: "\($0)") },
                selected: "\(self.numberOfProcesses)"
            ))
        ]))
        
        if !widgets.filter({ $0 == .battery }).isEmpty {
            self.addArrangedSubview(PreferencesSection([
                PreferencesRow(localizedString("Time format"), component: selectView(
                    action: #selector(toggleTimeFormat),
                    items: ShortLong,
                    selected: self.timeFormat
                ))
            ]))
        }
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    @objc private func toggleTimeFormat(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.timeFormat = key
        Store.shared.set(key: "\(self.title)_timeFormat", value: key)
        self.callback()
    }
}
