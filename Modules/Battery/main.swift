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

struct Battery_Usage: value_t {
    var powerSource: String = ""
    var state: String? = nil
    var isCharged: Bool = false
    var isCharging: Bool = false
    var level: Double = 0
    var cycles: Int = 0
    var health: Int = 0
    
    var amperage: Int = 0
    var voltage: Double = 0
    var temperature: Double = 0
    
    var ACwatts: Int = 0
    
    var timeToEmpty: Int = 0
    var timeToCharge: Int = 0
    var timeOnACPower: Date? = nil
    
    public var widgetValue: Double {
        get {
            return self.level
        }
    }
}

public class Battery: Module {
    private var usageReader: UsageReader? = nil
    private var processReader: ProcessReader? = nil
    private let popupView: Popup
    private var settingsView: Settings
    
    private var lowNotification: NSUserNotification? = nil
    private var highNotification: NSUserNotification? = nil
    
    public init() {
        self.settingsView = Settings("Battery")
        self.popupView = Popup("Battery")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.usageReader = UsageReader()
        self.processReader = ProcessReader()
        
        self.settingsView.callback = {
            DispatchQueue.global(qos: .background).async {
                self.usageReader?.read()
            }
        }
        self.settingsView.callbackWhenUpdateNumberOfProcesses = {
            self.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self.processReader?.read()
            }
        }
        
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.processReader?.callbackHandler = { [unowned self] value in
            if let list = value {
                self.popupView.processCallback(list)
            }
        }
        
        if let reader = self.usageReader {
            self.addReader(reader)
        }
        if let reader = self.processReader {
            self.addReader(reader)
        }
    }
    
    public override func isAvailable() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        return !sources.isEmpty
    }
    
    private func usageCallback(_ raw: Battery_Usage?) {
        guard let value = raw else {
            return
        }
        
        self.checkLowNotification(value: value)
        self.checkHighNotification(value: value)
        self.popupView.usageCallback(value)
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini: widget.setValue(abs(value.level))
            case let widget as BarChart: widget.setValue([value.level])
            case let widget as BatterykWidget:
                widget.setValue(
                    percentage: value.level ,
                    ACStatus: value.powerSource != "Battery Power",
                    isCharging: value.isCharging ,
                    time: value.timeToEmpty == 0 && value.timeToCharge != 0 ? value.timeToCharge : value.timeToEmpty
                )
            default: break
            }
        }
    }
    
    private func checkLowNotification(value: Battery_Usage) {
        let level = Store.shared.string(key: "\(self.config.name)_lowLevelNotification", defaultValue: "0.15")
        if level == "Disabled" {
            return
        }
        
        guard let notificationLevel = Double(level) else {
            return
        }
        
        if (value.level > notificationLevel || value.powerSource != "Battery Power") && self.lowNotification != nil {
            NSUserNotificationCenter.default.removeDeliveredNotification(self.lowNotification!)
            if value.level > notificationLevel {
                self.lowNotification = nil
            }
            return
        }
        
        if value.isCharging {
            return
        }
        
        if value.level <= notificationLevel && self.lowNotification == nil {
            var subtitle = localizedString("Battery remaining", "\(Int(value.level*100))")
            if value.timeToEmpty > 0 {
                subtitle += " (\(Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()))"
            }
            
            self.lowNotification = showNotification(
                title: localizedString("Low battery"),
                subtitle: subtitle,
                id: "battery-level",
                icon: NSImage(named: NSImage.Name("low-battery"))!
            )
        }
    }
    
    private func checkHighNotification(value: Battery_Usage) {
        let level = Store.shared.string(key: "\(self.config.name)_highLevelNotification", defaultValue: "Disabled")
        if level == "Disabled" {
            return
        }
        
        guard let notificationLevel = Double(level) else {
            return
        }
        
        if (value.level < notificationLevel || value.powerSource == "Battery Power") && self.highNotification != nil {
            NSUserNotificationCenter.default.removeDeliveredNotification(self.highNotification!)
            if value.level < notificationLevel {
                self.highNotification = nil
            }
            return
        }
        
        if !value.isCharging {
            return
        }
        
        if value.level >= notificationLevel && self.highNotification == nil {
            var subtitle = localizedString("Battery remaining to full charge", "\(Int((1-value.level)*100))")
            if value.timeToCharge > 0 {
                subtitle += " (\(Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds()))"
            }
            
            self.highNotification = showNotification(
                title: localizedString("High battery"),
                subtitle: subtitle,
                id: "battery-level2",
                icon: NSImage(named: NSImage.Name("high-battery"))!
            )
        }
    }
}
