//
//  BatteryReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
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
    public var value: Observable<[Double]>!
    public var usage: Observable<BatteryUsage> = Observable(BatteryUsage())
    public var availableAdditional: Bool = false
    public var updateInterval: Int = 0
    
    private var service: io_connect_t = 0
    private var internalChecked: Bool = false
    private var hasInternalBattery: Bool = false
    private var timer: Repeater?
    
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
    
    init() {
        self.value = Observable([])
        self.service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
        
        if self.available {
            self.read()
        }
    }
    
    func start() {
        read()
        if self.timer != nil && self.timer!.state.isRunning == false {
            self.timer!.start()
        }
    }
    
    func stop() {
        self.timer?.pause()
        IOServiceClose(self.service)
        IOObjectRelease(self.service)
    }

    @objc func read() {
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

                DispatchQueue.main.async(execute: {
                    self.usage << BatteryUsage(
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
                })

                if powerSource == "Battery Power" {
                    cap = 0 - cap
                }
                
                var time = 0
                if timeToEmpty != 0 && timeToCharged == 0 {
                    time = timeToEmpty
                } else if timeToEmpty == 0 && timeToCharged != 0 {
                    time = timeToCharged
                }

                DispatchQueue.main.async(execute: {
                    self.value << [Double(cap), Double(time)]
                })
            }
        }
    }
    
    func getBoolValue(_ forIdentifier: CFString) -> Bool? {
        if let value = IORegistryEntryCreateCFProperty(self.service, forIdentifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Bool
        }
        return nil
    }
    
    func getIntValue(_ identifier: CFString) -> Int? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Int
        }
        return nil
    }
    
    func getDoubleValue(_ identifier: CFString) -> Double? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Double
        }
        return nil
    }
    
    func getVoltage() -> Double? {
        if let value = self.getDoubleValue("Voltage" as CFString) {
            return value / 1000.0
        }
        return nil
    }
    
    func getTemperature() -> Double? {
        if let value = IORegistryEntryCreateCFProperty(self.service, "Temperature" as CFString, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as! Double / 100.0
        }
        return nil
    }
    
    func setInterval(value: Int) {
        if value == 0 {
            return
        }
        
        self.updateInterval = value
        self.timer?.reset(.seconds(Double(value)))
    }
}
