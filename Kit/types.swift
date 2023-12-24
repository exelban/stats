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

public enum StackMode: String {
    case auto = "automatic"
    case oneRow = "oneRow"
    case twoRows = "twoRows"
}

public let SensorsWidgetMode: [KeyValue_t] = [
    KeyValue_t(key: StackMode.auto.rawValue, value: "Automatic"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: StackMode.oneRow.rawValue, value: "One row"),
    KeyValue_t(key: StackMode.twoRows.rawValue, value: "Two rows")
]

public let SpeedPictogram: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "dots", value: "Dots"),
    KeyValue_t(key: "arrows", value: "Arrows"),
    KeyValue_t(key: "chars", value: "Characters")
]

public let BatteryAdditionals: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "innerPercentage", value: "Percentage inside the icon"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "percentage", value: "Percentage"),
    KeyValue_t(key: "time", value: "Time"),
    KeyValue_t(key: "percentageAndTime", value: "Percentage and time"),
    KeyValue_t(key: "timeAndPercentage", value: "Time and percentage")
]

public let BatteryInfo: [KeyValue_t] = [
    KeyValue_t(key: "percentage", value: "Percentage"),
    KeyValue_t(key: "time", value: "Time"),
    KeyValue_t(key: "percentageAndTime", value: "Percentage and time"),
    KeyValue_t(key: "timeAndPercentage", value: "Time and percentage")
]

public let ShortLong: [KeyValue_t] = [
    KeyValue_t(key: "short", value: "Short"),
    KeyValue_t(key: "long", value: "Long")
]

public let ReaderUpdateIntervals: [Int] = [1, 2, 3, 5, 10, 15, 30, 60]
public let NumbersOfProcesses: [Int] = [0, 3, 5, 8, 10, 15]

public typealias Bandwidth = (upload: Int64, download: Int64)
public let NetworkReaders: [KeyValue_t] = [
    KeyValue_t(key: "interface", value: "Interface based"),
    KeyValue_t(key: "process", value: "Processes based")
]

public let Alignments: [KeyValue_t] = [
    KeyValue_t(key: "left", value: "Left alignment", additional: NSTextAlignment.left),
    KeyValue_t(key: "center", value: "Center alignment", additional: NSTextAlignment.center),
    KeyValue_t(key: "right", value: "Right alignment", additional: NSTextAlignment.right)
]

public struct Color: KeyValue_p, Equatable {
    public let key: String
    public let value: String
    public var additional: Any?
    
    public static func == (lhs: Color, rhs: Color) -> Bool {
        return lhs.key == rhs.key
    }
}

extension Color: CaseIterable {
    public static var utilization: Color { return Color(key: "utilization", value: "Based on utilization", additional: NSColor.black) }
    public static var pressure: Color { return Color(key: "pressure", value: "Based on pressure", additional: NSColor.black) }
    public static var cluster: Color { return Color(key: "cluster", value: "Based on cluster", additional: NSColor.controlAccentColor) }
    
    public static var separator1: Color { return Color(key: "separator_1", value: "separator_1", additional: NSColor.black) }
    
    public static var systemAccent: Color { return Color(key: "system", value: "System accent", additional: NSColor.controlAccentColor) }
    public static var monochrome: Color { return Color(key: "monochrome", value: "Monochrome accent", additional: NSColor.textColor) }
    
    public static var separator2: Color { return Color(key: "separator_2", value: "separator_2", additional: NSColor.black) }
    
