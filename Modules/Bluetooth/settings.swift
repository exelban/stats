//
//  settings.swift
//  Bluetooth
//
//  Created by Serhiy Mytrovtsiy on 07/07/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    public var callback: (() -> Void) = {}
    
    private var list: [String: Bool] = [:]
    
    private let emptyView: EmptyView = EmptyView(msg: localizedString("No Bluetooth devices are available"))
    private var section: PreferencesSection = PreferencesSection()
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.spacing = Constants.Settings.margin
        
        self.addArrangedSubview(self.emptyView)
        self.addArrangedSubview(self.section)
        self.section.isHidden = true
        
        self.addArrangedSubview(NSView())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func load(widgets: [widget_t]) {}
    
    internal func setList(_ list: [BLEDevice]) {
        if self.list.count != list.count && !self.list.isEmpty {
            self.section.removeFromSuperview()
            self.section = PreferencesSection()
            self.addArrangedSubview(self.section)
            self.list = [:]
        }
        
        if list.isEmpty && self.emptyView.isHidden {
            self.emptyView.isHidden = false
            self.section.isHidden = true
            return
        } else if !list.isEmpty && !self.emptyView.isHidden {
            self.emptyView.isHidden = true
            self.section.isHidden = false
        }
        
        list.forEach { (d: BLEDevice) in
            if self.list[d.id] == nil {
                let btn = switchView(
                    action: #selector(self.handleSelection),
                    state: d.state
                )
                btn.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(d.uuid?.uuidString ?? d.address)")
                section.add(PreferencesRow(d.name, component: btn))
                self.list[d.id] = true
            }
        }
    }
    
    @objc private func handleSelection(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        let value = controlState(sender)
        Store.shared.set(key: "ble_\(id.rawValue)", value: value)
        self.callback()
    }
}
