//
//  types.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public struct DoubleValue {
    public var ts: Date = Date()
    public let value: Double
    
    public init(_ value: Double = 0) {
        self.value = value
    }
}
extension [DoubleValue] {
    public func max() -> Double? { self.max(by: { $0.value < $1.value })?.value }
}

public struct ColorValue: Equatable {
    public let value: Double
    public let color: NSColor?
    
    public init(_ value: Double, color: NSColor? = nil) {
        self.value = value
        self.color = color
    }
    
    // swiftlint:disable operator_whitespace
    public static func ==(lhs: ColorValue, rhs: ColorValue) -> Bool {
        return lhs.value == rhs.value
    }
    // swiftlint:enable operator_whitespace
}

public enum AppUpdateInterval: String {
    case silent = "Silent"
    case atStart = "At start"
    case separator1 = "separator_1"
    case oncePerDay = "Once per day"
    case oncePerWeek = "Once per week"
    case oncePerMonth = "Once per month"
    case separator2 = "separator_2"
    case never = "Never"
}
public let AppUpdateIntervals: [KeyValue_t] = [
    KeyValue_t(key: "Silent", value: AppUpdateInterval.silent.rawValue),
    KeyValue_t(key: "At start", value: AppUpdateInterval.atStart.rawValue),
    KeyValue_t(key: "separator_1", value: "separator_1"),
    KeyValue_t(key: "Once per day", value: AppUpdateInterval.oncePerDay.rawValue),
    KeyValue_t(key: "Once per week", value: AppUpdateInterval.oncePerWeek.rawValue),
    KeyValue_t(key: "Once per month", value: AppUpdateInterval.oncePerMonth.rawValue),
    KeyValue_t(key: "separator_2", value: "separator_2"),
    KeyValue_t(key: "Never", value: AppUpdateInterval.never.rawValue)
]

public let TemperatureUnits: [KeyValue_t] = [
    KeyValue_t(key: "system", value: "System"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "celsius", value: "Celsius", additional: UnitTemperature.celsius),
    KeyValue_t(key: "fahrenheit", value: "Fahrenheit", additional: UnitTemperature.fahrenheit)
]

public let CombinedModulesSpacings: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "1", value: "1", additional: 1),
    KeyValue_t(key: "2", value: "2", additional: 2),
    KeyValue_t(key: "3", value: "3", additional: 3),
    KeyValue_t(key: "4", value: "4", additional: 4),
    KeyValue_t(key: "5", value: "5", additional: 5),
    KeyValue_t(key: "6", value: "6", additional: 6),
    KeyValue_t(key: "7", value: "7", additional: 7),
    KeyValue_t(key: "8", value: "8", additional: 8)
]

public let PublicIPAddressRefreshIntervals: [KeyValue_t] = [
    KeyValue_t(key: "never", value: "Never"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "hour", value: "Every hour"),
    KeyValue_t(key: "12", value: "Every 12 hours"),
    KeyValue_t(key: "24", value: "Every 24 hours")
]

public enum DataSizeBase: String {
    case bit
    case byte
}
public let SpeedBase: [KeyValue_t] = [
    KeyValue_t(key: "bit", value: "Bit", additional: DataSizeBase.bit),
    KeyValue_t(key: "byte", value: "Byte", additional: DataSizeBase.byte)
]

internal enum StackMode: String {
    case auto = "automatic"
    case oneRow = "oneRow"
    case twoRows = "twoRows"
}

internal let SensorsWidgetValue: [KeyValue_t] = [
    KeyValue_t(key: "oi", value: "output/input"),
    KeyValue_t(key: "io", value: "input/output"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "i", value: "input"),
    KeyValue_t(key: "o", value: "output")
]

internal let SensorsWidgetMode: [KeyValue_t] = [
    KeyValue_t(key: StackMode.auto.rawValue, value: "Automatic"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: StackMode.oneRow.rawValue, value: "One row"),
    KeyValue_t(key: StackMode.twoRows.rawValue, value: "Two rows")
]

internal let SpeedPictogram: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "dots", value: "Dots"),
    KeyValue_t(key: "arrows", value: "Arrows"),
    KeyValue_t(key: "chars", value: "Characters")
]
internal let SpeedPictogramColor: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "default", value: "Default color"),
    KeyValue_t(key: "transparent", value: "Transparent when no activity"),
    KeyValue_t(key: "constant", value: "Constant color")
]

internal let BatteryAdditionals: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "innerPercentage", value: "Percentage inside the icon"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "percentage", value: "Percentage"),
    KeyValue_t(key: "time", value: "Time"),
    KeyValue_t(key: "percentageAndTime", value: "Percentage and time"),
    KeyValue_t(key: "timeAndPercentage", value: "Time and percentage")
]

