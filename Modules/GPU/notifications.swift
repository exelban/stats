//
//  notifications.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 05/12/2023
//  Using Swift 5.0
//  Running on macOS 14.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class Notifications: NotificationsWrapper {
    private let usageID: String = "usage"
    private var usageLevel: String = ""
    
    public init(_ module: ModuleType) {
        super.init(module, [self.usageID])
        
        if Store.shared.exist(key: "\(self.module)_notificationLevel") {
            let value = Store.shared.string(key: "\(self.module)_notificationLevel", defaultValue: self.usageLevel)
            Store.shared.set(key: "\(self.module)_notifications_usage", value: value)
            Store.shared.remove("\(self.module)_notificationLevel")
        }
        
        self.usageLevel = Store.shared.string(key: "\(self.module)_notifications_usage", defaultValue: self.usageLevel)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Usage"), component: selectView(
                action: #selector(self.changeUsage),
                items: notificationLevels,
                selected: self.usageLevel
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: Double) {
        let title = localizedString("GPU usage threshold")
        
        if let threshold = Double(self.usageLevel) {
            let subtitle = localizedString("GPU usage is", "\(Int((value)*100))%")
            self.checkDouble(id: self.usageID, value: value, threshold: threshold, title: title, subtitle: subtitle)
        }
    }
    
    @objc private func changeUsage(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.usageLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_usage", value: self.usageLevel)
    }
}
