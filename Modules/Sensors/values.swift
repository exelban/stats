//
//  values.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Kit

enum SensorGroup: String {
    case CPU = "CPU"
    case GPU = "GPU"
    case system = "Systems"
    case sensor = "Sensors"
}

enum SensorType: String {
    case temperature = "Temperature"
    case voltage = "Voltage"
    case current = "Current"
    case power = "Power"
    case fan = "Fan"
}

struct Sensor_t {
    var key: String
    var name: String
    
    var value: Double = 0
    
    var group: SensorGroup
    var type: SensorType
    var unit: String {
        get {
            switch self.type {
            case .temperature:
                return "°C"
            case .voltage:
                return "V"
            case .power:
                return "W"
            case .current:
                return "A"
            case .fan:
                return "RPM"
            }
        }
    }
    
    var formattedValue: String {
        get {
            switch self.type {
            case .temperature:
                return Temperature(value)
            case .voltage:
                let val = value >= 100 ? "\(Int(value))" : String(format: "%.3f", value)
                return "\(val)\(unit)"
            case .power:
                let val = value >= 100 ? "\(Int(value))" : String(format: "%.2f", value)
                return "\(val)\(unit)"
            case .current:
                let val = value >= 100 ? "\(Int(value))" : String(format: "%.2f", value)
                return "\(val)\(unit)"
            case .fan:
                return "\(Int(value)) \(unit)"
            }
        }
    }
    var formattedMiniValue: String {
        get {
            switch self.type {
            case .temperature:
                return Temperature(value).replacingOccurrences(of: "C", with: "").replacingOccurrences(of: "F", with: "")
            case .voltage:
                let val = value >= 10 ? "\(Int(value))" : String(format: "%.1f", value)
                return "\(val)\(unit)"
            case .power:
                let val = value >= 10 ? "\(Int(value))" : String(format: "%.1f", value)
                return "\(val)\(unit)"
            case .current:
                let val = value >= 10 ? "\(Int(value))" : String(format: "%.1f", value)
                return "\(val)\(unit)"
            case .fan:
                return "\(Int(value))"
            }
        }
    }
    
    var state: Bool {
        get {
            return Store.shared.bool(key: "sensor_\(self.key)", defaultValue: false)
        }
    }
    
    func copy() -> Sensor_t {
        return Sensor_t(key: self.key, name: self.name, group: self.group, type: self.type)
    }
}

