//
//  BatteryReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/06/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import IOKit.ps

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
        if updateTimer != nil {
            return
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(read), userInfo: nil, repeats: true)
    }
    
    func stop() {
        if updateTimer == nil {
            return
        }
        updateTimer.invalidate()
        updateTimer = nil
    }
    
    @objc func read() {
        let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
        
        for ps in psList {
            if let psDesc = IOPSGetPowerSourceDescription(psInfo, ps).takeUnretainedValue() as? [String: Any] {
//                let type = psDesc[kIOPSTypeKey] as? String
                let isCharging = (psDesc[kIOPSIsChargingKey] as? Bool)
                var cap: Float = Float(psDesc[kIOPSCurrentCapacityKey] as! Int) / 100
                
                if !isCharging! {
                    cap = 0 - cap
                }
                
                self.usage << Float(cap)
            }
        }
    }
}
