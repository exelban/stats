//
//  settings.swift
//  Ports
//
//  Created by Dogukan Akin on 05/10/2025.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: SettingsWrapper {
    private var updateIntervalValue: Int = 3
    
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    public init(_ module: ModuleType) {
        self.updateIntervalValue = Store.shared.int(key: "\(module.rawValue)_updateInterval", defaultValue: self.updateIntervalValue)
        
        super.init(module, frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 2) + Constants.Settings.margin
        
        self.addSubview(selectSettingsRowV1(
            title: localizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        self.addSubview(selectSettingsRowV1(
            title: localizedString("Widget"),
            action: #selector(toggleWidget),
            items: widgets.map{ $0.rawValue },
            selected: widgets.first{ $0.isActive }?.rawValue ?? ""
        ))
        
        self.setFrameSize(NSSize(width: self.frame.width, height: height))
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            Store.shared.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
    
    @objc private func toggleWidget(_ sender: NSMenuItem) {
        guard let widget = widget_t.fromString(sender.title) else { return }
        self.toggleWidget(widget)
    }
}
