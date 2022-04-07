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

internal class SensorsReader: Reader<[Sensor_p]> {
    internal var list: [Sensor_p] = []
    static let HIDtypes: [SensorType] = [.temperature, .voltage]
    
    private var HIDState: Bool {
        get {
            return Store.shared.bool(key: "Sensors_hid", defaultValue: false)
        }
    }
    
    init() {
        super.init()
        
        var available: [String] = SMC.shared.getAllKeys()
        var list: [Sensor] = []
        var sensorsList = SensorsList
        #if arch(arm64)
        sensorsList = sensorsList.filter({ !$0.isIntelOnly })
        #endif
        
        if let count = SMC.shared.getValue("FNum") {
            self.loadFans(Int(count))
        }
        
        available = available.filter({ (key: String) -> Bool in
            switch key.prefix(1) {
            case "T", "V", "P", "I": return true
            default: return false
            }
        })
        
        sensorsList.forEach { (s: Sensor) in
            if let idx = available.firstIndex(where: { $0 == s.key }) {
                list.append(s)
                available.remove(at: idx)
            }
        }
        
        sensorsList.filter{ $0.key.contains("%") }.forEach { (s: Sensor) in
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
            if s.type == .temperature && (s.value == 0 || s.value > 110) {
                return false
            }
            return true
        })
        
        #if arch(arm64)
        if self.HIDState {
            self.list += self.initHIDSensors()
        }
        #endif
        