    public static var clear: Color { return Color(key: "clear", value: "Clear", additional: NSColor.clear) }
    public static var white: Color { return Color(key: "white", value: "White", additional: NSColor.white) }
    public static var black: Color { return Color(key: "black", value: "Black", additional: NSColor.black) }
    public static var gray: Color { return Color(key: "gray", value: "Gray", additional: NSColor.gray) }
    public static var secondGray: Color { return Color(key: "secondGray", value: "Second gray", additional: NSColor.systemGray) }
    public static var darkGray: Color { return Color(key: "darkGray", value: "Dark gray", additional: NSColor.darkGray) }
    public static var lightGray: Color { return Color(key: "lightGray", value: "Light gray", additional: NSColor.lightGray) }
    public static var red: Color { return Color(key: "red", value: "Red", additional: NSColor.red) }
    public static var secondRed: Color { return Color(key: "secondRed", value: "Second red", additional: NSColor.systemRed) }
    public static var green: Color { return Color(key: "green", value: "Green", additional: NSColor.green) }
    public static var secondGreen: Color { return Color(key: "secondGreen", value: "Second green", additional: NSColor.systemGreen) }
    public static var blue: Color { return Color(key: "blue", value: "Blue", additional: NSColor.blue) }
    public static var secondBlue: Color { return Color(key: "secondBlue", value: "Second blue", additional: NSColor.systemBlue) }
    public static var yellow: Color { return Color(key: "yellow", value: "Yellow", additional: NSColor.yellow) }
    public static var secondYellow: Color { return Color(key: "secondYellow", value: "Second yellow", additional: NSColor.systemYellow) }
    public static var orange: Color { return Color(key: "orange", value: "Orange", additional: NSColor.orange) }
    public static var secondOrange: Color { return Color(key: "secondOrange", value: "Second orange", additional: NSColor.systemOrange) }
    public static var purple: Color { return Color(key: "purple", value: "Purple", additional: NSColor.purple) }
    public static var secondPurple: Color { return Color(key: "secondPurple", value: "Second purple", additional: NSColor.systemPurple) }
    public static var brown: Color { return Color(key: "brown", value: "Brown", additional: NSColor.brown) }
    public static var secondBrown: Color { return Color(key: "secondBrown", value: "Second brown", additional: NSColor.systemBrown) }
    public static var cyan: Color { return Color(key: "cyan", value: "Cyan", additional: NSColor.cyan) }
    public static var magenta: Color { return Color(key: "magenta", value: "Magenta", additional: NSColor.magenta) }
    public static var pink: Color { return Color(key: "pink", value: "Pink", additional: NSColor.systemPink) }
    public static var teal: Color { return Color(key: "teal", value: "Teal", additional: NSColor.systemTeal) }
    public static var indigo: Color { if #available(OSX 10.15, *) {
        return Color(key: "indigo", value: "Indigo", additional: NSColor.systemIndigo)
    } else {
        return Color(key: "indigo", value: "Indigo", additional: NSColor(red: 75, green: 0, blue: 130, alpha: 1))
    } }
    
    public static var allCases: [Color] {
        return [.utilization, .pressure, .cluster, separator1,
                .systemAccent, .monochrome, separator2,
                .clear, .white, .black, .gray, .secondGray, .darkGray, .lightGray,
                .red, .secondRed, .green, .secondGreen, .blue, .secondBlue, .yellow, .secondYellow,
                .orange, .secondOrange, .purple, .secondPurple, .brown, .secondBrown,
                .cyan, .magenta, .pink, .teal, .indigo
        ]
    }
    
    public static var allColors: [Color] {
        return [.systemAccent, .monochrome, .separator2, .clear, .white, .black, .gray, .secondGray, .darkGray, .lightGray,
                .red, .secondRed, .green, .secondGreen, .blue, .secondBlue, .yellow, .secondYellow,
                .orange, .secondOrange, .purple, .secondPurple, .brown, .secondBrown,
                .cyan, .magenta, .pink, .teal, .indigo
        ]
    }
    
    public static var random: Color {
        Color.allColors[.random(in: 0...Color.allColors.count)]
    }
    
    public static func fromString(_ key: String, defaultValue: Color = .systemAccent) -> Color {
        return Color.allCases.first{ $0.key == key } ?? defaultValue
    }
}

public class MonochromeColor {
    static public let base: NSColor = NSColor.textColor
    static public let red: NSColor = NSColor(red: (145), green: (145), blue: (145), alpha: 1)
    static public let blue: NSColor = NSColor(red: (113), green: (113), blue: (113), alpha: 1)
}

public typealias colorZones = (orange: Double, red: Double)

public extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let toggleModule = Notification.Name("toggleModule")
    static let togglePopup = Notification.Name("togglePopup")
    static let toggleWidget = Notification.Name("toggleWidget")
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
    public var additional: Any?
    
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
    
    public static var allCases: [Scale] {
        return [.none, .separator, .linear, .square, .cube, .logarithmic]
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
