//
//  types.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public enum AppUpdateInterval: String {
    case atStart = "At start"
    case separator_1 = "separator_1"
    case oncePerDay = "Once per day"
    case oncePerWeek = "Once per week"
    case oncePerMonth = "Once per month"
    case separator_2 = "separator_2"
    case never = "Never"
}
public let AppUpdateIntervals: [KeyValue_t] = [
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

public enum DataSizeBase: String {
    case bit = "bit"
    case byte = "byte"
}
public let SpeedBase: [KeyValue_t] = [
    KeyValue_t(key: "bit", value: "Bit", additional: DataSizeBase.bit),
    KeyValue_t(key: "byte", value: "Byte", additional: DataSizeBase.byte)
]

public let SensorsWidgetMode: [KeyValue_t] = [
    KeyValue_t(key: "automatic", value: "Automatic"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "oneRow", value: "One row"),
    KeyValue_t(key: "twoRows", value: "Two rows"),
]

public let SpeedPictogram: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "dots", value: "Dots"),
    KeyValue_t(key: "arrows", value: "Arrows"),
    KeyValue_t(key: "chars", value: "Characters"),
]

public let BatteryAdditionals: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "percentage", value: "Percentage"),
    KeyValue_t(key: "time", value: "Time"),
    KeyValue_t(key: "percentageAndTime", value: "Percentage and time"),
    KeyValue_t(key: "timeAndPercentage", value: "Time and percentage"),
]

public let ShortLong: [KeyValue_t] = [
    KeyValue_t(key: "short", value: "Short"),
    KeyValue_t(key: "long", value: "Long"),
]

public let ReaderUpdateIntervals: [Int] = [1, 2, 3, 5, 10, 15, 30]
public let NumbersOfProcesses: [Int] = [0, 3, 5, 8, 10, 15]

public typealias Bandwidth = (upload: Int64, download: Int64)
public let NetworkReaders: [KeyValue_t] = [
    KeyValue_t(key: "interface", value: "Interface based"),
    KeyValue_t(key: "process", value: "Processes based"),
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
    
    public static var separator_1: Color { return Color(key: "separator_1", value: "separator_1", additional: NSColor.black) }
    
    public static var systemAccent: Color { return Color(key: "system", value: "System accent", additional: NSColor.black) }
    public static var monochrome: Color { return Color(key: "monochrome", value: "Monochrome accent", additional: NSColor.black) }
    
    public static var separator_2: Color { return Color(key: "separator_2", value: "separator_2", additional: NSColor.black) }
    
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
    public static var secondYellow: Color { return Color(key: "secondYellow", value: "Second yellow", additional: NSColor.black) }
    public static var orange: Color { return Color(key: "orange", value: "Orange", additional: NSColor.orange) }
    public static var secondOrange: Color { return Color(key: "secondOrange", value: "Second orange", additional: NSColor.black) }
    public static var purple: Color { return Color(key: "purple", value: "Purple", additional: NSColor.purple) }
    public static var secondPurple: Color { return Color(key: "secondPurple", value: "Second purple", additional: NSColor.black) }
    public static var brown: Color { return Color(key: "brown", value: "Brown", additional: NSColor.brown) }
    public static var secondBrown: Color { return Color(key: "secondBrown", value: "Second brown", additional: NSColor.black) }
    public static var cyan: Color { return Color(key: "cyan", value: "Cyan", additional: NSColor.cyan) }
    public static var magenta: Color { return Color(key: "magenta", value: "Magenta", additional: NSColor.magenta) }
    public static var pink: Color { return Color(key: "pink", value: "Pink", additional: NSColor.systemPink) }
    public static var teal: Color { return Color(key: "teal", value: "Teal", additional: NSColor.systemTeal) }
    public static var indigo: Color { if #available(OSX 10.15, *) {
        return Color(key: "indigo", value: "Indigo", additional: NSColor.systemIndigo)
    } else {
        return Color(key: "indigo", value: "Indigo", additional: NSColor(hexString: "#4B0082"))
    } }
    
    public static var allCases: [Color] {
        return [.utilization, .pressure, separator_1,
                .systemAccent, .monochrome, separator_2,
                .clear, .white, .black, .gray, .secondGray, .darkGray, .lightGray,
                .red, .secondRed, .green, .secondGreen, .blue, .secondBlue, .yellow, .secondYellow,
                .orange, .secondOrange, .purple, .secondPurple, .brown, .secondBrown,
                .cyan, .magenta, .pink, .teal, .indigo
        ]
    }
    
    public static func fromString(_ key: String, defaultValue: Color = .systemAccent) -> Color {
        return Color.allCases.first{ $0.key == key } ?? defaultValue
    }
}

public typealias colorZones = (orange: Double, red: Double)

public extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let toggleModule = Notification.Name("toggleModule")
    static let togglePopup = Notification.Name("togglePopup")
    static let toggleWidget = Notification.Name("toggleWidget")
    static let openModuleSettings = Notification.Name("openModuleSettings")
    static let settingsAppear = Notification.Name("settingsAppear")
    static let switchWidget = Notification.Name("switchWidget")
    static let checkForUpdates = Notification.Name("checkForUpdates")
    static let changeCronInterval = Notification.Name("changeCronInterval")
    static let clickInSettings = Notification.Name("clickInSettings")
    static let refreshPublicIP = Notification.Name("refreshPublicIP")
}