        self.list += self.initCalculatedSensors()
    }
    
    public override func read() {
        for (i, s) in self.list.enumerated() {
            if s.group == .hid || s.isComputed {
                continue
            }
            self.list[i].value = SMC.shared.getValue(self.list[i].key) ?? 0
        }
        
        var cpuSensors = self.list.filter({ $0.group == .CPU && $0.type == .temperature && $0.average }).map{ $0.value }
        var gpuSensors = self.list.filter({ $0.group == .GPU && $0.type == .temperature && $0.average }).map{ $0.value }
        let fanSensors = self.list.filter({ $0.type == .fan && !$0.isComputed }).map{ $0.value }
        
        #if arch(arm64)
        if self.HIDState {
            for typ in SensorsReader.HIDtypes {
                let (page, usage, type) = self.m1Preset(type: typ)
                AppleSiliconSensors(page, usage, type).forEach { (key, value) in
                    guard let key = key as? String, let value = value as? Double, value < 300 && value >= 0 else {
                        return
                    }
                    
                    if let idx = self.list.firstIndex(where: { $0.group == .hid && $0.key == key }) {
                        self.list[idx].value = value
                    }
                }
            }
            
            cpuSensors += self.list.filter({ $0.key.hasPrefix("pACC MTR Temp") || $0.key.hasPrefix("eACC MTR Temp") }).map{ $0.value }
            gpuSensors += self.list.filter({ $0.key.hasPrefix("GPU MTR Temp") }).map{ $0.value }
            
            let socSensors = list.filter({ $0.key.hasPrefix("SOC MTR Temp") }).map{ $0.value }
            if !socSensors.isEmpty {
                if let idx = self.list.firstIndex(where: { $0.key == "Average SOC" }) {
                    self.list[idx].value = socSensors.reduce(0, +) / Double(socSensors.count)
                }
                if let max = socSensors.max() {
                    if let idx = self.list.firstIndex(where: { $0.key == "Hottest SOC" }) {
                        self.list[idx].value = max
                    }
                }
            }
        }
        #endif
        
        if !cpuSensors.isEmpty {
            if let idx = self.list.firstIndex(where: { $0.key == "Average CPU" }) {
                self.list[idx].value = cpuSensors.reduce(0, +) / Double(cpuSensors.count)
            }
            if let max = cpuSensors.max() {
                if let idx = self.list.firstIndex(where: { $0.key == "Hottest CPU" }) {
                    self.list[idx].value = max
                }
            }
        }
        if !gpuSensors.isEmpty {
            if let idx = self.list.firstIndex(where: { $0.key == "Average GPU" }) {
                self.list[idx].value = gpuSensors.reduce(0, +) / Double(gpuSensors.count)
            }
            if let max = gpuSensors.max() {
                if let idx = self.list.firstIndex(where: { $0.key == "Hottest GPU" }) {
                    self.list[idx].value = max
                }
            }
        }
        if !fanSensors.isEmpty && fanSensors.count > 1 {
            if let max = fanSensors.max() {
                if let idx = self.list.firstIndex(where: { $0.key == "Fastest Fan" }) {
                    self.list[idx].value = max
                }
            }
        }
        
        self.callback(self.list)
    }
    
    private func loadFans(_ count: Int) {
        debug("Found \(Int(count)) fans", log: self.log)
        
        for i in 0..<Int(count) {
            var name = SMC.shared.getStringValue("F\(i)ID")
            var mode: FanMode
            
            if name == nil && count == 2 {
                switch i {
                case 0:
                    name = localizedString("Left fan")
                case 1:
                    name = localizedString("Right fan")
                default: break
                }
            }
            
            if let md = SMC.shared.getValue("F\(i)Md") {
                mode = FanMode(rawValue: Int(md)) ?? .automatic
            } else {
                mode = self.getFanMode(i)
            }
            
            self.list.append(Fan(
                id: i,
                key: "F\(i)Ac",
                name: name ?? "\(localizedString("Fan")) #\(i)",
                minSpeed: SMC.shared.getValue("F\(i)Mn") ?? 1,
                maxSpeed: SMC.shared.getValue("F\(i)Mx") ?? 1,
                value: SMC.shared.getValue("F\(i)Ac") ?? 0,
                mode: mode
            ))
        }
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
    
    private func m1Preset(type: SensorType) -> (Int32, Int32, Int32) {
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
        
        return (page, usage, eventType)
    }
    
    private func initHIDSensors() -> [Sensor] {
        var list: [Sensor] = []
        
        for typ in SensorsReader.HIDtypes {
            let (page, usage, type) = self.m1Preset(type: typ)
            if let sensors = AppleSiliconSensors(page, usage, type) {
                sensors.forEach { (key, value) in
                    guard let key = key as? String, let value = value as? Double else {
                        return
                    }
                    var name: String = key
                    
                    HIDSensorsList.forEach { (s: Sensor) in
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
                    }
                    
                    list.append(Sensor(
                        key: key,
                        name: name,
                        value: value,
                        group: .hid,
                        type: typ
                    ))
                }
            }
        }
        
        let socSensors = list.filter({ $0.key.hasPrefix("SOC MTR Temp") }).map{ $0.value }
        if !socSensors.isEmpty {
            let value = socSensors.reduce(0, +) / Double(socSensors.count)
            list.append(Sensor(key: "Average SOC", name: "Average SOC", value: value, group: .hid, type: .temperature))
            if let max = socSensors.max() {
                list.append(Sensor(key: "Hottest SOC", name: "Hottest SOC", value: max, group: .hid, type: .temperature))
            }
        }
        
        return list.filter({ (s: Sensor_p) -> Bool in
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
    
    private func initCalculatedSensors() -> [Sensor] {
        var list: [Sensor] = []
        
        var cpuSensors = self.list.filter({ $0.group == .CPU && $0.type == .temperature && $0.average }).map{ $0.value }
        var gpuSensors = self.list.filter({ $0.group == .GPU && $0.type == .temperature && $0.average }).map{ $0.value }
        
        #if arch(arm64)
        if self.HIDState {
            cpuSensors += self.list.filter({ $0.key.hasPrefix("pACC MTR Temp") || $0.key.hasPrefix("eACC MTR Temp") }).map{ $0.value }
            gpuSensors += self.list.filter({ $0.key.hasPrefix("GPU MTR Temp") }).map{ $0.value }
        }
        #endif
        
        let fanSensors = self.list.filter({ $0.type == .fan && !$0.isComputed }).map{ $0.value}
        
        if !cpuSensors.isEmpty {
            let value = cpuSensors.reduce(0, +) / Double(cpuSensors.count)
            list.append(Sensor(key: "Average CPU", name: "Average CPU", value: value, group: .CPU, type: .temperature, isComputed: true))
            if let max = cpuSensors.max() {
                list.append(Sensor(key: "Hottest CPU", name: "Hottest CPU", value: max, group: .CPU, type: .temperature, isComputed: true))
            }
        }
        if !gpuSensors.isEmpty {
            let value = gpuSensors.reduce(0, +) / Double(gpuSensors.count)
            list.append(Sensor(key: "Average GPU", name: "Average GPU", value: value, group: .GPU, type: .temperature, isComputed: true))
            if let max = gpuSensors.max() {
                list.append(Sensor(key: "Hottest GPU", name: "Hottest GPU", value: max, group: .GPU, type: .temperature, isComputed: true))
            }
        }
        if !fanSensors.isEmpty && fanSensors.count > 1 {
            if let max = fanSensors.max() {
                list.append(Sensor(key: "Fastest Fan", name: "Fastest Fan", value: max, group: .sensor, type: .fan, isComputed: true))
            }
        }
        
        return list.filter({ (s: Sensor_p) -> Bool in
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
    
    public func HIDCallback() {
        if self.HIDState {
            self.list += self.initHIDSensors()
        } else {
            self.list = self.list.filter({ $0.group != .hid })
        }
    }
}
