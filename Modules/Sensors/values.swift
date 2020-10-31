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

import StatsKit

typealias SensorGroup_t = String
enum SensorGroup: SensorGroup_t {
    case CPU = "CPU"
    case GPU = "GPU"
    case System = "Systems"
    case Sensor = "Sensors"
}

typealias SensorType_t = String
enum SensorType: SensorType_t {
    case Temperature = "Temperature"
    case Voltage = "Voltage"
    case Power = "Power"
}

struct Sensor_t {
    let store: Store = Store()
    var key: String
    var name: String
    
    var group: SensorGroup_t
    var type: SensorType_t
    var unit: String {
        get {
            switch self.type {
            case SensorType.Temperature.rawValue:
                return "°C"
            case SensorType.Voltage.rawValue:
                return "V"
            case SensorType.Power.rawValue:
                return "W"
            default: return ""
            }
        }
    }
    
    var value: Double? = nil
    
    var formattedValue: String {
        get {
            switch self.type {
            case SensorType.Temperature.rawValue:
                return Temperature(value ?? 0)
            case SensorType.Voltage.rawValue:
                return String(format: "%.3f \(unit)", value ?? 0)
            case SensorType.Power.rawValue:
                return String(format: "%.2f \(unit)", value ?? 0)
            default: return String(format: "%.2f", value ?? 0)
            }
        }
    }
    var formattedMiniValue: String {
        get {
            switch self.type {
            case SensorType.Temperature.rawValue:
                return Temperature(value ?? 0).replacingOccurrences(of: "C", with: "").replacingOccurrences(of: "F", with: "")
            case SensorType.Voltage.rawValue:
                return String(format: "%.1f\(unit)", value ?? 0)
            case SensorType.Power.rawValue:
                return String(format: "%.1f\(unit)", value ?? 0)
            default: return String(format: "%.1f", value ?? 0)
            }
        }
    }
    
    var state: Bool {
        get {
            return store.bool(key: "sensor_\(self.key)", defaultValue: false)
        }
    }
}

// List of keys: https://github.com/acidanthera/VirtualSMC/blob/master/Docs/SMCSensorKeys.txt
let SensorsList: [Sensor_t] = [
    /// Temperature
    Sensor_t(key: "TA0P", name: "Ambient 1", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TA1P", name: "Ambient 2", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "Th0H", name: "Heatpipe 1", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "Th1H", name: "Heatpipe 2", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "Th2H", name: "Heatpipe 3", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "Th3H", name: "Heatpipe 4", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TZ0C", name: "Termal zone 1", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TZ1C", name: "Termal zone 2", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    
    Sensor_t(key: "TC0D", name: "CPU diode", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC0E", name: "CPU diode virtual", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC0F", name: "CPU diode filtered", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC0C", name: "CPU core", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC0H", name: "CPU heatsink", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC0P", name: "CPU proximity", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TCAD", name: "CPU package", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    
    Sensor_t(key: "TC0c", name: "CPU core 1", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC1c", name: "CPU core 2", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC2c", name: "CPU core 3", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC3c", name: "CPU core 4", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC4c", name: "CPU core 5", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC5c", name: "CPU core 6", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC6c", name: "CPU core 7", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC7c", name: "CPU core 8", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC8c", name: "CPU core 9", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC9c", name: "CPU core 10", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    
    Sensor_t(key: "TC1C", name: "CPU core 1", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC2C", name: "CPU core 2", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC3C", name: "CPU core 3", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC4C", name: "CPU core 4", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC5C", name: "CPU core 5", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC6C", name: "CPU core 6", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC7C", name: "CPU core 7", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC8C", name: "CPU core 8", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TC9C", name: "CPU core 9", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    
    Sensor_t(key: "TCGC", name: "GPU Intel Graphics", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TG0D", name: "GPU diode", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TG0H", name: "GPU heatsink", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TG0P", name: "GPU proximity", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    
    Sensor_t(key: "Tm0P", name: "Mainboard", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "Tp0P", name: "Powerboard", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TB1T", name: "Battery", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TW0P", name: "Airport", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TL0P", name: "Display", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TI0P", name: "Thunderbold 1", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TI1P", name: "Thunderbold 2", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TI2P", name: "Thunderbold 3", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TI3P", name: "Thunderbold 4", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    
    Sensor_t(key: "TN0D", name: "Northbridge diode", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TN0H", name: "Northbridge heatsink", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    Sensor_t(key: "TN0P", name: "Northbridge proximity", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    
     /// Voltage
    Sensor_t(key: "VCAC", name: "CPU IA", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VCSC", name: "CPU System Agent", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC0C", name: "CPU Core 1", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC1C", name: "CPU Core 2", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC2C", name: "CPU Core 3", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC3C", name: "CPU Core 4", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC4C", name: "CPU Core 5", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC5C", name: "CPU Core 6", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC6C", name: "CPU Core 7", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC7C", name: "CPU Core 8", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC8C", name: "CPU Core 9", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VC9C", name: "CPU Core 10", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    
    Sensor_t(key: "VCTC", name: "GPU Intel Graphics", group: SensorGroup.GPU.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VG0C", name: "GPU", group: SensorGroup.GPU.rawValue, type: SensorType.Voltage.rawValue),
    
    Sensor_t(key: "VM0R", name: "Memory", group: SensorGroup.System.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "Vb0R", name: "CMOS", group: SensorGroup.System.rawValue, type: SensorType.Voltage.rawValue),
    
    Sensor_t(key: "VD0R", name: "DC In", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VP0R", name: "12V rail", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "Vp0C", name: "12V vcc", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VV2S", name: "3V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VR3R", name: "3.3V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VV1S", name: "5V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VV9S", name: "12V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    Sensor_t(key: "VeES", name: "PCI 12V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    
     /// Power
    Sensor_t(key: "PC0C", name: "CPU Core", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCAM", name: "CPU Core (IMON)", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCPC", name: "CPU Package", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCTR", name: "CPU Total", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCPT", name: "CPU Package total", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCPR", name: "CPU Package total (SMC)", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PC0R", name: "CPU Computing high side", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PC0G", name: "CPU GFX", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCEC", name: "CPU VccEDRAM", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    
    Sensor_t(key: "PCPG", name: "GPU Intel Graphics", group: SensorGroup.GPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PG0R", name: "GPU", group: SensorGroup.GPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCGC", name: "Intel GPU", group: SensorGroup.GPU.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PCGM", name: "Intel GPU (IMON)", group: SensorGroup.GPU.rawValue, type: SensorType.Power.rawValue),
    
    Sensor_t(key: "PC3C", name: "RAM", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PPBR", name: "Battery", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PDTR", name: "DC In", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
    Sensor_t(key: "PSTR", name: "System total", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
]
