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
import Cocoa

internal enum SensorGroup: String {
    case CPU = "CPU"
    case GPU = "GPU"
    case system = "Systems"
    case sensor = "Sensors"
    case hid = "HID"
    case unknown = "Unknown"
}

internal enum SensorType: String {
    case temperature = "Temperature"
    case voltage = "Voltage"
    case current = "Current"
    case power = "Power"
    case energy = "Energy"
    case fan = "Fans"
}

internal protocol Sensor_p {
    var key: String { get }
    var name: String { get }
    var value: Double { get set }
    var state: Bool { get }
    
    var group: SensorGroup { get }
    var type: SensorType { get }
    var platforms: [Platform] { get }
    var isComputed: Bool { get }
    var average: Bool { get }
    
    var unit: String { get }
    var formattedValue: String { get }
    var formattedMiniValue: String { get }
    var formattedPopupValue: String { get }
}

internal struct Sensor: Sensor_p {
    var key: String
    var name: String
    
    var value: Double = 0
    
    var group: SensorGroup
    var type: SensorType
    var platforms: [Platform]
    var isComputed: Bool = false
    var average: Bool = false
    
    var unit: String {
        get {
            switch self.type {
            case .temperature:
                return UnitTemperature.current.symbol
            case .voltage:
                return "V"
            case .power:
                return "W"
            case .energy:
                return "Wh"
            case .current:
                return "A"
            case .fan:
                return "%"
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
            case .power, .energy:
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
    var formattedPopupValue: String {
        get {
            switch self.type {
            case .temperature:
                return Temperature(value, fractionDigits: 1)
            case .voltage:
                let val = value >= 100 ? "\(Int(value))" : String(format: "%.3f", value)
                return "\(val)\(unit)"
            case .power, .energy:
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
            case .voltage, .power, .energy, .current:
                let val = value >= 9.95 ? "\(Int(round(value)))" : String(format: "%.1f", value)
                return "\(val)\(unit)"
            case .fan:
                return "\(Int(value))\(unit)"
            }
        }
    }
    
    var state: Bool {
        get {
            return Store.shared.bool(key: "sensor_\(self.key)", defaultValue: false)
        }
    }
    
    func copy() -> Sensor {
        return Sensor(
            key: self.key,
            name: self.name,
            group: self.group,
            type: self.type,
            platforms: self.platforms,
            isComputed: self.isComputed,
            average: self.average
        )
    }
}

internal struct Fan: Sensor_p {
    let id: Int
    var key: String
    var name: String
    let minSpeed: Double
    let maxSpeed: Double
    var value: Double
    var mode: FanMode
    
    var percentage: Int {
        if self.value != 0 && self.maxSpeed != 0 && self.value != 1 && self.maxSpeed != 1 {
            return (100*Int(self.value)) / Int(self.maxSpeed)
        }
        return 0
    }
    
    var group: SensorGroup = .sensor
    var type: SensorType = .fan
    var platforms: [Platform] = Platform.all
    var isIntelOnly: Bool = false
    var isComputed: Bool = false
    var average: Bool = false
    var unit: String = "RPM"
    
    var formattedValue: String {
        "\(Int(value)) RPM"
    }
    var formattedMiniValue: String {
        return "\(Int(value))"
    }
    var formattedPopupValue: String {
        "\(Int(value)) RPM"
    }
    
    var state: Bool {
        Store.shared.bool(key: "sensor_\(self.key)", defaultValue: false)
    }
    
    var customSpeed: Int? {
        get {
            if !Store.shared.exist(key: "fan_\(self.id)_speed") {
                return nil
            }
            return Store.shared.int(key: "fan_\(self.id)_speed", defaultValue: Int(self.minSpeed))
        }
        set {
            if let value = newValue {
                Store.shared.set(key: "fan_\(self.id)_speed", value: value)
            } else {
                Store.shared.remove("fan_\(self.id)_speed")
            }
        }
    }
    var customMode: FanMode? {
        get {
            if !Store.shared.exist(key: "fan_\(self.id)_mode") {
                return nil
            }
            let value = Store.shared.int(key: "fan_\(self.id)_mode", defaultValue: FanMode.automatic.rawValue)
            return FanMode(rawValue: value)
        }
        set {
            if let value = newValue {
                Store.shared.set(key: "fan_\(self.id)_mode", value: value.rawValue)
            } else {
                Store.shared.remove("fan_\(self.id)_mode")
            }
        }
    }
}

// List of keys: https://github.com/acidanthera/VirtualSMC/blob/master/Docs/SMCSensorKeys.txt
internal let SensorsList: [Sensor] = [
    // Temperature
    Sensor(key: "TA%P", name: "Ambient %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "Th%H", name: "Heatpipe %", group: .sensor, type: .temperature, platforms: [.intel]),
    Sensor(key: "TZ%C", name: "Thermal zone %", group: .sensor, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "TC0D", name: "CPU diode", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TC0E", name: "CPU diode virtual", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TC0F", name: "CPU diode filtered", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TC0H", name: "CPU heatsink", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TC0P", name: "CPU proximity", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TCAD", name: "CPU package", group: .CPU, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "TC%c", name: "CPU core %", group: .CPU, type: .temperature, platforms: Platform.all, average: true),
    Sensor(key: "TC%C", name: "CPU Core %", group: .CPU, type: .temperature, platforms: Platform.all, average: true),
    
    Sensor(key: "TCGC", name: "GPU Intel Graphics", group: .GPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TG0D", name: "GPU diode", group: .GPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TGDD", name: "GPU AMD Radeon", group: .GPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TG0H", name: "GPU heatsink", group: .GPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "TG0P", name: "GPU proximity", group: .GPU, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "Tm0P", name: "Mainboard", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "Tp0P", name: "Powerboard", group: .system, type: .temperature, platforms: [.intel]),
    Sensor(key: "TB1T", name: "Battery", group: .system, type: .temperature, platforms: [.intel]),
    Sensor(key: "TW0P", name: "Airport", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TL0P", name: "Display", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TI%P", name: "Thunderbolt %", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TH%A", name: "Disk % (A)", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TH%B", name: "Disk % (B)", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TH%C", name: "Disk % (C)", group: .system, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "TN0D", name: "Northbridge diode", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TN0H", name: "Northbridge heatsink", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TN0P", name: "Northbridge proximity", group: .system, type: .temperature, platforms: Platform.all),
    
    // Apple Silicon
    Sensor(key: "Tp09", name: "CPU efficiency core 1", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0T", name: "CPU efficiency core 2", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp01", name: "CPU performance core 1", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp05", name: "CPU performance core 2", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0D", name: "CPU performance core 3", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0H", name: "CPU performance core 4", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0L", name: "CPU performance core 5", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0P", name: "CPU performance core 6", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0X", name: "CPU performance core 7", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tp0b", name: "CPU performance core 8", group: .CPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    
    Sensor(key: "Tg05", name: "GPU 1", group: .GPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tg0D", name: "GPU 2", group: .GPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tg0L", name: "GPU 3", group: .GPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    Sensor(key: "Tg0T", name: "GPU 4", group: .GPU, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra], average: true),
    
    // M2
    Sensor(key: "Tp05", name: "CPU efficiency core 1", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tp0D", name: "CPU efficiency core 2", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tp0j", name: "CPU efficiency core 3", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tp0r", name: "CPU efficiency core 4", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    
    Sensor(key: "Tp01", name: "CPU performance core 1", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tp09", name: "CPU performance core 2", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tp0f", name: "CPU performance core 3", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tp0n", name: "CPU performance core 4", group: .CPU, type: .temperature, platforms: [.m2], average: true),
    
    Sensor(key: "Tg0f", name: "GPU 1", group: .GPU, type: .temperature, platforms: [.m2], average: true),
    Sensor(key: "Tg0n", name: "GPU 2", group: .GPU, type: .temperature, platforms: [.m2], average: true),
    
    Sensor(key: "TaLP", name: "Airflow left", group: .sensor, type: .temperature, platforms: Platform.apple),
    Sensor(key: "TaRF", name: "Airflow right", group: .sensor, type: .temperature, platforms: Platform.apple),
    
    Sensor(key: "TH0x", name: "NAND", group: .system, type: .temperature, platforms: Platform.apple),
    Sensor(key: "TB1T", name: "Battery 1", group: .system, type: .temperature, platforms: Platform.apple),
    Sensor(key: "TB2T", name: "Battery 2", group: .system, type: .temperature, platforms: Platform.apple),
    Sensor(key: "TW0P", name: "Airport", group: .system, type: .temperature, platforms: Platform.apple),
    
    // Voltage
    Sensor(key: "VCAC", name: "CPU IA", group: .CPU, type: .voltage, platforms: Platform.all),
    Sensor(key: "VCSC", name: "CPU System Agent", group: .CPU, type: .voltage, platforms: Platform.all),
    Sensor(key: "VC%C", name: "CPU Core %", group: .CPU, type: .voltage, platforms: Platform.all),
    
    Sensor(key: "VCTC", name: "GPU Intel Graphics", group: .GPU, type: .voltage, platforms: Platform.all),
    Sensor(key: "VG0C", name: "GPU", group: .GPU, type: .voltage, platforms: Platform.all),
    
    Sensor(key: "VM0R", name: "Memory", group: .system, type: .voltage, platforms: Platform.all),
    Sensor(key: "Vb0R", name: "CMOS", group: .system, type: .voltage, platforms: Platform.all),
    
    Sensor(key: "VD0R", name: "DC In", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "VP0R", name: "12V rail", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "Vp0C", name: "12V vcc", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "VV2S", name: "3V", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "VR3R", name: "3.3V", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "VV1S", name: "5V", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "VV9S", name: "12V", group: .sensor, type: .voltage, platforms: Platform.all),
    Sensor(key: "VeES", name: "PCI 12V", group: .sensor, type: .voltage, platforms: Platform.all),
    
    // Current
    Sensor(key: "IC0R", name: "CPU High side", group: .sensor, type: .current, platforms: Platform.all),
    Sensor(key: "IG0R", name: "GPU High side", group: .sensor, type: .current, platforms: Platform.all),
    Sensor(key: "ID0R", name: "DC In", group: .sensor, type: .current, platforms: Platform.all),
    Sensor(key: "IBAC", name: "Battery", group: .sensor, type: .current, platforms: Platform.all),
    
    // Power
    Sensor(key: "PC0C", name: "CPU Core", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCAM", name: "CPU Core (IMON)", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCPC", name: "CPU Package", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCTR", name: "CPU Total", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCPT", name: "CPU Package total", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCPR", name: "CPU Package total (SMC)", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PC0R", name: "CPU Computing high side", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PC0G", name: "CPU GFX", group: .CPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCEC", name: "CPU VccEDRAM", group: .CPU, type: .power, platforms: Platform.all),
    
    Sensor(key: "PCPG", name: "GPU Intel Graphics", group: .GPU, type: .power, platforms: Platform.all),
    Sensor(key: "PG0R", name: "GPU", group: .GPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCGC", name: "Intel GPU", group: .GPU, type: .power, platforms: Platform.all),
    Sensor(key: "PCGM", name: "Intel GPU (IMON)", group: .GPU, type: .power, platforms: Platform.all),
    
    Sensor(key: "PC3C", name: "RAM", group: .sensor, type: .power, platforms: Platform.all),
    Sensor(key: "PPBR", name: "Battery", group: .sensor, type: .power, platforms: Platform.all),
    Sensor(key: "PDTR", name: "DC In", group: .sensor, type: .power, platforms: Platform.all),
    Sensor(key: "PSTR", name: "System Total", group: .sensor, type: .power, platforms: Platform.all)
]

internal let HIDSensorsList: [Sensor] = [
    Sensor(key: "pACC MTR Temp Sensor%", name: "CPU performance core %", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "eACC MTR Temp Sensor%", name: "CPU efficiency core %", group: .CPU, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "GPU MTR Temp Sensor%", name: "GPU core %", group: .GPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "SOC MTR Temp Sensor%", name: "SOC core %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "ANE MTR Temp Sensor%", name: "Neural engine %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "ISP MTR Temp Sensor%", name: "Airport %", group: .sensor, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "PMGR SOC Die Temp Sensor%", name: "Power manager die %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "PMU tdev%", name: "Power management unit dev %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "PMU tdie%", name: "Power management unit die %", group: .sensor, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "gas gauge battery", name: "Battery", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "NAND CH% temp", name: "Disk %s", group: .GPU, type: .temperature, platforms: Platform.all)
]
