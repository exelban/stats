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

public enum SensorGroup: String, Codable {
    case CPU = "CPU"
    case GPU = "GPU"
    case system = "Systems"
    case sensor = "Sensors"
    case hid = "HID"
    case unknown = "Unknown"
}

public enum SensorType: String, Codable {
    case temperature = "Temperature"
    case voltage = "Voltage"
    case current = "Current"
    case power = "Power"
    case energy = "Energy"
    case fan = "Fans"
}

public protocol Sensor_p {
    var key: String { get }
    var name: String { get }
    var value: Double { get set }
    var state: Bool { get }
    var popupState: Bool { get }
    var notificationThreshold: String { get }
    
    var group: SensorGroup { get }
    var type: SensorType { get }
    var platforms: [Platform] { get }
    var isComputed: Bool { get }
    var average: Bool { get }
    
    var localValue: Double { get }
    var unit: String { get }
    var formattedValue: String { get }
    var formattedMiniValue: String { get }
    var formattedPopupValue: String { get }
}

public class Sensors_List: Codable {
    private var queue: DispatchQueue = DispatchQueue(label: "eu.exelban.Stats.Sensors.SynchronizedArray", attributes: .concurrent)
    
    private var list: [Sensor_p] = []
    public var sensors: [Sensor_p] {
        get {
            self.queue.sync{ self.list }
        }
        set {
            self.queue.async(flags: .barrier) {
                self.list = newValue
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case sensors
    }
    
    public init() {}
    
    public func encode(to encoder: Encoder) throws {
        let wrappers = sensors.map { Sensor_w($0) }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wrappers, forKey: .sensors)
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wrappers = try container.decode([Sensor_w].self, forKey: .sensors)
        self.sensors = wrappers.map { $0.sensor }
    }
}

public struct Sensor_w: Codable {
    let sensor: Sensor_p
    
    private enum CodingKeys: String, CodingKey {
        case base, payload
    }
    
    private enum Typ: Int, Codable {
        case sensor
        case fan
    }
    
    init(_ sensor: Sensor_p) {
        self.sensor = sensor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = try container.decode(Typ.self, forKey: .base)
        switch base {
        case .sensor: self.sensor = try container.decode(Sensor.self, forKey: .payload)
        case .fan: self.sensor = try container.decode(Fan.self, forKey: .payload)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch sensor {
        case let payload as Sensor:
            try container.encode(Typ.sensor, forKey: .base)
            try container.encode(payload, forKey: .payload)
        case let payload as Fan:
            try container.encode(Typ.fan, forKey: .base)
            try container.encode(payload, forKey: .payload)
        default: break
        }
    }
}

public struct Sensor: Sensor_p, Codable {
    public var key: String
    public var name: String
    
    public var value: Double = 0
    
    public var group: SensorGroup
    public var type: SensorType
    public var platforms: [Platform]
    public var isComputed: Bool = false
    public var average: Bool = false
    
    public var unit: String {
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
            return "RPM"
        }
    }
    
