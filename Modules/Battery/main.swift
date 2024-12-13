//
//  main.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit
import IOKit.ps

struct Battery_Usage: Codable {
    var powerSource: String = ""
    var state: String? = nil
    var isCharged: Bool = false
    var isCharging: Bool = false
    var isBatteryPowered: Bool = false
    var optimizedChargingEngaged: Bool = false
    var level: Double = 0
    var cycles: Int = 0
    var health: Int = 0
    
    var designedCapacity: Int = 0
    var maxCapacity: Int = 0
    var currentCapacity: Int = 0
    
    var amperage: Int = 0
    var voltage: Double = 0
    var temperature: Double = 0
    
    var ACwatts: Int = 0
    var chargingCurrent: Int = 0
    var chargingVoltage: Int = 0
    
    var timeToEmpty: Int = 0
    var timeToCharge: Int = 0
    var timeOnACPower: Date? = nil
}

public class Battery: Module {
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal
    private let notificationsView: Notifications
    
    private var usageReader: UsageReader? = nil
    private var processReader: ProcessReader? = nil
    
    private var lowLevelNotificationState: Bool = false
    private var highLevelNotificationState: Bool = false
    private var notificationID: String? = nil
    
    public init() {
        self.settingsView = Settings(.battery)
        self.popupView = Popup(.battery)
        self.portalView = Portal(.battery)
        self.notificationsView = Notifications(.battery)
        
        super.init(
            moduleType: .battery,
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView,
            notifications: self.notificationsView
        )
        guard self.available else { return }
        
        self.usageReader = UsageReader(.battery) { [weak self] value in
            self?.usageCallback(value)
        }
        self.processReader = ProcessReader(.battery) { [weak self] value in
            if let list = value {
                self?.popupView.processCallback(list)
            }
        }
        
        self.settingsView.callback = { [weak self] in
            DispatchQueue.global(qos: .background).async {
                self?.usageReader?.read()
            }
        }
        self.settingsView.callbackWhenUpdateNumberOfProcesses = { [weak self] in
            self?.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self?.processReader?.read()
            }
        }
        
        self.setReaders([self.usageReader, self.processReader])
    }
    
    public override func willTerminate() {
        guard self.isAvailable() else { return }
        self.notificationsView.willTerminate()
    }
    
    public override func isAvailable() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        return !sources.isEmpty
    }
    
    private func usageCallback(_ raw: Battery_Usage?) {
        guard let value = raw, self.enabled else { return }
        
        self.popupView.usageCallback(value)
        self.portalView.loadCallback(value)
        self.notificationsView.usageCallback(value)
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: SWidget) in
            switch w.item {
            case let widget as Mini:
                widget.setValue(abs(value.level))
                widget.setColorZones((0.15, 0.3))
            case let widget as BarChart:
                widget.setValue([[ColorValue(value.level)]])
                widget.setColorZones((0.15, 0.3))
            case let widget as BatteryWidget:
                widget.setValue(
                    percentage: value.level,
                    ACStatus: !value.isBatteryPowered,
                    isCharging: value.isCharging,
                    optimizedCharging: value.optimizedChargingEngaged,
                    time: value.timeToEmpty == 0 && value.timeToCharge != 0 ? value.timeToCharge : value.timeToEmpty
                )
            case let widget as BatteryDetailsWidget:
                widget.setValue(
                    percentage: value.level,
                    time: value.timeToEmpty == 0 && value.timeToCharge != 0 ? value.timeToCharge : value.timeToEmpty
                )
            default: break
            }
        }
    }
}
