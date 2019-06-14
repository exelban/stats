//
//  BatteryReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

class BatteryReader: Reader {
    var usage: Observable<Float>!
    var updateTimer: Timer!
    
    fileprivate static let IOSERVICE_BATTERY = "AppleSmartBattery"
    fileprivate var service: io_service_t = 0
    fileprivate enum Key: String {
        case ACPowered        = "ExternalConnected"
        case Amperage         = "Amperage"
        /// Current charge
        case CurrentCapacity  = "CurrentCapacity"
        case CycleCount       = "CycleCount"
        /// Originally DesignCapacity == MaxCapacity
        case DesignCapacity   = "DesignCapacity"
        case DesignCycleCount = "DesignCycleCount9C"
        case FullyCharged     = "FullyCharged"
        case IsCharging       = "IsCharging"
        /// Current max charge (this degrades over time)
        case MaxCapacity      = "MaxCapacity"
        case Temperature      = "Temperature"
        /// Time remaining to charge/discharge
        case TimeRemaining    = "TimeRemaining"
    }
    
    init() {
        self.usage = Observable(0)
        read()
    }
    
    func start() {
        _ = self.open()
        if updateTimer != nil {
            return
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(read), userInfo: nil, repeats: true)
    }
    
    func stop() {
        _ = self.close()
        if updateTimer == nil {
            return
        }
        updateTimer.invalidate()
        updateTimer = nil
    }
    
    @objc func read() {
        var cap = charge()
        let charging = isCharging()
        
        if !charging {
            cap = 0 - cap
        }
        
        self.usage << Float(cap)
    }
    
    public func open() -> kern_return_t {
        if (service != 0) {
            #if DEBUG
            print("WARNING - \(#file):\(#function) - connection already open")
            #endif
            return kIOReturnStillOpen
        }
        
        service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceNameMatching("AppleSmartBattery"))
        
        if (service == 0) {
            #if DEBUG
            print("ERROR - \(#file):\(#function) - service not found")
            #endif
            return kIOReturnNotFound
        }
        
        return kIOReturnSuccess
    }
    
    public func close() -> kern_return_t {
        let result = IOObjectRelease(service)
        service = 0
        
        #if DEBUG
        if (result != kIOReturnSuccess) {
            print("ERROR - \(#file):\(#function) - Failed to close")
        }
        #endif
        
        return result
    }
    
    public func maxCapactiy() -> Int {
        let prop = IORegistryEntryCreateCFProperty(service, Key.MaxCapacity.rawValue as CFString, kCFAllocatorDefault, 0)
        
        if prop != nil {
            return prop!.takeUnretainedValue() as! Int
        }
        return 0
    }
    
    public func currentCapacity() -> Int {
        let prop = IORegistryEntryCreateCFProperty(service, Key.CurrentCapacity.rawValue as CFString, kCFAllocatorDefault, 0)
        
        if prop != nil {
            return prop!.takeUnretainedValue() as! Int
        }
        return 0
    }
    
    public func isACPowered() -> Bool {
        let prop = IORegistryEntryCreateCFProperty(service, Key.ACPowered.rawValue as CFString, kCFAllocatorDefault, 0)
        
        if prop != nil {
            return prop!.takeUnretainedValue() as! Bool
        }
        return false
    }
    
    public func isCharging() -> Bool {
        let prop = IORegistryEntryCreateCFProperty(service, Key.IsCharging.rawValue as CFString, kCFAllocatorDefault, 0)
        
        if prop != nil {
            return prop!.takeUnretainedValue() as! Bool
        }
        return false
    }
    
    public func isCharged() -> Bool {
        let prop = IORegistryEntryCreateCFProperty(service, Key.FullyCharged.rawValue as CFString, kCFAllocatorDefault, 0)
        
        if prop != nil {
            return prop!.takeUnretainedValue() as! Bool
        }
        return false
    }
    
    public func charge() -> Double {
        let ccap = Double(currentCapacity())
        let mcap = Double(maxCapactiy())
        
        if ccap != 0 && mcap != 0 {
            return ccap / mcap
        }
        return 0
    }
    
    public func timeRemaining() -> Int {
        let prop = IORegistryEntryCreateCFProperty(service, Key.TimeRemaining.rawValue as CFString, kCFAllocatorDefault, 0)
        
        if prop != nil {
            return prop!.takeUnretainedValue() as! Int
        }
        return 0
    }
}
