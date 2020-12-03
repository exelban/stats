//
//  readers.swift
//  Sensors
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
import os.log

internal class SensorsReader: Reader<[Sensor_t]> {
    internal var list: [Sensor_t] = []
    private var smc: UnsafePointer<SMCService>
    
    init(_ smc: UnsafePointer<SMCService>) {
        self.smc = smc
        
        var available: [String] = self.smc.pointee.getAllKeys()
        var list: [Sensor_t] = []
        
        available = available.filter({ (key: String) -> Bool in
            switch key.prefix(1) {
            case "T", "V", "P", "F":
                if SensorsList.firstIndex(where: { $0.key == key }) == nil {
                    os_log(.debug, "Missing sensor key %s on the list", key)
                }
                return true
            default: return false
            }
        })
        
        SensorsList.forEach { (s: Sensor_t) in
            if let idx = available.firstIndex(where: { $0 == s.key }) {
                list.append(s)
                available.remove(at: idx)
            }
        }
        
        for (index, sensor) in list.enumerated().reversed() {
            if let newValue = self.smc.pointee.getValue(sensor.key) {
                // Remove the temperature sensor, if SMC report more that 110 C degree.
                if sensor.type == SensorType.Temperature.rawValue && newValue > 110 {
                    list.remove(at: index)
                    continue
                }
                
                if let idx = list.firstIndex(where: { $0.key == sensor.key }) {
                    list[idx].value = newValue
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
