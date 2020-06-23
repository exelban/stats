//
//  values.swift
//  Stats
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
    case Frequency = "Frequency"
    case Battery = "Battery"
}

struct Sensor_t {
    let store: Store = Store()
    var name: String
    var key: String = ""
    
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
                let formatter = MeasurementFormatter()
                formatter.numberFormatter.maximumFractionDigits = 0
                return formatter.string(from: (value ?? 0).localizeTemperature())
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
                return String(format: "%.0f°", value?.localizeTemperature().value ?? 0)
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
let SensorsDict: [String: Sensor_t] = [
    /// Temperature
    "TA0P": Sensor_t(name: "Ambient 1", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "TA1P": Sensor_t(name: "Ambient 2", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "Th0H": Sensor_t(name: "Heatpipe 1", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "Th1H": Sensor_t(name: "Heatpipe 2", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "Th2H": Sensor_t(name: "Heatpipe 3", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "Th3H": Sensor_t(name: "Heatpipe 4", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "TZ0C": Sensor_t(name: "Termal zone 1", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    "TZ1C": Sensor_t(name: "Termal zone 2", group: SensorGroup.Sensor.rawValue, type: SensorType.Temperature.rawValue),
    
    "TC0E": Sensor_t(name: "CPU 1", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC0F": Sensor_t(name: "CPU 2", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC0D": Sensor_t(name: "CPU die", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC0C": Sensor_t(name: "CPU core", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC0H": Sensor_t(name: "CPU heatsink", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC0P": Sensor_t(name: "CPU proximity", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TCAD": Sensor_t(name: "CPU package", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    
    "TC1C": Sensor_t(name: "CPU core 1", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC2C": Sensor_t(name: "CPU core 2", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC3C": Sensor_t(name: "CPU core 3", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC4C": Sensor_t(name: "CPU core 4", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC5C": Sensor_t(name: "CPU core 5", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC6C": Sensor_t(name: "CPU core 6", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC7C": Sensor_t(name: "CPU core 7", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    "TC8C": Sensor_t(name: "CPU core 8", group: SensorGroup.CPU.rawValue, type: SensorType.Temperature.rawValue),
    
    "TCGC": Sensor_t(name: "GPU Intel Graphics", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    "TG0D": Sensor_t(name: "GPU die", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    "TG0H": Sensor_t(name: "GPU heatsink", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    "TG0P": Sensor_t(name: "GPU proximity", group: SensorGroup.GPU.rawValue, type: SensorType.Temperature.rawValue),
    
    "Tm0P": Sensor_t(name: "Mainboard", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "Tp0P": Sensor_t(name: "Powerboard", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TB1T": Sensor_t(name: "Battery", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TW0P": Sensor_t(name: "Airport", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TL0P": Sensor_t(name: "Display", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TI0P": Sensor_t(name: "Thunderbold 1", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TI1P": Sensor_t(name: "Thunderbold 2", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TI2P": Sensor_t(name: "Thunderbold 3", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TI3P": Sensor_t(name: "Thunderbold 4", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    
    "TN0D": Sensor_t(name: "Northbridge die", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TN0H": Sensor_t(name: "Northbridge heatsink", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    "TN0P": Sensor_t(name: "Northbridge proximity", group: SensorGroup.System.rawValue, type: SensorType.Temperature.rawValue),
    
    /// Voltage
    "VCAC": Sensor_t(name: "CPU IA", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VCSC": Sensor_t(name: "CPU System Agent", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC0C": Sensor_t(name: "CPU Core 1", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC1C": Sensor_t(name: "CPU Core 2", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC2C": Sensor_t(name: "CPU Core 3", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC3C": Sensor_t(name: "CPU Core 4", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC4C": Sensor_t(name: "CPU Core 5", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC5C": Sensor_t(name: "CPU Core 6", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC6C": Sensor_t(name: "CPU Core 7", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    "VC7C": Sensor_t(name: "CPU Core 8", group: SensorGroup.CPU.rawValue, type: SensorType.Voltage.rawValue),
    
    "VCTC": Sensor_t(name: "GPU Intel Graphics", group: SensorGroup.GPU.rawValue, type: SensorType.Voltage.rawValue),
    "VG0C": Sensor_t(name: "GPU", group: SensorGroup.GPU.rawValue, type: SensorType.Voltage.rawValue),
    
    "VM0R": Sensor_t(name: "Memory", group: SensorGroup.System.rawValue, type: SensorType.Voltage.rawValue),
    "Vb0R": Sensor_t(name: "CMOS", group: SensorGroup.System.rawValue, type: SensorType.Voltage.rawValue),
    
    "VD0R": Sensor_t(name: "DC In", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "VP0R": Sensor_t(name: "12V rail", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "Vp0C": Sensor_t(name: "12V vcc", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "VV2S": Sensor_t(name: "3V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "VR3R": Sensor_t(name: "3.3V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "VV1S": Sensor_t(name: "5V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "VV9S": Sensor_t(name: "12V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    "VeES": Sensor_t(name: "PCI 12V", group: SensorGroup.Sensor.rawValue, type: SensorType.Voltage.rawValue),
    
    /// Power
    "PC0C": Sensor_t(name: "CPU Core", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    "PCPC": Sensor_t(name: "CPU Package", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    "PCPT": Sensor_t(name: "CPU Package total", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    "PC0R": Sensor_t(name: "CPU Computing high side", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    "PC0G": Sensor_t(name: "CPU GFX", group: SensorGroup.CPU.rawValue, type: SensorType.Power.rawValue),
    
    "PCPG": Sensor_t(name: "GPU Intel Graphics", group: SensorGroup.GPU.rawValue, type: SensorType.Power.rawValue),
    "PG0R": Sensor_t(name: "GPU", group: SensorGroup.GPU.rawValue, type: SensorType.Power.rawValue),
    
    "PPBR": Sensor_t(name: "Battery", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
    "PDTR": Sensor_t(name: "DC In", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
    "PSTR": Sensor_t(name: "System total", group: SensorGroup.Sensor.rawValue, type: SensorType.Power.rawValue),
    
    /// Frequency
    "FRC0": Sensor_t(name: "CPU 1", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC1": Sensor_t(name: "CPU 2", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC2": Sensor_t(name: "CPU 3", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC3": Sensor_t(name: "CPU 4", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC4": Sensor_t(name: "CPU 5", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC5": Sensor_t(name: "CPU 6", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC6": Sensor_t(name: "CPU 7", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    "FRC7": Sensor_t(name: "CPU 8", group: SensorGroup.CPU.rawValue, type: SensorType.Frequency.rawValue),
    
    "CG0C": Sensor_t(name: "GPU", group: SensorGroup.GPU.rawValue, type: SensorType.Frequency.rawValue),
    "CG0S": Sensor_t(name: "GPU shader", group: SensorGroup.GPU.rawValue, type: SensorType.Frequency.rawValue),
    "CG0M": Sensor_t(name: "GPU memory", group: SensorGroup.GPU.rawValue, type: SensorType.Frequency.rawValue),
    
    /// Battery
    "B0AV": Sensor_t(name: "Voltage", group: SensorGroup.Sensor.rawValue, type: SensorType.Battery.rawValue),
    "B0AC": Sensor_t(name: "Amperage", group: SensorGroup.Sensor.rawValue, type: SensorType.Battery.rawValue),
]
