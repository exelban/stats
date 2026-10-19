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
    
    var current: Int = 0
    var voltage: Double = 0
    var temperature: Double? = nil
    var batteryPower: Double = 0
    
    var ACwatts: Int = 0
    var chargingCurrent: Int = 0
    var chargingVoltage: Int = 0
    var adapterPower: Double = 0
    var adapterVoltage: Double = 0
    
    var timeToEmpty: Int = 0
    var timeToCharge: Int = 0
    var timeOnACPower: Date? = nil
    
    var ups: UPS_Usage? = nil
}

struct UPS_Usage: Codable {
    var name: String = ""
    var powerSource: String = ""
    var isBatteryPowered: Bool = false
    var isCharged: Bool = false
    var isCharging: Bool = false
    var level: Double = 0
}

public class Battery: Module {
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal
    private let notificationsView: Notifications
    
    private var usageReader: UsageReader? = nil
    private var processReader: ProcessReader? = nil
    
    private var textValue: String {
        Store.shared.string(key: "\(self.name)_textWidgetValue", defaultValue: "$battery.power")
    }
    private var timeFormat: String {
        Store.shared.string(key: "\(self.name)_timeFormat", defaultValue: "short")
    }
    
    public init() {
        self.settingsView = Settings(.battery)
        self.popupView = Popup(.battery)
        self.portalView = Portal(.battery, height: 70)
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
                    time: value.isBatteryPowered ? value.timeToEmpty : value.timeToCharge
                )
            case let widget as BatteryDetailsWidget:
                widget.setValue(
                    percentage: value.level,
                    time: value.isBatteryPowered ? value.timeToEmpty : value.timeToCharge
                )
            case let widget as TextWidget:
                var text = self.textValue
                let pairs = TextWidget.parseText(text)
                pairs.forEach { pair in
                    var replacement: String? = nil
                    
                    switch pair.key {
                    case "$battery":
                        switch pair.value {
                        case "level": replacement = "\(Int(abs(value.level) * 100))%"
                        case "power": replacement = "\(abs(value.batteryPower).roundTo(decimalPlaces: 2)) W"
                        case "current": replacement = "\(value.current) mA"
                        case "voltage": replacement = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
                        case "temperature": replacement = value.temperature.map { temperature($0) } ?? localizedString("Unavailable")
                        case "health": replacement = "\(value.health)%"
                        case "cycles": replacement = "\(value.cycles)"
                        case "source": replacement = localizedString(value.powerSource)
                        case "state": replacement = value.state.map { localizedString($0) } ?? localizedString("Unavailable")
                        case "status":
                            if value.isBatteryPowered {
                                replacement = localizedString("On battery")
                            } else if value.isCharged {
                                replacement = localizedString("Fully charged")
                            } else if value.optimizedChargingEngaged {
                                replacement = localizedString("On hold")
                            } else if value.isCharging {
                                replacement = localizedString("Charging")
                            } else {
                                replacement = localizedString("Plugged in")
                            }
                        default: return
                        }
                    case "$capacity":
                        switch pair.value {
                        case "current": replacement = "\(value.currentCapacity) mAh"
                        case "max": replacement = "\(value.maxCapacity) mAh"
                        case "designed": replacement = "\(value.designedCapacity) mAh"
                        default: return
                        }
                    case "$adapter":
                        switch pair.value {
                        case "power": replacement = "\(value.adapterPower.roundTo(decimalPlaces: 2)) W"
                        case "voltage": replacement = "\(value.adapterVoltage.roundTo(decimalPlaces: 2)) V"
                        case "current":
                            let current = value.adapterVoltage > 0 ? Int((value.adapterPower / value.adapterVoltage) * 1000) : 0
                            replacement = "\(current) mA"
                        case "rating": replacement = "\(value.ACwatts) W"
                        default: return
                        }
                    case "$charging":
                        switch pair.value {
                        case "current": replacement = "\(value.chargingCurrent) mA"
                        case "voltage": replacement = "\((Double(value.chargingVoltage)/1000).roundTo(decimalPlaces: 2)) V"
                        default: return
                        }
                    case "$time":
                        let minutes: Int
                        switch pair.value {
                        case "remaining":
                            if value.isCharged {
                                replacement = localizedString("Fully charged")
                            } else if value.optimizedChargingEngaged {
                                replacement = localizedString("On hold")
                            }
                            minutes = value.isBatteryPowered ? value.timeToEmpty : value.timeToCharge
                        case "empty": minutes = value.timeToEmpty
                        case "charge": minutes = value.timeToCharge
                        default: return
                        }
                        if replacement == nil {
                            if minutes == -1 {
                                replacement = localizedString("Calculating")
                            } else if minutes > 0 {
                                replacement = Double(minutes*60).printSecondsToHoursMinutesSeconds(short: self.timeFormat == "short")
                            } else {
                                replacement = localizedString("Unknown")
                            }
                        }
                    case "$ups":
                        switch pair.value {
                        case "name", "level", "source", "status": break
                        default: return
                        }
                        if let ups = value.ups {
                            switch pair.value {
                            case "name": replacement = ups.name
                            case "level": replacement = "\(Int(abs(ups.level) * 100))%"
                            case "source": replacement = localizedString(ups.powerSource)
                            case "status":
                                if ups.isBatteryPowered {
                                    replacement = localizedString("On battery")
                                } else if ups.isCharged {
                                    replacement = localizedString("Fully charged")
                                } else if ups.isCharging {
                                    replacement = localizedString("Charging")
                                } else {
                                    replacement = localizedString("Plugged in")
                                }
                            default: return
                            }
                        } else {
                            replacement = localizedString("Unavailable")
                        }
                    default: return
                    }
                    
                    if let replacement {
                        let key = pair.value.isEmpty ? pair.key : "\(pair.key).\(pair.value)"
                        text = text.replacingOccurrences(of: key, with: replacement)
                    }
                }
                widget.setValue(text)
            default: break
            }
        }
    }
}