    public var formattedValue: String {
        switch self.type {
        case .temperature:
            return temperature(value)
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
    public var formattedPopupValue: String {
        switch self.type {
        case .temperature:
            return temperature(value, fractionDigits: 1)
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
    public var formattedMiniValue: String {
        switch self.type {
        case .temperature:
            return temperature(value).replacingOccurrences(of: "C", with: "").replacingOccurrences(of: "F", with: "")
        case .voltage, .power, .energy, .current:
            let val = value >= 9.95 ? "\(Int(round(value)))" : String(format: "%.1f", value)
            return "\(val)\(unit)"
        case .fan:
            return "\(Int(value))"
        }
    }
    public var localValue: Double {
        if self.type == .temperature {
            return Double(self.formattedMiniValue.digits) ?? self.value
        }
        return self.value
    }
    
    public var state: Bool {
        Store.shared.bool(key: "sensor_\(self.key)", defaultValue: false)
    }
    public var popupState: Bool {
        Store.shared.bool(key: "sensor_\(self.key)_popup", defaultValue: true)
    }
    public var notificationThreshold: String {
        Store.shared.string(key: "sensor_\(self.key)_notification", defaultValue: "")
    }
    
    public func copy() -> Sensor {
        Sensor(
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

public struct Fan: Sensor_p, Codable {
    public let id: Int
    public var key: String
    public var name: String
    public var minSpeed: Double
    public var maxSpeed: Double
    public var value: Double
    public var mode: FanMode
    
    public var percentage: Int {
        if self.value != 0 && self.maxSpeed != 0 && self.value != 1 && self.maxSpeed != 1 {
            return (100*Int(self.value)) / Int(self.maxSpeed)
        }
        return 0
    }
    
    public var group: SensorGroup = .sensor
    public var type: SensorType = .fan
    public var platforms: [Platform] = Platform.all
    public var isIntelOnly: Bool = false
    public var isComputed: Bool = false
    public var average: Bool = false
    public var unit: String = "RPM"
    
    public var formattedValue: String {
        "\(Int(self.value)) RPM"
    }
    public var formattedMiniValue: String {
        "\(Int(self.value))"
    }
    public var formattedPopupValue: String {
        "\(Int(self.value)) RPM"
    }
    public var localValue: Double {
        return self.value
    }
    
    public var state: Bool {
        Store.shared.bool(key: "sensor_\(self.key)", defaultValue: false)
    }
    public var popupState: Bool {
        Store.shared.bool(key: "sensor_\(self.key)_popup", defaultValue: true)
    }
    public var notificationThreshold: String {
        Store.shared.string(key: "sensor_\(self.key)_notification", defaultValue: "")
    }
    
    public var customSpeed: Int? {
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
    public var customMode: FanMode? {
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
    
    Sensor(key: "TTLD", name: "Thunderbolt left", group: .system, type: .temperature, platforms: Platform.all),
    Sensor(key: "TTRD", name: "Thunderbolt right", group: .system, type: .temperature, platforms: Platform.all),
    
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
    
    Sensor(key: "Tm02", name: "Memory 1", group: .sensor, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra]),
    Sensor(key: "Tm06", name: "Memory 2", group: .sensor, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra]),
    Sensor(key: "Tm08", name: "Memory 3", group: .sensor, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra]),
    Sensor(key: "Tm09", name: "Memory 4", group: .sensor, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra]),
    
    //M2
    Sensor(key: "Tp1h", name: "CPU efficiency core 1", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp1t", name: "CPU efficiency core 2", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp1p", name: "CPU efficiency core 3", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp1l", name: "CPU efficiency core 4", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
       
    Sensor(key: "Tp01", name: "CPU performance core 1", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp05", name: "CPU performance core 2", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp09", name: "CPU performance core 3", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp0D", name: "CPU performance core 4", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp0X", name: "CPU performance core 5", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp0b", name: "CPU performance core 6", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp0f", name: "CPU performance core 7", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tp0j", name: "CPU performance core 8", group: .CPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    
    Sensor(key: "Tg0f", name: "GPU 1", group: .GPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    Sensor(key: "Tg0j", name: "GPU 2", group: .GPU, type: .temperature, platforms: [.m2, .m2Max, .m2Pro, .m2Ultra], average: true),
    
    // M3
    Sensor(key: "Te05", name: "CPU efficiency core 1", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Te0L", name: "CPU efficiency core 2", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Te0P", name: "CPU efficiency core 3", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Te0S", name: "CPU efficiency core 4", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    
    Sensor(key: "Tf04", name: "CPU performance core 1", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf09", name: "CPU performance core 2", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf0A", name: "CPU performance core 3", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf0B", name: "CPU performance core 4", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf0D", name: "CPU performance core 5", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf0E", name: "CPU performance core 6", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf44", name: "CPU performance core 7", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf49", name: "CPU performance core 8", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf4A", name: "CPU performance core 9", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf4B", name: "CPU performance core 10", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf4D", name: "CPU performance core 11", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf4E", name: "CPU performance core 12", group: .CPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    
    Sensor(key: "Tf14", name: "GPU 1", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf18", name: "GPU 2", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf19", name: "GPU 3", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf1A", name: "GPU 4", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf24", name: "GPU 5", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf28", name: "GPU 6", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf29", name: "GPU 7", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    Sensor(key: "Tf2A", name: "GPU 8", group: .GPU, type: .temperature, platforms: [.m3, .m3Max, .m3Pro, .m3Ultra], average: true),
    
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
    Sensor(key: "PSTR", name: "System Total", group: .sensor, type: .power, platforms: Platform.all),
    
    Sensor(key: "PDBR", name: "Power Delivery Brightness", group: .sensor, type: .temperature, platforms: [.m1, .m1Pro, .m1Max, .m1Ultra])
]

internal let HIDSensorsList: [Sensor] = [
    Sensor(key: "pACC MTR Temp Sensor%", name: "CPU performance core %", group: .CPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "eACC MTR Temp Sensor%", name: "CPU efficiency core %", group: .CPU, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "GPU MTR Temp Sensor%", name: "GPU core %", group: .GPU, type: .temperature, platforms: Platform.all),
    Sensor(key: "SOC MTR Temp Sensor%", name: "SOC core %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "ANE MTR Temp Sensor%", name: "Neural engine %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "ISP MTR Temp Sensor%", name: "Image Signal Processor %", group: .sensor, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "PMGR SOC Die Temp Sensor%", name: "Power manager die %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "PMU tdev%", name: "Power management unit dev %", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "PMU tdie%", name: "Power management unit die %", group: .sensor, type: .temperature, platforms: Platform.all),
    
    Sensor(key: "gas gauge battery", name: "Battery", group: .sensor, type: .temperature, platforms: Platform.all),
    Sensor(key: "NAND CH% temp", name: "Disk %s", group: .GPU, type: .temperature, platforms: Platform.all)
]
