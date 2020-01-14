//
//  BatteryReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import IOKit.ps

struct BatteryUsage {
    var powerSource: String = ""
    var state: String = ""
    var isCharged: Bool = false
    var capacity: Double = 0
    var cycles: Int = 0
    var health: Int = 0
    
    var amperage: Int = 0
    var voltage: Double = 0
    var temperature: Double = 0
    
    var ACwatts: Int = 0
    var ACstatus: Bool = false
    
    var timeToEmpty: Int = 0
    var timeToCharge: Int = 0
}

class BatteryReader: Reader {
    public var name: String = "Battery"
    public var enabled: Bool = true
    public var available: Bool {
        get {
            if !self.internalChecked {
                let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
                let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
                self.hasInternalBattery = sources.count > 0
                self.internalChecked = true
            }
            return self.hasInternalBattery
        }
    }
    public var optional: Bool = false
    public var initialized: Bool = false
    public var callback: (BatteryUsage) -> Void = {_ in}
    
    private var service: io_connect_t = 0
    private var internalChecked: Bool = false
    private var hasInternalBattery: Bool = false
    
    init(_ updater: @escaping (BatteryUsage) -> Void) {
        self.callback = updater
        
        self.service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
        
        if self.available {
            self.read()
        }
    }

    public func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
        
        for ps in psList {
            if let list = IOPSGetPowerSourceDescription(psInfo, ps).takeUnretainedValue() as? Dictionary<String, Any> {
                let powerSource = list[kIOPSPowerSourceStateKey] as? String ?? "AC Power"
                let state = list[kIOPSBatteryHealthKey] as! String
                let isCharged = list[kIOPSIsChargedKey] as? Bool ?? false
                var cap = Float(list[kIOPSCurrentCapacityKey] as! Int) / 100

                let timeToEmpty = Int(list[kIOPSTimeToEmptyKey] as! Int)
                let timeToCharged = Int(list[kIOPSTimeToFullChargeKey] as! Int)

                let cycles = self.getIntValue("CycleCount" as CFString) ?? 0
                
                let maxCapacity = self.getIntValue("MaxCapacity" as CFString) ?? 1
                let designCapacity = self.getIntValue("DesignCapacity" as CFString) ?? 1
                
                let amperage = self.getIntValue("Amperage" as CFString) ?? 0
                let voltage = self.getVoltage() ?? 0
                let temperature = self.getTemperature() ?? 0
                
                var ACwatts: Int = 0
                if let ACDetails = IOPSCopyExternalPowerAdapterDetails() {
                    if let ACList = ACDetails.takeUnretainedValue() as? Dictionary<String, Any> {
                        ACwatts = Int(ACList[kIOPSPowerAdapterWattsKey] as! Int)
                    }
                }
                let ACstatus = self.getBoolValue("IsCharging" as CFString) ?? false
                
                if powerSource == "Battery Power" {
                    cap = 0 - cap
                }
                
                DispatchQueue.main.async(execute: {
                    let usage = BatteryUsage(
                        powerSource: powerSource,
                        state: state,
                        isCharged: isCharged,
                        capacity: Double(cap),
                        cycles: cycles,
                        health: (100 * maxCapacity) / designCapacity,
                        
                        amperage: amperage,
                        voltage: voltage,
                        temperature: temperature,
                        
                        ACwatts: ACwatts,
                        ACstatus: ACstatus,
                    
                        timeToEmpty: timeToEmpty,
                        timeToCharge: timeToCharged
                    )
                    self.callback(usage)
                })
            }
        }
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
    
    private func getBoolValue(_ forIdentifier: CFString) -> Bool? {
        if let value = IORegistryEntryCreateCFProperty(self.service, forIdentifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Bool
        }
        return nil
    }
    
    private func getIntValue(_ identifier: CFString) -> Int? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Int
        }
        return nil
    }
    
    private func getDoubleValue(_ identifier: CFString) -> Double? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Double
        }
        return nil
    }
    
    private func getVoltage() -> Double? {
        if let value = self.getDoubleValue("Voltage" as CFString) {
            return value / 1000.0
        }
        return nil
    }
    
    private func getTemperature() -> Double? {
        if let value = IORegistryEntryCreateCFProperty(self.service, "Temperature" as CFString, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as! Double / 100.0
        }
        return nil
    }
}
