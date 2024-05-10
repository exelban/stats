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
    
    private var utilizationState: Bool = false
    private var utilization: Int = 80
    
    public init(_ module: ModuleType) {
        super.init(module, [self.utilizationID])
        
        if Store.shared.exist(key: "\(self.module)_notificationLevel") {
            let value = Store.shared.string(key: "\(self.module)_notifications_free", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_utilization_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_utilization_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notificationLevel")
            }
        }
        
        self.utilizationState = Store.shared.bool(key: "\(self.module)_notifications_utilization_state", defaultValue: self.utilizationState)
        self.utilization = Store.shared.int(key: "\(self.module)_notifications_utilization_value", defaultValue: self.utilization)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Usage"), component: PreferencesSwitch(
                action: self.toggleUtilization, state: self.utilizationState, with: StepperInput(self.utilization, callback: self.changeUtilization)
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func utilizationCallback(_ value: Double) {
        let title = localizedString("Disk utilization threshold")
        
        if self.utilizationState {
            let subtitle = localizedString("Disk utilization is", "\(Int((value)*100))%")
            self.checkDouble(id: self.utilizationID, value: value, threshold: Double(self.utilization)/100, title: title, subtitle: subtitle)
        }
    }
    
    @objc private func toggleUtilization(_ sender: NSControl) {
        self.utilizationState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_utilization_state", value: self.utilizationState)
    }
    @objc private func changeUtilization(_ newValue: Int) {
        self.utilization = newValue
        Store.shared.set(key: "\(self.module)_notifications_utilization_value", value: self.utilization)
    }
}
