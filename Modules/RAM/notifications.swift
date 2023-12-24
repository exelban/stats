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
    KeyValue_t(key: "", value: "Disabled"),
    KeyValue_t(key: "warning", value: "Warning", additional: DispatchSource.MemoryPressureEvent.warning),
    KeyValue_t(key: "critical", value: "Critical", additional: DispatchSource.MemoryPressureEvent.critical)
]

internal let swapSizes: [KeyValue_t] = [
    KeyValue_t(key: "", value: "Disabled"),
    KeyValue_t(key: "512", value: "0.5 GB"),
    KeyValue_t(key: "1024", value: "1.0 GB"),
    KeyValue_t(key: "1536", value: "1.5 GB"),
    KeyValue_t(key: "2048", value: "2.0 GB"),
    KeyValue_t(key: "2560", value: "2.5 GB"),
    KeyValue_t(key: "5120", value: "5.0 GB"),
    KeyValue_t(key: "7680", value: "7.5 GB"),
    KeyValue_t(key: "10240", value: "10 GB"),
    KeyValue_t(key: "16384", value: "16 GB")
]

class Notifications: NotificationsWrapper {
    private let totalUsageID: String = "totalUsage"
    private let freeID: String = "free"
    private let pressureID: String = "pressure"
    private let swapID: String = "swap"
    
    private var totalUsageLevel: String = ""
    private var freeLevel: String = ""
    private var pressureLevel: String = ""
    private var swapSize: String = ""
    
    public init(_ module: ModuleType) {
        super.init(module, [self.totalUsageID, self.freeID, self.pressureID, self.swapID])
        
        if Store.shared.exist(key: "\(self.module)_notificationLevel") {
            let value = Store.shared.string(key: "\(self.module)_notificationLevel", defaultValue: self.totalUsageLevel)
            Store.shared.set(key: "\(self.module)_notifications_totalUsage", value: value)
            Store.shared.remove("\(self.module)_notificationLevel")
        }
        
        self.totalUsageLevel = Store.shared.string(key: "\(self.module)_notifications_totalUsage", defaultValue: self.totalUsageLevel)
        self.freeLevel = Store.shared.string(key: "\(self.module)_notifications_free", defaultValue: self.freeLevel)
        self.pressureLevel = Store.shared.string(key: "\(self.module)_notifications_pressure", defaultValue: self.pressureLevel)
        self.swapSize = Store.shared.string(key: "\(self.module)_notifications_swap", defaultValue: self.swapSize)
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Usage"),
            action: #selector(self.changeTotalUsage),
            items: notificationLevels,
            selected: self.totalUsageLevel
        ))
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Free memory (less than)"),
            action: #selector(self.changeFree),
            items: notificationLevels,
            selected: self.freeLevel
        ))
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Memory pressure"),
            action: #selector(self.changePressure),
            items: memoryPressureLevels,
            selected: self.pressureLevel
        ))
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Swap size"),
            action: #selector(self.changeSwap),
            items: swapSizes,
            selected: self.swapSize
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func loadCallback(_ value: RAM_Usage) {
        let title = localizedString("RAM utilization threshold")
        
        if let threshold = Double(self.totalUsageLevel) {
            let subtitle = localizedString("RAM utilization is", "\(Int((value.usage)*100))%")
            self.checkDouble(id: self.totalUsageID, value: value.usage, threshold: threshold, title: title, subtitle: subtitle)
        }
        if let threshold = Double(self.freeLevel) {
            let free = value.free / value.total
            let subtitle = localizedString("Free RAM is", "\(Int((free)*100))%")
            self.checkDouble(id: self.freeID, value: free, threshold: threshold, title: title, subtitle: subtitle, less: true)
        }
        
        if self.pressureLevel != "", let thresholdPair = memoryPressureLevels.first(where: {$0.key == self.pressureLevel}) {
            if let threshold = thresholdPair.additional as? DispatchSource.MemoryPressureEvent {
                self.checkDouble(
                    id: self.pressureID,
                    value: Double(value.pressureLevel.rawValue),
                    threshold: Double(threshold.rawValue),
                    title: title,
                    subtitle: "\(localizedString("Memory pressure")): \(thresholdPair.key)"
                )
            }
        }
        
        if let threshold = Double(self.swapSize) {
            let value = Units(bytes: Int64(value.swap.used))
            let subtitle = "\(localizedString("Swap size")): \(value.getReadableMemory())"
            self.checkDouble(id: self.freeID, value: value.megabytes, threshold: threshold, title: title, subtitle: subtitle)
        }
    }
    
    @objc private func changeTotalUsage(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.totalUsageLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_totalUsage", value: self.totalUsageLevel)
    }
    
    @objc private func changeFree(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.freeLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_free", value: self.freeLevel)
    }
    
    @objc private func changePressure(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.pressureLevel = key
        Store.shared.set(key: "\(self.module)_notifications_pressure", value: self.pressureLevel)
    }
    
    @objc private func changeSwap(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.swapSize = key
        Store.shared.set(key: "\(self.module)_notifications_swap", value: self.swapSize)
    }
}
