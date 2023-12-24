//
//  notifications.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 17/12/2023
//  Using Swift 5.0
//  Running on macOS 14.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class Notifications: NotificationsWrapper {
    private let lowID: String = "low"
    private let highID: String = "high"
    private var lowLevel: String = ""
    private var highLevel: String = ""
    
    public init(_ module: ModuleType) {
        super.init(module, [self.lowID, self.highID])
        
        if Store.shared.exist(key: "\(self.module)_lowLevelNotification") {
            let value = Store.shared.string(key: "\(self.module)_lowLevelNotification", defaultValue: self.lowID)
            Store.shared.set(key: "\(self.module)_notifications_low", value: value)
            Store.shared.remove("\(self.module)_lowLevelNotification")
        }
        if Store.shared.exist(key: "\(self.module)_highLevelNotification") {
            let value = Store.shared.string(key: "\(self.module)_highLevelNotification", defaultValue: self.highLevel)
            Store.shared.set(key: "\(self.module)_notifications_high", value: value)
            Store.shared.remove("\(self.module)_highLevelNotification")
        }
        
        self.lowLevel = Store.shared.string(key: "\(self.module)_notifications_low", defaultValue: self.lowLevel)
        self.highLevel = Store.shared.string(key: "\(self.module)_notifications_high", defaultValue: self.highLevel)
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Low level notification"),
            action: #selector(self.changeLowLevel),
            items: notificationLevels,
            selected: self.lowLevel
        ))
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("High level notification"),
            action: #selector(self.changeHighLevel),
            items: notificationLevels,
            selected: self.highLevel
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: Battery_Usage) {
        if value.isCharging || !value.isBatteryPowered {
            self.hideNotification(self.lowID)
        }
        if let threshold = Double(self.lowLevel), !value.isCharging {
            let title = localizedString("Low battery")
            var subtitle = localizedString("Battery remaining", "\(Int(value.level*100))")
            if value.timeToEmpty > 0 {
                subtitle += " (\(Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()))"
            }
            self.checkDouble(id: self.lowID, value: value.level, threshold: threshold, title: title, subtitle: subtitle, less: true)
        }
        
        if value.isBatteryPowered {
            self.hideNotification(self.highID)
        }
        if let threshold = Double(self.highLevel), value.isCharging {
            let title = localizedString("High battery")
            var subtitle = localizedString("Battery remaining to full charge", "\(Int((1-value.level)*100))")
            if value.timeToCharge > 0 {
                subtitle += " (\(Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds()))"
            }
            self.checkDouble(id: self.lowID, value: value.level, threshold: threshold, title: title, subtitle: subtitle)
        }
    }
    
    @objc private func changeLowLevel(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.lowLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_low", value: self.lowLevel)
    }
    
    @objc private func changeHighLevel(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.highLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_high", value: self.highLevel)
    }
}
