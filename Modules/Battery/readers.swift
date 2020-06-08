//
//  readers.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit

internal class UsageReader: Reader<Usage> {
    private var service: io_connect_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
    
    private var source: CFRunLoopSource?
    private var loop: CFRunLoop?
    
    private var usage: Usage = Usage()
    
    public override func start() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        self.source = IOPSNotificationCreateRunLoopSource({ (context) in
            guard let ctx = context else {
                return
            }
            
            let watcher = Unmanaged<UsageReader>.fromOpaque(ctx).takeUnretainedValue()
            watcher.read()
        }, context).takeRetainedValue()
        
        self.loop = RunLoop.current.getCFRunLoop()
        CFRunLoopAddSource(self.loop, source, .defaultMode)
        
        self.read()
    }
    
    public override func stop() {
        guard let runLoop = loop, let source = source else {
            return
        }
        
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
    }
    
    public override func read() {
        let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
        
        if psList.count == 0 {
            return
        }
        
        for ps in psList {
            if let list = IOPSGetPowerSourceDescription(psInfo, ps).takeUnretainedValue() as? Dictionary<String, Any> {
                self.usage.powerSource = list[kIOPSPowerSourceStateKey] as? String ?? "AC Power"
                self.usage.state = list[kIOPSBatteryHealthKey] as! String
                self.usage.isCharged = list[kIOPSIsChargedKey] as? Bool ?? false
                var cap = Double(list[kIOPSCurrentCapacityKey] as! Int) / 100
                
                self.usage.timeToEmpty = Int(list[kIOPSTimeToEmptyKey] as! Int)
                self.usage.timeToCharge = Int(list[kIOPSTimeToFullChargeKey] as! Int)
                
                self.usage.cycles = self.getIntValue("CycleCount" as CFString) ?? 0
                
                let maxCapacity = self.getIntValue("MaxCapacity" as CFString) ?? 1
                let designCapacity = self.getIntValue("DesignCapacity" as CFString) ?? 1
                self.usage.health = (100 * maxCapacity) / designCapacity
                
                self.usage.amperage = self.getIntValue("Amperage" as CFString) ?? 0
                self.usage.voltage = self.getVoltage() ?? 0
                self.usage.temperature = self.getTemperature() ?? 0
                
                var ACwatts: Int = 0
                if let ACDetails = IOPSCopyExternalPowerAdapterDetails() {
                    if let ACList = ACDetails.takeUnretainedValue() as? Dictionary<String, Any> {
                        guard let watts = ACList[kIOPSPowerAdapterWattsKey] else {
                            return
                        }
                        ACwatts = Int(watts as! Int)
                    }
                }
                self.usage.ACwatts = ACwatts
                self.usage.ACstatus = self.getBoolValue("IsCharging" as CFString) ?? false
                
                if self.usage.powerSource == "Battery Power" {
                    cap = 0 - cap
                }
                self.usage.level = cap
                
                DispatchQueue.main.async(execute: {
                    self.callback(self.usage)
                })
            }
        }
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
