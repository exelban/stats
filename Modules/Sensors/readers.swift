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
import Kit
import IOKit.hid

internal class SensorsReader: Reader<[Sensor_p]> {
    internal var list: [Sensor_p] = []
}

internal class x86_SensorsReader: SensorsReader {
    init() {
        super.init()
        
        var available: [String] = SMC.shared.getAllKeys()
        var list: [Sensor] = []
        
        if let count = SMC.shared.getValue("FNum") {
            debug("Found \(Int(count)) fans", log: self.log)
            
            for i in 0..<Int(count) {
                self.list.append(Fan(
                    id: i,
                    key: "F\(i)Ac",
                    name: SMC.shared.getStringValue("F\(i)ID") ?? "\(localizedString("Fan")) #\(i)",
                    minSpeed: SMC.shared.getValue("F\(i)Mn") ?? 1,
                    maxSpeed: SMC.shared.getValue("F\(i)Mx") ?? 1,
                    value: SMC.shared.getValue("F\(i)Ac") ?? 0,
                    mode: self.getFanMode(i)
                ))
            }
        }
        
        available = available.filter({ (key: String) -> Bool in
            switch key.prefix(1) {
            case "T", "V", "P", "I": return true
            default: return false
            }
        })
        
        SensorsList.forEach { (s: Sensor) in
            if let idx = available.firstIndex(where: { $0 == s.key }) {
                list.append(s)
                available.remove(at: idx)
            }
        }
        
        SensorsList.filter{ $0.key.contains("%") }.forEach { (s: Sensor) in
            var index = 1
            for i in 0..<10 {
                let key = s.key.replacingOccurrences(of: "%", with: "\(i)")
                if available.firstIndex(where: { $0 == key }) != nil {
                    var sensor = s.copy()
                    sensor.key = key
                    sensor.name = s.name.replacingOccurrences(of: "%", with: "\(index)")
                    
                    list.append(sensor)
                    index += 1
                }
            }
        }
        
        for sensor in list {
            if let newValue = SMC.shared.getValue(sensor.key) {
                if let idx = list.firstIndex(where: { $0.key == sensor.key }) {
                    list[idx].value = newValue
                }
            }
        }
        
        self.list += list.filter({ (s: Sensor) -> Bool in
            if s.type == .temperature && s.value > 110 {
                return false
            }
            return true
        })
    }
    
    public override func read() {
        for i in 0..<self.list.count {
            self.list[i].value = SMC.shared.getValue(self.list[i].key) ?? 0
        }
        self.callback(self.list)
    }
    
    private func getFanMode(_ id: Int) -> FanMode {
        let fansMode: Int = Int(SMC.shared.getValue("FS! ") ?? 0)
        var mode: FanMode = .automatic
        
        if fansMode == 0 {
            mode = .automatic
        } else if fansMode == 3 {
            mode = .forced
        } else if fansMode == 1 && id == 0 {
            mode = .forced
        } else if fansMode == 2 && id == 1 {
            mode = .forced
        }
        
        return mode
    }
}

internal class AppleSilicon_SensorsReader: SensorsReader {
    private let types: [SensorType] = [.temperature, .current, .voltage]
    
    init() {
        super.init()
        
        for type in types {
            self.fetch(type: type)
        }
        self.calculateAverageAndHottest()
        self.sort()
    }
    
    public override func read() {
        for type in types {
            self.fetch(type: type)
        }
        self.calculateAverageAndHottest()
        self.sort()
        
        self.callback(self.list)
    }
    
    private func fetch(type: SensorType) {
        var page: Int32 = 0
        var usage: Int32 = 0
        var eventType: Int32 = kIOHIDEventTypeTemperature
        
        //  usagePage:
        //    kHIDPage_AppleVendor                        = 0xff00,
        //    kHIDPage_AppleVendorTemperatureSensor       = 0xff05,
        //    kHIDPage_AppleVendorPowerSensor             = 0xff08,
        //    kHIDPage_GenericDesktop
        //
        //  usage:
        //    kHIDUsage_AppleVendor_TemperatureSensor     = 0x0005,
        //    kHIDUsage_AppleVendorPowerSensor_Current    = 0x0002,
        //    kHIDUsage_AppleVendorPowerSensor_Voltage    = 0x0003,
        //    kHIDUsage_GD_Keyboard
        //
        
        switch type {
        case .temperature:
            page = 0xff00
            usage = 0x0005
            eventType = kIOHIDEventTypeTemperature
        case .current:
            page = 0xff08
            usage = 0x0002
            eventType = kIOHIDEventTypePower
        case .voltage:
            page = 0xff08
            usage = 0x0003
            eventType = kIOHIDEventTypePower
        case .power: break
        case .fan: break
        }
        
        if let list = AppleSiliconSensors(page, usage, eventType) {
            list.forEach { (key, value) in
                if let name = key as? String, let value = value as? Double {
                    self.upsert(key: name, value: value, type: type)
                }
            }
        }
        
        return
    }
    
