//
//  notifications.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 04/12/2023
//  Using Swift 5.0
//  Running on macOS 14.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class Notifications: NotificationsWrapper {
    private let totalLoadID: String = "totalUsage"
    private let systemLoadID: String = "systemUsage"
    private let userLoadID: String = "userUsage"
    private let eCoresLoadID: String = "eCoresUsage"
    private let pCoresLoadID: String = "pCoresUsage"
    
    private var totalLoadLevel: String = ""
    private var systemLoadLevel: String = ""
    private var userLoadLevel: String = ""
    private var eCoresLoadLevel: String = ""
    private var pCoresLoadLevel: String = ""
    
    public init(_ module: ModuleType) {
        super.init(module, [self.totalLoadID, self.systemLoadID, self.userLoadID, self.eCoresLoadID, self.pCoresLoadID])
        
        if Store.shared.exist(key: "\(self.module)_notificationLevel") {
            let value = Store.shared.string(key: "\(self.module)_notificationLevel", defaultValue: self.totalLoadLevel)
            Store.shared.set(key: "\(self.module)_notifications_totalLoad", value: value)
            Store.shared.remove("\(self.module)_notificationLevel")
        }
        
        self.totalLoadLevel = Store.shared.string(key: "\(self.module)_notifications_totalLoad", defaultValue: self.totalLoadLevel)
        self.systemLoadLevel = Store.shared.string(key: "\(self.module)_notifications_systemLoad", defaultValue: self.systemLoadLevel)
        self.userLoadLevel = Store.shared.string(key: "\(self.module)_notifications_userLoad", defaultValue: self.userLoadLevel)
        self.eCoresLoadLevel = Store.shared.string(key: "\(self.module)_notifications_eCoresLoad", defaultValue: self.eCoresLoadLevel)
        self.pCoresLoadLevel = Store.shared.string(key: "\(self.module)_notifications_pCoresLoad", defaultValue: self.pCoresLoadLevel)
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Total load"),
            action: #selector(self.changeTotalLoad),
            items: notificationLevels,
            selected: self.totalLoadLevel
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("System load"),
            action: #selector(self.changeSystemLoad),
            items: notificationLevels,
            selected: self.systemLoadLevel
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("User load"),
            action: #selector(self.changeUserLoad),
            items: notificationLevels,
            selected: self.userLoadLevel
        ))
        
        #if arch(arm64)
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Efficiency cores load"),
            action: #selector(self.changeECoresLoad),
            items: notificationLevels,
            selected: self.eCoresLoadLevel
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Performance cores load"),
            action: #selector(self.changePCoresLoad),
            items: notificationLevels,
            selected: self.pCoresLoadLevel
        ))
        #endif
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func loadCallback(_ value: CPU_Load) {
        let title = localizedString("CPU usage threshold")
        
        if let threshold = Double(self.totalLoadLevel) {
            let subtitle = localizedString("Total usage is", "\(Int((value.totalUsage)*100))%")
            self.checkDouble(id: self.totalLoadID, value: value.totalUsage, threshold: threshold, title: title, subtitle: subtitle)
        }
        
        if let threshold = Double(self.systemLoadLevel) {
            let subtitle = localizedString("System usage is", "\(Int((value.systemLoad)*100))%")
            self.checkDouble(id: self.systemLoadID, value: value.systemLoad, threshold: threshold, title: title, subtitle: subtitle)
        }
        
        if let threshold = Double(self.userLoadLevel) {
            let subtitle = localizedString("User usage is", "\(Int((value.systemLoad)*100))%")
            self.checkDouble(id: self.userLoadID, value: value.userLoad, threshold: threshold, title: title, subtitle: subtitle)
        }
        
        if let threshold = Double(self.eCoresLoadLevel), let usage = value.usageECores {
            let subtitle = localizedString("Efficiency cores usage is", "\(Int((value.systemLoad)*100))%")
            self.checkDouble(id: self.eCoresLoadID, value: usage, threshold: threshold, title: title, subtitle: subtitle)
        }
        
        if let threshold = Double(self.pCoresLoadLevel), let usage = value.usagePCores {
            let subtitle = localizedString("Performance cores usage is", "\(Int((value.systemLoad)*100))%")
            self.checkDouble(id: self.pCoresLoadID, value: usage, threshold: threshold, title: title, subtitle: subtitle)
        }
    }
    
    // MARK: - change helpers
    
    @objc private func changeTotalLoad(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.totalLoadLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_totalLoad", value: self.totalLoadLevel)
    }
    
    @objc private func changeSystemLoad(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.systemLoadLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_systemLoad", value: self.systemLoadLevel)
    }
    
    @objc private func changeUserLoad(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.userLoadLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_userLoad", value: self.userLoadLevel)
    }
    
    @objc private func changeECoresLoad(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.eCoresLoadLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_eCoresLoad", value: self.eCoresLoadLevel)
    }
    
    @objc private func changePCoresLoad(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.pCoresLoadLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_pCoresLoad", value: self.pCoresLoadLevel)
    }
}
