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
import StatsKit
import ModuleKit
import SystemConfiguration

internal class Settings: NSView, Settings_v {
    public var callback: (() -> Void) = {}
    
    private let title: String
    private let store: UnsafePointer<Store>
    private var button: NSPopUpButton?
    
    private let levelsList: [String] = ["Disabled", "0.03", "0.05", "0.1", "0.15", "0.2", "0.25", "0.3", "0.4", "0.5"]
    private var lowLevelNotification: String {
        get {
            return self.store.pointee.string(key: "\(self.title)_lowLevelNotification", defaultValue: "0.15")
        }
    }
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        
        super.init(frame: CGRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: Constants.Settings.width - (Constants.Settings.margin*2), height: 0))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widget: widget_t) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        
        let levels: [String] = self.levelsList.map { (v: String) -> String in
            if let level = Double(v) {
                return "\(Int(level*100))%"
            }
            return v
        }
        
        self.addSubview(SelectTitleRow(
            frame: NSRect(
                x:Constants.Settings.margin,
                y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * 0,
                width: self.frame.width - (Constants.Settings.margin*2),
                height: rowHeight
            ),
            title: "Low level notification",
            action: #selector(changeUpdateInterval),
            items: levels,
            selected: self.lowLevelNotification == "Disabled" ? self.lowLevelNotification : "\(Int((Double(self.lowLevelNotification) ?? 0)*100))%"
        ))
        
        self.setFrameSize(NSSize(width: self.frame.width, height: 30 + (Constants.Settings.margin*2)))
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        if sender.title == "Disabled" {
            store.pointee.set(key: "\(self.title)_lowLevelNotification", value: sender.title)
        } else if let value = Double(sender.title.replacingOccurrences(of: "%", with: "")) {
            store.pointee.set(key: "\(self.title)_lowLevelNotification", value: "\(value/100)")
        }
    }
}
