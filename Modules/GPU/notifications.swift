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
    private let sustainedID: String = "delay10s"
    
    private var usageState: Bool = false
    private var usageLevel: Int = 75
    private var sustainedState: Bool = false
    private let sustainedDuration: TimeInterval = 10
    
    public init(_ module: ModuleType) {
        super.init(module, [self.usageID])
        
        if Store.shared.exist(key: "\(self.module)_notifications_usage") {
            let value = Store.shared.string(key: "\(self.module)_notifications_usage", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_usage_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_usage_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_usage")
            }
        }
        
        self.usageState = Store.shared.bool(key: "\(self.module)_notifications_usage_state", defaultValue: self.usageState)
        self.usageLevel = Store.shared.int(key: "\(self.module)_notifications_usage_value", defaultValue: self.usageLevel)
        self.sustainedState = Store.shared.bool(key: "\(self.module)_notifications_\(self.sustainedID)_state", defaultValue: self.sustainedState)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Usage"), component: PreferencesSwitch(
                action: self.toggleUsage, state: self.usageState,
                with: StepperInput(self.usageLevel, callback: self.changeUsage)
            ))
        ]))
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Delay alerts by 10 seconds"), component: PreferencesSwitch(
                action: self.toggleSustained, state: self.sustainedState
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: Double) {
        let title = localizedString("GPU usage threshold")
        
        if self.usageState {
            let subtitle = localizedString("GPU usage is", "\(Int((value)*100))%")
            self.checkDouble(
                id: self.usageID,
                value: value,
                threshold: Double(self.usageLevel)/100,
                title: title,
                subtitle: subtitle,
                duration: self.sustainedState ? self.sustainedDuration : nil
            )
        }
    }
    
    @objc private func toggleUsage(_ sender: NSControl) {
        self.usageState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_usage_state", value: self.usageState)
    }
    @objc private func changeUsage(_ newValue: Int) {
        self.usageLevel = newValue
        Store.shared.set(key: "\(self.module)_notifications_usage_value", value: self.usageLevel)
    }
    @objc private func toggleSustained(_ sender: NSControl) {
        self.sustainedState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_\(self.sustainedID)_state", value: self.sustainedState)
    }
}