// List of keys: https://github.com/acidanthera/VirtualSMC/blob/master/Docs/SMCSensorKeys.txt
let SensorsList: [Sensor_t] = [
    // Temperature
    Sensor_t(key: "TA%P", name: "Ambient %", group: .sensor, type: .temperature),
    Sensor_t(key: "Th%H", name: "Heatpipe %", group: .sensor, type: .temperature),
    Sensor_t(key: "TZ%C", name: "Termal zone %", group: .sensor, type: .temperature),
    
    Sensor_t(key: "TC0D", name: "CPU diode", group: .CPU, type: .temperature),
    Sensor_t(key: "TC0E", name: "CPU diode virtual", group: .CPU, type: .temperature),
    Sensor_t(key: "TC0F", name: "CPU diode filtered", group: .CPU, type: .temperature),
    Sensor_t(key: "TC0H", name: "CPU heatsink", group: .CPU, type: .temperature),
    Sensor_t(key: "TC0P", name: "CPU proximity", group: .CPU, type: .temperature),
    Sensor_t(key: "TCAD", name: "CPU package", group: .CPU, type: .temperature),
    
    Sensor_t(key: "TC%c", name: "CPU core %", group: .CPU, type: .temperature),
    Sensor_t(key: "TC%C", name: "CPU core %", group: .CPU, type: .temperature),
    
    Sensor_t(key: "TCGC", name: "GPU Intel Graphics", group: .GPU, type: .temperature),
    Sensor_t(key: "TG0D", name: "GPU diode", group: .GPU, type: .temperature),
    Sensor_t(key: "TGDD", name: "GPU AMD Radeon", group: .GPU, type: .temperature),
    Sensor_t(key: "TG0H", name: "GPU heatsink", group: .GPU, type: .temperature),
    Sensor_t(key: "TG0P", name: "GPU proximity", group: .GPU, type: .temperature),
    
    Sensor_t(key: "Tm0P", name: "Mainboard", group: .system, type: .temperature),
    Sensor_t(key: "Tp0P", name: "Powerboard", group: .system, type: .temperature),
    Sensor_t(key: "TB1T", name: "Battery", group: .system, type: .temperature),
    Sensor_t(key: "TW0P", name: "Airport", group: .system, type: .temperature),
    Sensor_t(key: "TL0P", name: "Display", group: .system, type: .temperature),
    Sensor_t(key: "TI%P", name: "Thunderbold %", group: .system, type: .temperature),
    
    Sensor_t(key: "TN0D", name: "Northbridge diode", group: .system, type: .temperature),
    Sensor_t(key: "TN0H", name: "Northbridge heatsink", group: .system, type: .temperature),
    Sensor_t(key: "TN0P", name: "Northbridge proximity", group: .system, type: .temperature),
    
    // Voltage
    Sensor_t(key: "VCAC", name: "CPU IA", group: .CPU, type: .voltage),
    Sensor_t(key: "VCSC", name: "CPU System Agent", group: .CPU, type: .voltage),
    Sensor_t(key: "VC%C", name: "CPU Core %", group: .CPU, type: .voltage),
    
    Sensor_t(key: "VCTC", name: "GPU Intel Graphics", group: .GPU, type: .voltage),
    Sensor_t(key: "VG0C", name: "GPU", group: .GPU, type: .voltage),
    
    Sensor_t(key: "VM0R", name: "Memory", group: .system, type: .voltage),
    Sensor_t(key: "Vb0R", name: "CMOS", group: .system, type: .voltage),
    
    Sensor_t(key: "VD0R", name: "DC In", group: .sensor, type: .voltage),
    Sensor_t(key: "VP0R", name: "12V rail", group: .sensor, type: .voltage),
    Sensor_t(key: "Vp0C", name: "12V vcc", group: .sensor, type: .voltage),
    Sensor_t(key: "VV2S", name: "3V", group: .sensor, type: .voltage),
    Sensor_t(key: "VR3R", name: "3.3V", group: .sensor, type: .voltage),
    Sensor_t(key: "VV1S", name: "5V", group: .sensor, type: .voltage),
    Sensor_t(key: "VV9S", name: "12V", group: .sensor, type: .voltage),
    Sensor_t(key: "VeES", name: "PCI 12V", group: .sensor, type: .voltage),
    
    // Power
    Sensor_t(key: "PC0C", name: "CPU Core", group: .CPU, type: .power),
    Sensor_t(key: "PCAM", name: "CPU Core (IMON)", group: .CPU, type: .power),
    Sensor_t(key: "PCPC", name: "CPU Package", group: .CPU, type: .power),
    Sensor_t(key: "PCTR", name: "CPU Total", group: .CPU, type: .power),
    Sensor_t(key: "PCPT", name: "CPU Package total", group: .CPU, type: .power),
    Sensor_t(key: "PCPR", name: "CPU Package total (SMC)", group: .CPU, type: .power),
    Sensor_t(key: "PC0R", name: "CPU Computing high side", group: .CPU, type: .power),
    Sensor_t(key: "PC0G", name: "CPU GFX", group: .CPU, type: .power),
    Sensor_t(key: "PCEC", name: "CPU VccEDRAM", group: .CPU, type: .power),
    
    Sensor_t(key: "PCPG", name: "GPU Intel Graphics", group: .GPU, type: .power),
    Sensor_t(key: "PG0R", name: "GPU", group: .GPU, type: .power),
    Sensor_t(key: "PCGC", name: "Intel GPU", group: .GPU, type: .power),
    Sensor_t(key: "PCGM", name: "Intel GPU (IMON)", group: .GPU, type: .power),
    
    Sensor_t(key: "PC3C", name: "RAM", group: .sensor, type: .power),
    Sensor_t(key: "PPBR", name: "Battery", group: .sensor, type: .power),
    Sensor_t(key: "PDTR", name: "DC In", group: .sensor, type: .power),
    Sensor_t(key: "PSTR", name: "System total", group: .sensor, type: .power),
    
    // Fans
    Sensor_t(key: "F%Ac", name: "Fan #%", group: .sensor, type: .fan)
]