internal let BatteryInfo: [KeyValue_t] = [
    KeyValue_t(key: "percentage", value: "Percentage"),
    KeyValue_t(key: "time", value: "Time"),
    KeyValue_t(key: "percentageAndTime", value: "Percentage and time"),
    KeyValue_t(key: "timeAndPercentage", value: "Time and percentage")
]

public let ShortLong: [KeyValue_t] = [
    KeyValue_t(key: "short", value: "Short"),
    KeyValue_t(key: "long", value: "Long")
]

public let ReaderUpdateIntervals: [KeyValue_t] = [
    KeyValue_t(key: "1", value: "1 sec"),
    KeyValue_t(key: "2", value: "2 sec"),
    KeyValue_t(key: "3", value: "3 sec"),
    KeyValue_t(key: "5", value: "5 sec"),
    KeyValue_t(key: "10", value: "10 sec"),
    KeyValue_t(key: "15", value: "15 sec"),
    KeyValue_t(key: "30", value: "30 sec"),
    KeyValue_t(key: "60", value: "60 sec")
]
public let NumbersOfProcesses: [Int] = [0, 3, 5, 8, 10, 15]

public let NetworkReaders: [KeyValue_t] = [
    KeyValue_t(key: "interface", value: "Interface based"),
    KeyValue_t(key: "process", value: "Processes based")
]

internal let Alignments: [KeyValue_t] = [
    KeyValue_t(key: "left", value: "Left alignment", additional: NSTextAlignment.left),
    KeyValue_t(key: "center", value: "Center alignment", additional: NSTextAlignment.center),
    KeyValue_t(key: "right", value: "Right alignment", additional: NSTextAlignment.right)
]

public struct SColor: KeyValue_p, Equatable {
    public let key: String
    public let value: String
    public var additional: Any?
    
    public static func == (lhs: SColor, rhs: SColor) -> Bool {
        return lhs.key == rhs.key
    }
}

extension SColor: CaseIterable {
    public static var utilization: SColor { return SColor(key: "utilization", value: "Based on utilization", additional: NSColor.black) }
    public static var pressure: SColor { return SColor(key: "pressure", value: "Based on pressure", additional: NSColor.black) }
    public static var cluster: SColor { return SColor(key: "cluster", value: "Based on cluster", additional: NSColor.controlAccentColor) }
    
    public static var separator1: SColor { return SColor(key: "separator_1", value: "separator_1", additional: NSColor.black) }
    
    public static var systemAccent: SColor { return SColor(key: "system", value: "System accent", additional: NSColor.controlAccentColor) }
    public static var monochrome: SColor { return SColor(key: "monochrome", value: "Monochrome accent", additional: NSColor.textColor) }
    
    public static var separator2: SColor { return SColor(key: "separator_2", value: "separator_2", additional: NSColor.black) }
    
