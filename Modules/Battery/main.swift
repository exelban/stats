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
import StatsKit
import ModuleKit
import IOKit.ps

struct Battery_Usage: value_t {
    var powerSource: String = ""
    var state: String = ""
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
    
    public var widget_value: Double {
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
    
    private let store: UnsafePointer<Store>
    
    private var notification: NSUserNotification? = nil
    
    public init(_ store: UnsafePointer<Store>) {
        self.store = store
        self.settingsView = Settings("Battery", store: store)
        self.popupView = Popup("Battery", store: store)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.usageReader = UsageReader()
        self.processReader = ProcessReader(self.config.name, store: store)
        
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
        
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
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
        return sources.count > 0
    }
    
    private func usageCallback(_ value: Battery_Usage?) {
        if value == nil {
            return
        }
        
        self.checkNotification(value: value!)
        self.popupView.usageCallback(value!)
        if let widget = self.widget as? Mini {
            widget.setValue(abs(value!.level))
        }
        if let widget = self.widget as? BarChart {
            widget.setValue([value!.level])
        }
        if let widget = self.widget as? BatterykWidget {
            widget.setValue(
                percentage: value?.level ?? 0,
                ACStatus: value?.powerSource != "Battery Power",
                isCharging: value?.isCharging ?? false,
                time: (value?.timeToEmpty == 0 && value?.timeToCharge != 0 ? value?.timeToCharge : value?.timeToEmpty) ?? 0
            )
        }
    }
    
    private func checkNotification(value: Battery_Usage) {
        let level = self.store.pointee.string(key: "\(self.config.name)_lowLevelNotification", defaultValue: "0.15")
        if level == LocalizedString("Disabled") {
            return
        }
        
        guard let notificationLevel = Double(level) else {
            return
        }
        
        if (value.level > notificationLevel || value.powerSource != "Battery Power") && self.notification != nil {
            NSUserNotificationCenter.default.removeDeliveredNotification(self.notification!)
            if value.level > notificationLevel {
                self.notification = nil
            }
            return
        }
        
        if value.isCharging {
            return
        }
        
        if value.level <= notificationLevel && self.notification == nil {
            var subtitle = LocalizedString("Battery remaining", "\(Int(value.level*100))")
            if value.timeToEmpty > 0 {
                subtitle += " (\(Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()))"
            }
            
            self.notification = showNotification(
                title: LocalizedString("Low battery"),
                subtitle: subtitle,
                id: "battery-level",
                icon: NSImage(named: NSImage.Name("low-battery"))!
            )
        }
    }
}