    private func createDeviceMatchingDictionary(usagePage: Int, usage: Int) -> CFMutableDictionary {
        let dict = [
            kIOHIDPrimaryUsageKey: usage,
            kIOHIDPrimaryUsagePageKey: usagePage
        ] as NSDictionary
        
        return dict.mutableCopy() as! NSMutableDictionary
    }
    
    private func upsert(key: String, value: Double, type: SensorType, group: SensorGroup = .system, prepend: Bool = false) {
        if let idx = self.list.firstIndex(where: { $0.key == key }) {
            self.list[idx].value = value
        } else {
            var name: String = key
            var g: SensorGroup = group
            
            AppleSiliconSensorsList.forEach { (s: Sensor) in
                if s.key.contains("%") {
                    var index = 1
                    for i in 0..<64 {
                        if s.key.replacingOccurrences(of: "%", with: "\(i)") == key {
                            name = s.name.replacingOccurrences(of: "%", with: "\(index)")
                        }
                        index += 1
                    }
                } else if s.key == key {
                    name = s.name
                }
                g = s.group
            }
            
            let s = Sensor(
                key: key,
                name: name,
                value: value,
                group: g,
                type: type
            )
            
            if prepend {
                self.list.insert(s, at: 0)
            } else {
                self.list.append(s)
            }
        }
    }
    
    private func calculateAverageAndHottest() {
        let cpuSensors = self.list.filter({ $0.key.hasPrefix("pACC MTR Temp") || $0.key.hasPrefix("eACC MTR Temp") }).map{ $0.value }
        let gpuSensors = self.list.filter({ $0.key.hasPrefix("GPU MTR Temp") }).map{ $0.value }
        let socSensors = self.list.filter({ $0.key.hasPrefix("SOC MTR Temp") }).map{ $0.value }
        
        if !socSensors.isEmpty {
            self.upsert(
                key: "Average SOC",
                value: socSensors.reduce(0, +) / Double(socSensors.count),
                type: .temperature,
                group: .system,
                prepend: true
            )
            if let max = socSensors.max() {
                self.upsert(
                    key: "Hottest SOC",
                    value: max,
                    type: .temperature,
                    group: .system,
                    prepend: true
                )
            }
        }
        if !gpuSensors.isEmpty {
            self.upsert(
                key: "Average GPU",
                value: gpuSensors.reduce(0, +) / Double(gpuSensors.count),
                type: .temperature,
                group: .GPU,
                prepend: true
            )
            if let max = gpuSensors.max() {
                self.upsert(
                    key: "Hottest GPU",
                    value: max,
                    type: .temperature,
                    group: .system,
                    prepend: true
                )
            }
        }
        if !cpuSensors.isEmpty {
            self.upsert(
                key: "Average CPU",
                value: cpuSensors.reduce(0, +) / Double(cpuSensors.count),
                type: .temperature,
                group: .CPU,
                prepend: true
            )
            if let max = cpuSensors.max() {
                self.upsert(
                    key: "Hottest CPU",
                    value: max,
                    type: .temperature,
                    group: .system,
                    prepend: true
                )
            }
        }
    }
    
    private func sort() {
        self.list = self.list.filter({ (s: Sensor_p) -> Bool in
            switch s.type {
            case .temperature:
                return s.value < 110 && s.value >= 0
            case .voltage:
                return s.value < 300 && s.value >= 0
            case .current:
                return s.value < 100 && s.value >= 0
            default: return true
            }
        }).sorted { $0.key.lowercased() < $1.key.lowercased() }
    }
}