    public static var clear: SColor { return SColor(key: "clear", value: "Clear", additional: NSColor.clear) }
    public static var white: SColor { return SColor(key: "white", value: "White", additional: NSColor.white) }
    public static var black: SColor { return SColor(key: "black", value: "Black", additional: NSColor.black) }
    public static var gray: SColor { return SColor(key: "gray", value: "Gray", additional: NSColor.gray) }
    public static var secondGray: SColor { return SColor(key: "secondGray", value: "Second gray", additional: NSColor.systemGray) }
    public static var darkGray: SColor { return SColor(key: "darkGray", value: "Dark gray", additional: NSColor.darkGray) }
    public static var lightGray: SColor { return SColor(key: "lightGray", value: "Light gray", additional: NSColor.lightGray) }
    public static var red: SColor { return SColor(key: "red", value: "Red", additional: NSColor.red) }
    public static var secondRed: SColor { return SColor(key: "secondRed", value: "Second red", additional: NSColor.systemRed) }
    public static var green: SColor { return SColor(key: "green", value: "Green", additional: NSColor.green) }
    public static var secondGreen: SColor { return SColor(key: "secondGreen", value: "Second green", additional: NSColor.systemGreen) }
    public static var blue: SColor { return SColor(key: "blue", value: "Blue", additional: NSColor.blue) }
    public static var secondBlue: SColor { return SColor(key: "secondBlue", value: "Second blue", additional: NSColor.systemBlue) }
    public static var yellow: SColor { return SColor(key: "yellow", value: "Yellow", additional: NSColor.yellow) }
    public static var secondYellow: SColor { return SColor(key: "secondYellow", value: "Second yellow", additional: NSColor.systemYellow) }
    public static var orange: SColor { return SColor(key: "orange", value: "Orange", additional: NSColor.orange) }
    public static var secondOrange: SColor { return SColor(key: "secondOrange", value: "Second orange", additional: NSColor.systemOrange) }
    public static var purple: SColor { return SColor(key: "purple", value: "Purple", additional: NSColor.purple) }
    public static var secondPurple: SColor { return SColor(key: "secondPurple", value: "Second purple", additional: NSColor.systemPurple) }
    public static var brown: SColor { return SColor(key: "brown", value: "Brown", additional: NSColor.brown) }
    public static var secondBrown: SColor { return SColor(key: "secondBrown", value: "Second brown", additional: NSColor.systemBrown) }
    public static var cyan: SColor { return SColor(key: "cyan", value: "Cyan", additional: NSColor.cyan) }
    public static var magenta: SColor { return SColor(key: "magenta", value: "Magenta", additional: NSColor.magenta) }
    public static var pink: SColor { return SColor(key: "pink", value: "Pink", additional: NSColor.systemPink) }
    public static var teal: SColor { return SColor(key: "teal", value: "Teal", additional: NSColor.systemTeal) }
    public static var indigo: SColor { if #available(OSX 10.15, *) {
        return SColor(key: "indigo", value: "Indigo", additional: NSColor.systemIndigo)
    } else {
        return SColor(key: "indigo", value: "Indigo", additional: NSColor(red: 75, green: 0, blue: 130, alpha: 1))
    } }
    
    public static var allCases: [SColor] {
        return [.utilization, .pressure, .cluster, separator1,
                .systemAccent, .monochrome, separator2,
                .clear, .white, .black, .gray, .secondGray, .darkGray, .lightGray,
                .red, .secondRed, .green, .secondGreen, .blue, .secondBlue, .yellow, .secondYellow,
                .orange, .secondOrange, .purple, .secondPurple, .brown, .secondBrown,
                .cyan, .magenta, .pink, .teal, .indigo
        ]
    }
    
    public static var allColors: [SColor] {
        return [.systemAccent, .monochrome, .separator2, .clear, .white, .black, .gray, .secondGray, .darkGray, .lightGray,
                .red, .secondRed, .green, .secondGreen, .blue, .secondBlue, .yellow, .secondYellow,
                .orange, .secondOrange, .purple, .secondPurple, .brown, .secondBrown,
                .cyan, .magenta, .pink, .teal, .indigo
        ]
    }
    
    public static func fromString(_ key: String, defaultValue: SColor = .systemAccent) -> SColor {
        return SColor.allCases.first{ $0.key == key } ?? defaultValue
    }
}

internal class MonochromeColor {
    static internal let red: NSColor = NSColor(red: (145), green: (145), blue: (145), alpha: 1)
    static internal let blue: NSColor = NSColor(red: (113), green: (113), blue: (113), alpha: 1)
}

public typealias colorZones = (orange: Double, red: Double)

public extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let toggleModule = Notification.Name("toggleModule")
    static let togglePopup = Notification.Name("togglePopup")
    static let toggleWidget = Notification.Name("toggleWidget")
    static let toggleWidgetIcon = Notification.Name("toggleWidgetIcon")
    static let openModuleSettings = Notification.Name("openModuleSettings")
    static let clickInSettings = Notification.Name("clickInSettings")
    static let refreshPublicIP = Notification.Name("refreshPublicIP")
    static let resetTotalNetworkUsage = Notification.Name("resetTotalNetworkUsage")
    static let syncFansControl = Notification.Name("syncFansControl")
    static let fanHelperState = Notification.Name("fanHelperState")
    static let toggleOneView = Notification.Name("toggleOneView")
    static let widgetRearrange = Notification.Name("widgetRearrange")
    static let moduleRearrange = Notification.Name("moduleRearrange")
    static let pause = Notification.Name("pause")
    static let toggleFanControl = Notification.Name("toggleFanControl")
    static let combinedModulesPopup = Notification.Name("combinedModulesPopup")
    static let remoteLoginSuccess = Notification.Name("remoteLoginSuccess")
    static let remoteState = Notification.Name("remoteState")
    static let themeChanged = Notification.Name("themeChanged")
    static let switchToTab = Notification.Name("switchToTab")
    static let toggleSplitStatus = Notification.Name("toggleSplitStatus")
    static let togglePinButton = Notification.Name("togglePinButton")
}

public var isARM: Bool {
    SystemKit.shared.device.platform != .intel
}

