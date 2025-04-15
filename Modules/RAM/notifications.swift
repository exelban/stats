//
//  notifications.swift
//  RAM
//
//  Created by Serhiy Mytrovtsiy on 05/12/2023
//  Using Swift 5.0
//  Running on macOS 14.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal let memoryPressureLevels: [KeyValue_t] = [
    KeyValue_t(key: "warning", value: "Warning", additional: DispatchSource.MemoryPressureEvent.warning),
    KeyValue_t(key: "critical", value: "Critical", additional: DispatchSource.MemoryPressureEvent.critical)
]

class Notifications: NotificationsWrapper {
    private let totalID: String = "totalUsage"
    private let freeID: String = "free"
    private let pressureID: String = "pressure"
    private let swapID: String = "swap"
    
    private var totalState: Bool = false
    private var freeState: Bool = false
    private var pressureState: Bool = false
    private var swapState: Bool = false
    
    private var total: Int = 75
    private var free: Int = 75
    private var pressure: String = ""
    private var swap: Int = 1
    private var swapUnit: SizeUnit = .GB
    
    public init(_ module: ModuleType) {
        super.init(module, [self.totalID, self.freeID, self.pressureID, self.swapID])
        
        if Store.shared.exist(key: "\(self.module)_notifications_totalUsage") {
            let value = Store.shared.string(key: "\(self.module)_notifications_totalUsage", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_total_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_total_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_totalUsage")
            }
        }
        if Store.shared.exist(key: "\(self.module)_notifications_free") {
            let value = Store.shared.string(key: "\(self.module)_notifications_free", defaultValue: "")
            if let v = Double(value) {
                Store.shared.set(key: "\(self.module)_notifications_free_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_free_value", value: Int(v*100))
                Store.shared.remove("\(self.module)_notifications_free")
            }
        }
        if Store.shared.exist(key: "\(self.module)_notifications_pressure") {
            let value = Store.shared.string(key: "\(self.module)_notifications_pressure", defaultValue: "")
            if value != "" {
                Store.shared.set(key: "\(self.module)_notifications_pressure_state", value: true)
                Store.shared.set(key: "\(self.module)_notifications_pressure_value", value: value)
                Store.shared.remove("\(self.module)_notifications_pressure")
            }
        }
        if Store.shared.exist(key: "\(self.module)_notifications_swap") {
            let value = Store.shared.string(key: "\(self.module)_notifications_swap", defaultValue: "")
            if value != ""  {
                Store.shared.set(key: "\(self.module)_notifications_swap_state", value: true)
                Store.shared.remove("\(self.module)_notifications_swap")
            }
        }
        
        self.totalState = Store.shared.bool(key: "\(self.module)_notifications_total_state", defaultValue: self.totalState)
        self.total = Store.shared.int(key: "\(self.module)_notifications_total_value", defaultValue: self.total)
        self.freeState = Store.shared.bool(key: "\(self.module)_notifications_free_state", defaultValue: self.freeState)
        self.free = Store.shared.int(key: "\(self.module)_notifications_free_value", defaultValue: self.free)
        self.pressureState = Store.shared.bool(key: "\(self.module)_notifications_pressure_state", defaultValue: self.pressureState)
        self.pressure = Store.shared.string(key: "\(self.module)_notifications_pressure_value", defaultValue: self.pressure)
        self.swapState = Store.shared.bool(key: "\(self.module)_notifications_swap_state", defaultValue: self.swapState)
        self.swap = Store.shared.int(key: "\(self.module)_notifications_swap_value", defaultValue: self.swap)
        self.swapUnit = SizeUnit.fromString(Store.shared.string(key: "\(self.module)_notifications_swap_unit", defaultValue: self.swapUnit.key))
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Usage"), component: PreferencesSwitch(
                action: self.toggleTotal, state: self.totalState, with: StepperInput(self.total, callback: self.changeTotal)
            )),
            PreferencesRow(localizedString("Free memory (less than)"), component: PreferencesSwitch(
                action: self.toggleFree, state: self.freeState, with: StepperInput(self.free, callback: self.changeFree)
            ))
        ]))
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Memory pressure"), component: PreferencesSwitch(
                action: self.togglePressure, state: self.pressureState,
                with: selectView(action: #selector(self.changePressure), items: memoryPressureLevels, selected: self.pressure)
            ))
        ]))
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Swap size"), component: PreferencesSwitch(
                action: self.toggleSwap, state: self.swapState, with: StepperInput(
                    self.swap, range: NSRange(location: 1, length: 1023), unit: self.swapUnit.key, units: SizeUnit.allCases, 
                    callback: self.changeSwap, unitCallback: self.changeSwapUnit
                )
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func loadCallback(_ value: RAM_Usage) {
        let title = localizedString("RAM utilization threshold")
        
        if self.totalState {
            let subtitle = localizedString("RAM utilization is", "\(Int((value.usage)*100))%")
            self.checkDouble(id: self.totalID, value: value.usage, threshold: Double(self.total)/100, title: title, subtitle: subtitle)
        }
        if self.freeState {
            let free = value.free / value.total
            let subtitle = localizedString("Free RAM is", "\(Int((free)*100))%")
            self.checkDouble(id: self.freeID, value: free, threshold: Double(self.free)/100, title: title, subtitle: subtitle, less: true)
        }
        
        if self.pressureState, self.pressure != "", let thresholdPair = memoryPressureLevels.first(where: {$0.key == self.pressure}) {
            if let threshold = thresholdPair.additional as? DispatchSource.MemoryPressureEvent {
                self.checkDouble(
                    id: self.pressureID,
                    value: Double(value.pressure.level),
                    threshold: Double(threshold.rawValue),
                    title: title,
                    subtitle: "\(localizedString("Memory pressure")): \(localizedString(thresholdPair.value))"
                )
            }
        }
        
        if self.swapState {
            let value = Units(bytes: Int64(value.swap.used))
            let subtitle = "\(localizedString("Swap size")): \(value.getReadableMemory())"
            self.checkDouble(id: self.swapID, value: value.toUnit(self.swapUnit), threshold: Double(self.swap), title: title, subtitle: subtitle)
        }
    }
    
    @objc private func toggleTotal(_ sender: NSControl) {
        self.totalState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_total_state", value: self.totalState)
    }
    @objc private func changeTotal(_ newValue: Int) {
        self.total = newValue
        Store.shared.set(key: "\(self.module)_notifications_total_value", value: self.total)
    }
    
    @objc private func toggleFree(_ sender: NSControl) {
        self.freeState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_free_state", value: self.freeState)
    }
    @objc private func changeFree(_ newValue: Int) {
        self.free = newValue
        Store.shared.set(key: "\(self.module)_notifications_free_value", value: self.free)
    }
    
    @objc private func togglePressure(_ sender: NSControl) {
        self.pressureState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_pressure_state", value: self.pressureState)
    }
    @objc private func changePressure(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.pressure = key
        Store.shared.set(key: "\(self.module)_notifications_pressure_value", value: self.pressure)
    }
    
    @objc private func toggleSwap(_ sender: NSControl) {
        self.swapState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_swap_state", value: self.swapState)
    }
    @objc private func changeSwap(_ newValue: Int) {
        self.swap = newValue
        Store.shared.set(key: "\(self.module)_notifications_swap_value", value: self.swap)
    }
    private func changeSwapUnit(_ newValue: KeyValue_p) {
        guard let newUnit = newValue as? SizeUnit else { return }
        self.swapUnit = newUnit
        Store.shared.set(key: "\(self.module)_notifications_swap_unit", value: self.swapUnit.key)
    }
}
