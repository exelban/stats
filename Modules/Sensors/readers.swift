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
import IOKit.hid

internal class SensorsReader: Reader<[Sensor_t]> {
    internal var list: [Sensor_t] = []
}

internal class x86_SensorsReader: SensorsReader {
    init() {
        super.init()
        
        var available: [String] = SMC.shared.getAllKeys()
        var list: [Sensor_t] = []
        
        available = available.filter({ (key: String) -> Bool in
            switch key.prefix(1) {
            case "T", "V", "P", "F": return true
            default: return false
            }
        })
        
        SensorsList.forEach { (s: Sensor_t) in
            if let idx = available.firstIndex(where: { $0 == s.key }) {
                list.append(s)
                available.remove(at: idx)
            }
        }
        
        SensorsList.filter{ $0.key.contains("%") }.forEach { (s: Sensor_t) in
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
        
        self.list = list.filter({ (s: Sensor_t) -> Bool in
            if s.type == .temperature && s.value > 110 {
                return false
            }
            return true
        })
    }
    
    public override func read() {
        for i in 0..<self.list.count {
            if let newValue = SMC.shared.getValue(self.list[i].key) {
                self.list[i].value = newValue
            }
        }
        self.callback(self.list)
    }
}

internal class AppleSilicon_SensorsReader: SensorsReader {
    private let types: [SensorType] = [.temperature, .current, .voltage]
    
    init() {
        super.init()
        
        for type in types {
            for (name, value) in self.fetch(type: type) {
                self.list.append(Sensor_t(
                    key: name,
                    name: name,
                    value: value,
                    group: .system,
                    type: type
                ))
            }
        }
        
        self.list = self.list.filter({ (s: Sensor_t) -> Bool in
            switch s.type {
            case .temperature:
                return s.value < 110
            case .voltage:
                return s.value < 300
            case .current:
                return s.value < 100
            default: return true
            }
        })
    }
    
    public override func read() {
        for type in types {
            for (name, value) in self.fetch(type: type) {
                if let idx = self.list.firstIndex(where: { $0.name == name && $0.type == type }) {
                    self.list[idx].value = value
                }
            }
        }
        self.callback(self.list)
    }
    
    private func fetch(type: SensorType) -> [String: Double] {
        var list: [String: Double] = [:]
        
        var page: Int = 0
        var usage: Int = 0
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
            usage = 0x0003
            eventType = kIOHIDEventTypePower
        case .voltage:
            page = 0xff08
            usage = 0x0002
            eventType = kIOHIDEventTypePower
        case .power: break
        case .fan: break
        }
        
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            return list
        }
        let system: IOHIDEventSystemClient = client.takeRetainedValue()
        
        let dict = createDeviceMatchingDictionary(usagePage: page, usage: usage)
        IOHIDEventSystemClientSetMatching(system, dict)
        
        guard let services: CFArray = IOHIDEventSystemClientCopyServices(system) else {
            return list
        }
        
        for i in 0..<CFArrayGetCount(services) {
            var value = CFArrayGetValueAtIndex(services, i)
            
            withUnsafePointer(to: &value) { rawPtr in
                let service = UnsafeRawPointer(rawPtr).assumingMemoryBound(to: IOHIDServiceClientRef.self)
                let namePtr: Unmanaged<CFString>? = IOHIDServiceClientCopyProperty(service.pointee, "Product" as CFString)
                let eventPtr: IOHIDEventRef? = IOHIDServiceClientCopyEvent(service.pointee, Int64(eventType), 0, 0)
                
                guard let name = namePtr?.takeRetainedValue() else {
                    return
                }
                var value: Double? = nil
                
                if eventPtr != nil {
                    value = IOHIDEventGetFloatValue(eventPtr, eventType << 16)
                }
                
                if let value = value {
                    list[name as String] = value
                }
            }
        }
        
        return list
    }
    
    private func createDeviceMatchingDictionary(usagePage: Int, usage: Int) -> CFMutableDictionary {
        let dict = [
            kIOHIDPrimaryUsageKey: usage,
            kIOHIDPrimaryUsagePageKey: usagePage
        ] as NSDictionary
        
        return dict.mutableCopy() as! NSMutableDictionary
    }
}