public let notificationLevels: [KeyValue_t] = [
    KeyValue_t(key: "", value: "Disabled"),
    KeyValue_t(key: "0.03", value: "3%"),
    KeyValue_t(key: "0.05", value: "5%"),
    KeyValue_t(key: "0.1", value: "10%"),
    KeyValue_t(key: "0.15", value: "15%"),
    KeyValue_t(key: "0.2", value: "20%"),
    KeyValue_t(key: "0.25", value: "25%"),
    KeyValue_t(key: "0.3", value: "30%"),
    KeyValue_t(key: "0.35", value: "35%"),
    KeyValue_t(key: "0.4", value: "40%"),
    KeyValue_t(key: "0.45", value: "45%"),
    KeyValue_t(key: "0.5", value: "50%"),
    KeyValue_t(key: "0.55", value: "55%"),
    KeyValue_t(key: "0.6", value: "60%"),
    KeyValue_t(key: "0.65", value: "65%"),
    KeyValue_t(key: "0.7", value: "70%"),
    KeyValue_t(key: "0.75", value: "75%"),
    KeyValue_t(key: "0.8", value: "80%"),
    KeyValue_t(key: "0.85", value: "85%"),
    KeyValue_t(key: "0.9", value: "90%"),
    KeyValue_t(key: "0.95", value: "95%"),
    KeyValue_t(key: "0.97", value: "97%"),
    KeyValue_t(key: "1.0", value: "100%")
]

public struct Scale: KeyValue_p, Equatable {
    public let key: String
    public let value: String
    
    public static func == (lhs: Scale, rhs: Scale) -> Bool {
        return lhs.key == rhs.key
    }
}

extension Scale: CaseIterable {
    public static var none: Scale { return Scale(key: "none", value: "None") }
    public static var separator: Scale { return Scale(key: "separator", value: "separator") }
    public static var linear: Scale { return Scale(key: "linear", value: "Linear") }
    public static var square: Scale { return Scale(key: "square", value: "Square") }
    public static var cube: Scale { return Scale(key: "cube", value: "Cube") }
    public static var logarithmic: Scale { return Scale(key: "logarithmic", value: "Logarithmic") }
    public static var separator2: Scale { return Scale(key: "separator", value: "separator") }
    public static var fixed: Scale { return Scale(key: "fixed", value: "Fixed scale") }
    
    public static var allCases: [Scale] {
        return [.none, .separator, .linear, .square, .cube, .logarithmic, .separator2, .fixed]
    }
    
    public static func fromString(_ key: String, defaultValue: Scale = .linear) -> Scale {
        return Scale.allCases.first{ $0.key == key } ?? defaultValue
    }
}

public enum FanValue: String {
    case rpm
    case percentage
}
public let FanValues: [KeyValue_t] = [
    KeyValue_t(key: "rpm", value: "RPM", additional: FanValue.rpm),
    KeyValue_t(key: "percentage", value: "Percentage", additional: FanValue.percentage)
]

public var LineChartHistory: [KeyValue_p] = [
    KeyValue_t(key: "60", value: "1 minute"),
    KeyValue_t(key: "120", value: "2 minutes"),
    KeyValue_t(key: "180", value: "3 minutes"),
    KeyValue_t(key: "300", value: "5 minutes"),
    KeyValue_t(key: "600", value: "10 minutes")
]

public struct SizeUnit: KeyValue_p, Equatable {
    public let key: String
    public let value: String
    
    public static func == (lhs: SizeUnit, rhs: SizeUnit) -> Bool {
        return lhs.key == rhs.key
    }
}

extension SizeUnit: CaseIterable {
    public static var byte: SizeUnit { return SizeUnit(key: "byte", value: "Bytes") }
    public static var KB: SizeUnit { return SizeUnit(key: "KB", value: "KB") }
    public static var MB: SizeUnit { return SizeUnit(key: "MB", value: "MB") }
    public static var GB: SizeUnit { return SizeUnit(key: "GB", value: "GB") }
    public static var TB: SizeUnit { return SizeUnit(key: "TB", value: "TB") }
    
    public static var allCases: [SizeUnit] {
        [.byte, .KB, .MB, .GB, .TB]
    }
    
    public static func fromString(_ key: String, defaultValue: SizeUnit = .byte) -> SizeUnit {
        return SizeUnit.allCases.first{ $0.key == key } ?? defaultValue
    }
    
    public func toBytes(_ value: Int) -> Int {
        switch self {
        case .KB:
            return value * 1_000
        case .MB:
            return value * 1_000 * 1_000
        case .GB:
            return value * 1_000 * 1_000 * 1_000
        case .TB:
            return value * 1_000 * 1_000 * 1_000 * 1_000
        default:
            return value
        }
    }
}

public enum RAMPressure: String, Codable {
    case normal
    case warning
    case critical
    
    func pressureColor() -> NSColor {
        switch self {
        case .normal:
            return NSColor.systemGreen
        case .warning:
            return NSColor.systemYellow
        case .critical:
            return NSColor.systemRed
        }
    }
}

public struct TokenResponse: Codable {
    public let access_token: String
    public let refresh_token: String
}

public struct DeviceResponse: Codable {
    public let device_code: String
    public let user_code: String
    public let verification_uri_complete: URL
    public let interval: Int?
}
