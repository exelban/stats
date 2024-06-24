//
//  notifications.swift
//  Bluetooth
//
//  Created by Serhiy Mytrovtsiy on 24/06/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class Notifications: NotificationsWrapper {
    private var list: [String: Bool] = [:]
    
    private let emptyView: EmptyView = EmptyView(msg: localizedString("No Bluetooth devices are available"))
    private var section: PreferencesSection = PreferencesSection()
    
    public init(_ module: ModuleType) {
        super.init(module)
        
        self.addArrangedSubview(self.emptyView)
        self.addArrangedSubview(self.section)
        self.section.isHidden = true
        
        self.addArrangedSubview(NSView())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func callback(_ list: [BLEDevice]) {
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
                let btn = selectView(
                    action: #selector(self.changeSensorNotificaion),
                    items: notificationLevels,
                    selected: d.notificationThreshold
                )
                btn.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(d.uuid?.uuidString ?? d.address)")
                section.add(PreferencesRow(d.name, component: btn))
                self.list[d.id] = true
            }
        }
        
        let devices = list.filter({ !$0.notificationThreshold.isEmpty })
        let title = localizedString("Bluetooth threshold")
        
        for d in devices {
            if let threshold = Double(d.notificationThreshold) {
                for l in d.batteryLevel {
                    let subtitle = localizedString("\(localizedString(d.name)): \(l.value)%")
                    if let value = Double(l.value) {
                        self.checkDouble(id: d.id, value: value/100, threshold: threshold, title: title, subtitle: subtitle, less: true)
                    }
                }
            }
        }
    }
    
    @objc private func changeSensorNotificaion(_ sender: NSMenuItem) {
        guard let id = sender.identifier, let key = sender.representedObject as? String else { return }
        Store.shared.set(key: "ble_\(id.rawValue)_notification", value: key)
    }
}
