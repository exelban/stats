//
//  readers.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class SensorsReader: Reader<[Sensor_t]> {
    internal var list: [Sensor_t] = []
    private var smc: UnsafePointer<SMCService>
    
    init(_ smc: UnsafePointer<SMCService>) {
        self.smc = smc
        
        var available: [String] = self.smc.pointee.getAllKeys()
        var list: [Sensor_t] = []
        
        available = available.filter({ (key: String) -> Bool in
            switch key.prefix(1) {
            case "T", "V", "P": return SensorsDict[key] != nil
            default: return false
            }
        })
        
        available.forEach { (key: String) in
            if var sensor = SensorsDict[key] {
                sensor.value = smc.pointee.getValue(key)
                if sensor.value != nil {
                    sensor.key = key
                    list.append(sensor)
                }
            }
        }
        
        self.list = list
    }
    
    public override func read() {
        for i in 0..<self.list.count {
            if let newValue = self.smc.pointee.getValue(self.list[i].key) {
                self.list[i].value = newValue
            }
        }
        self.callback(self.list)
    }
}
