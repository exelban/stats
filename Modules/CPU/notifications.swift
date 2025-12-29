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
    private let sustainedID: String = "delay10s"
    
    private var totalLoadState: Bool = false
    private var systemLoadState: Bool = false
    private var userLoadState: Bool = false
    private var eCoresLoadState: Bool = false
    private var pCoresLoadState: Bool = false
    private var sustainedState: Bool = false
    
    private var totalLoad: Int = 75
    private var systemLoad: Int = 75
    private var userLoad: Int = 75
    private var eCoresLoad: Int = 75
    private var pCoresLoad: Int = 75
    private let sustainedDuration: TimeInterval = 10
    
    public init(_ module: ModuleType) {
        super.init(module, [self.totalLoadID, self.systemLoadID, self.userLoadID, self.eCoresLoadID, self.pCoresLoadID])
        
        if Store.shared.exist(key: "\(self.module)_notifications_totalLoad") {
            let value = Store.shared.string(key: "\(self.module)_notifications_totalLoad", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_totalLoad_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_totalLoad_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_totalLoad")
            }
        }
        if Store.shared.exist(key: "\(self.module)_notifications_systemLoad") {
            let value = Store.shared.string(key: "\(self.module)_notifications_systemLoad", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_systemLoad_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_systemLoad_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_systemLoad")
            }
        }
        if Store.shared.exist(key: "\(self.module)_notifications_userLoad") {
            let value = Store.shared.string(key: "\(self.module)_notifications_userLoad", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_userLoad_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_userLoad_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_userLoad")
            }
        }
        
        if Store.shared.exist(key: "\(self.module)_notifications_eCoresLoad") {
            let value = Store.shared.string(key: "\(self.module)_notifications_eCoresLoad", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_eCoresLoad_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_eCoresLoad_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_eCoresLoad")
            }
        }
        if Store.shared.exist(key: "\(self.module)_notifications_pCoresLoad") {
            let value = Store.shared.string(key: "\(self.module)_notifications_pCoresLoad", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_pCoresLoad_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_pCoresLoad_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_pCoresLoad")
            }
        }
        
        self.totalLoadState = Store.shared.bool(key: "\(self.module)_notifications_totalLoad_state", defaultValue: self.totalLoadState)
        self.totalLoad = Store.shared.int(key: "\(self.module)_notifications_totalLoad_value", defaultValue: self.totalLoad)
        self.systemLoadState = Store.shared.bool(key: "\(self.module)_notifications_systemLoad_state", defaultValue: self.systemLoadState)
        self.systemLoad = Store.shared.int(key: "\(self.module)_notifications_systemLoad_value", defaultValue: self.systemLoad)
        self.userLoadState = Store.shared.bool(key: "\(self.module)_notifications_userLoad_state", defaultValue: self.userLoadState)
        self.userLoad = Store.shared.int(key: "\(self.module)_notifications_userLoad_value", defaultValue: self.userLoad)
        
        self.eCoresLoadState = Store.shared.bool(key: "\(self.module)_notifications_eCoresLoad_state", defaultValue: self.eCoresLoadState)
        self.eCoresLoad = Store.shared.int(key: "\(self.module)_notifications_eCoresLoad_value", defaultValue: self.eCoresLoad)
        self.pCoresLoadState = Store.shared.bool(key: "\(self.module)_notifications_pCoresLoad_state", defaultValue: self.pCoresLoadState)
        self.pCoresLoad = Store.shared.int(key: "\(self.module)_notifications_pCoresLoad_value", defaultValue: self.pCoresLoad)
        self.sustainedState = Store.shared.bool(key: "\(self.module)_notifications_\(self.sustainedID)_state", defaultValue: self.sustainedState)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Total load"), component: PreferencesSwitch(
                action: self.toggleTotalLoad, state: self.totalLoadState,
                with: StepperInput(self.totalLoad, callback: self.changeTotalLoad)
            )),
            PreferencesRow(localizedString("System load"), component: PreferencesSwitch(
                action: self.toggleSystemLoad, state: self.systemLoadState,
                with: StepperInput(self.systemLoad, callback: self.changeSystemLoad)
            )),
            PreferencesRow(localizedString("User load"), component: PreferencesSwitch(
                action: self.toggleUserLoad, state: self.userLoadState,
                with: StepperInput(self.userLoad, callback: self.changeUserLoad)
            ))
        ]))
        
        #if arch(arm64)
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Efficiency cores load"), component: PreferencesSwitch(
                action: self.toggleECoresLoad, state: self.eCoresLoadState,
                with: StepperInput(self.eCoresLoad, callback: self.changeECoresLoad)
            )),
            PreferencesRow(localizedString("Performance cores load"), component: PreferencesSwitch(
                action: self.togglePCoresLoad, state: self.pCoresLoadState,
                with: StepperInput(self.pCoresLoad, callback: self.changePCoresLoad)
            ))
        ]))
        #endif

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Delay alerts by 10 seconds"), component: PreferencesSwitch(
                action: self.toggleSustained, state: self.sustainedState
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func loadCallback(_ value: CPU_Load) {
        let title = localizedString("CPU usage threshold")
        
        if self.totalLoadState {
            let subtitle = "\(localizedString("Total load")): \(Int((value.totalUsage)*100))%"
            self.checkDouble(
                id: self.totalLoadID,
                value: value.totalUsage,
                threshold: Double(self.totalLoad)/100,
                title: title,
                subtitle: subtitle,
                duration: self.sustainedState ? self.sustainedDuration : nil
            )
        }
        
        if self.systemLoadState {
            let subtitle = "\(localizedString("System load")): \(Int((value.systemLoad)*100))%"
            self.checkDouble(
                id: self.systemLoadID,
                value: value.systemLoad,
                threshold: Double(self.systemLoad)/100,
                title: title,
                subtitle: subtitle,
                duration: self.sustainedState ? self.sustainedDuration : nil
            )
        }
        
        if self.userLoadState {
            let subtitle = "\(localizedString("User load")): \(Int((value.userLoad)*100))%"
            self.checkDouble(
                id: self.userLoadID,
                value: value.userLoad,
                threshold: Double(self.userLoad)/100,
                title: title,
                subtitle: subtitle,
                duration: self.sustainedState ? self.sustainedDuration : nil
            )
        }
        
        if self.eCoresLoadState, let usage = value.usageECores {
            let subtitle = "\(localizedString("Efficiency cores load")): \(Int((usage)*100))%"
            self.checkDouble(
                id: self.eCoresLoadID,
                value: usage,
                threshold: Double(self.eCoresLoad)/100,
                title: title,
                subtitle: subtitle,
                duration: self.sustainedState ? self.sustainedDuration : nil
            )
        }
        
        if self.pCoresLoadState, let usage = value.usagePCores {
            let subtitle = "\(localizedString("Performance cores load")): \(Int((usage)*100))%"
            self.checkDouble(
                id: self.pCoresLoadID,
                value: usage,
                threshold: Double(self.pCoresLoad)/100,
                title: title,
                subtitle: subtitle,
                duration: self.sustainedState ? self.sustainedDuration : nil
            )
        }
    }
    
    // MARK: - change helpers
    
    @objc private func toggleTotalLoad(_ sender: NSControl) {
        self.totalLoadState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_totalLoad_state", value: self.totalLoadState)
    }
    @objc private func changeTotalLoad(_ newValue: Int) {
        self.totalLoad = newValue
        Store.shared.set(key: "\(self.module)_notifications_totalLoad_value", value: self.totalLoad)
    }
    
    @objc private func toggleSystemLoad(_ sender: NSControl) {
        self.systemLoadState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_systemLoad_state", value: self.systemLoadState)
    }
    @objc private func changeSystemLoad(_ newValue: Int) {
        self.systemLoad = newValue
        Store.shared.set(key: "\(self.module)_notifications_systemLoad_value", value: self.systemLoad)
    }
    
    @objc private func toggleUserLoad(_ sender: NSControl) {
        self.userLoadState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_userLoad_state", value: self.userLoadState)
    }
    @objc private func changeUserLoad(_ newValue: Int) {
        self.userLoad = newValue
        Store.shared.set(key: "\(self.module)_notifications_userLoad_value", value: self.userLoad)
    }
    
    @objc private func toggleECoresLoad(_ sender: NSControl) {
        self.eCoresLoadState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_eCoresLoad_state", value: self.eCoresLoadState)
    }
    @objc private func changeECoresLoad(_ newValue: Int) {
        self.eCoresLoad = newValue
        Store.shared.set(key: "\(self.module)_notifications_eCoresLoad_value", value: self.eCoresLoad)
    }
    
    @objc private func togglePCoresLoad(_ sender: NSControl) {
        self.pCoresLoadState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_pCoresLoad_state", value: self.pCoresLoadState)
    }
    @objc private func changePCoresLoad(_ newValue: Int) {
        self.pCoresLoad = newValue
        Store.shared.set(key: "\(self.module)_notifications_pCoresLoad_value", value: self.pCoresLoad)
    }
    
    @objc private func toggleSustained(_ sender: NSControl) {
        self.sustainedState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_\(self.sustainedID)_state", value: self.sustainedState)
    }
}
