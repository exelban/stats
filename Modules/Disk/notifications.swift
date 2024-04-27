//
//  notifications.swift
//  Disk
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
    private let utilizationID: String = "usage"
    private var utilizationLevel: String = ""
    
    public init(_ module: ModuleType) {
        super.init(module, [self.utilizationID])
        
        if Store.shared.exist(key: "\(self.module)_notificationLevel") {
            let value = Store.shared.string(key: "\(self.module)_notificationLevel", defaultValue: self.utilizationLevel)
            Store.shared.set(key: "\(self.module)_notifications_utilization", value: value)
            Store.shared.remove("\(self.module)_notificationLevel")
        }
        
        self.utilizationLevel = Store.shared.string(key: "\(self.module)_notifications_utilization", defaultValue: self.utilizationLevel)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Usage"), component: selectView(
                action: #selector(self.changeUsage),
                items: notificationLevels,
                selected: self.utilizationLevel
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func utilizationCallback(_ value: Double) {
        let title = localizedString("Disk utilization threshold")
        
        if let threshold = Double(self.utilizationLevel) {
            let subtitle = localizedString("Disk utilization is", "\(Int((value)*100))%")
            self.checkDouble(id: self.utilizationID, value: value, threshold: threshold, title: title, subtitle: subtitle)
        }
    }
    
    @objc private func changeUsage(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.utilizationLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_utilization", value: self.utilizationLevel)
    }
}
