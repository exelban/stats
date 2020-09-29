//
//  helpers.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 29/09/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public typealias updateInterval = String
public enum updateIntervals: updateInterval {
    case atStart = "At start"
    case separator_1 = "separator_1"
    case oncePerDay = "Once per day"
    case oncePerWeek = "Once per week"
    case oncePerMonth = "Once per month"
    case separator_2 = "separator_2"
    case never = "Never"
}
extension updateIntervals: CaseIterable {}

public struct KeyValue_t {
    let key: String
    let value: String
    let additional: Any?
    
    init(key: String, value: String, additional: Any? = nil) {
        self.key = key
        self.value = value
        self.additional = additional
    }
}

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

public struct Units {
    public let bytes: Int64
    
    public init(bytes: Int64) {
        self.bytes = bytes
    }
    
    public var kilobytes: Double {
        return Double(bytes) / 1_024
    }
    public var megabytes: Double {
        return kilobytes / 1_024
    }
    public var gigabytes: Double {
        return megabytes / 1_024
    }
    public var terabytes: Double {
        return gigabytes / 1_024
    }
    
    public func getReadableTuple() -> (String, String) {
        switch bytes {
        case 0..<1_024:
            return ("0", "KB/s")
        case 1_024..<(1_024 * 1_024):
            return (String(format: "%.0f", kilobytes), "KB/s")
        case 1_024..<(1_024 * 1_024 * 100):
            return (String(format: "%.1f", megabytes), "MB/s")
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            return (String(format: "%.0f", megabytes), "MB/s")
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return (String(format: "%.1f", gigabytes), "GB/s")
        default:
            return (String(format: "%.0f", kilobytes), "KB/s")
        }
    }
    
    public func getReadableSpeed(base: DataSizeBase = .byte) -> String {
        let stringBase = base == .byte ? "B" : "b"
        let multiplier: Double = base == .byte ? 1 : 8
        
        switch bytes*Int64(multiplier) {
        case 0..<1_024:
            return "0 K\(stringBase)/s"
        case 1_024..<(1_024 * 1_024):
            return String(format: "%.0f K\(stringBase)/s", kilobytes*multiplier)
        case 1_024..<(1_024 * 1_024 * 100):
            return String(format: "%.1f M\(stringBase)/s", megabytes*multiplier)
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            return String(format: "%.0f M\(stringBase)/s", megabytes*multiplier)
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.1f G\(stringBase)/s", gigabytes*multiplier)
        default:
            return String(format: "%.0f K\(stringBase)/s", kilobytes*multiplier)
        }
    }
    
    public func getReadableMemory() -> String {
        switch bytes {
        case 0..<1_024:
            return "0 KB"
        case 1_024..<(1_024 * 1_024):
            return String(format: "%.0f KB", kilobytes)
        case 1_024..<(1_024 * 1_024 * 1_024):
            return String(format: "%.0f MB", megabytes)
        case 1_024..<(1_024 * 1_024 * 1_024 * 1_024):
            return String(format: "%.2f GB", gigabytes)
        case (1_024 * 1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.2f TB", terabytes)
        default:
            return String(format: "%.0f KB", kilobytes)
        }
    }
}

public class LabelField: NSTextField {
    public init(frame: NSRect, _ label: String) {
        super.init(frame: frame)
        
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.wantsLayer = true
        self.backgroundColor = .clear
        self.canDrawSubviewsIntoLayer = true
        
        self.stringValue = label
        self.textColor = .secondaryLabelColor
        self.alignment = .natural
        self.font = NSFont.systemFont(ofSize: 12, weight: .regular)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class ValueField: NSTextField {
    public init(frame: NSRect, _ value: String) {
        super.init(frame: frame)
        
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.wantsLayer = true
        self.backgroundColor = .clear
        self.canDrawSubviewsIntoLayer = true
        
        self.stringValue = value
        self.textColor = .textColor
        self.alignment = .right
        self.font = NSFont.systemFont(ofSize: 13, weight: .regular)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public extension NSBezierPath {
    func addArrow(start: CGPoint, end: CGPoint, pointerLineLength: CGFloat, arrowAngle: CGFloat) {
        self.move(to: start)
        self.line(to: end)
        
        let startEndAngle = atan((end.y - start.y) / (end.x - start.x)) + ((end.x - start.x) < 0 ? CGFloat(Double.pi) : 0)
        let arrowLine1 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle + arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle + arrowAngle))
        let arrowLine2 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle - arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle - arrowAngle))
        
        self.line(to: arrowLine1)
        self.move(to: end)
        self.line(to: arrowLine2)
    }
}

public func SeparatorView(_ title: String, origin: NSPoint, width: CGFloat) -> NSView {
    let view: NSView = NSView(frame: NSRect(x: origin.x, y: origin.y, width: width, height: 30))
    
    let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-15)/2, width: view.frame.width, height: 15))
    labelView.stringValue = title
    labelView.alignment = .center
    labelView.textColor = .secondaryLabelColor
    labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    labelView.stringValue = title
    
    view.addSubview(labelView)
    return view
}

public func PopupRow(_ view: NSView, n: CGFloat, title: String, value: String) -> ValueField {
    let rowView: NSView = NSView(frame: NSRect(x: 0, y: 22*n, width: view.frame.width, height: 22))
    
    let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 5
    let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: (22-15)/2, width: labelWidth, height: 15), title)
    let valueView: ValueField = ValueField(frame: NSRect(x: labelWidth, y: (22-16)/2, width: rowView.frame.width - labelWidth, height: 16), value)
    
    rowView.addSubview(labelView)
    rowView.addSubview(valueView)
    view.addSubview(rowView)
    
    return valueView
}

public func PopupWithColorRow(_ view: NSView, color: NSColor, n: CGFloat, title: String, value: String) -> ValueField {
    let rowView: NSView = NSView(frame: NSRect(x: 0, y: 22*n, width: view.frame.width, height: 22))
    
    let colorView: NSView = NSView(frame: NSRect(x: 2, y: 5, width: 12, height: 12))
    colorView.wantsLayer = true
    colorView.layer?.backgroundColor = color.cgColor
    colorView.layer?.cornerRadius = 2
    let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 5
    let labelView: LabelField = LabelField(frame: NSRect(x: 18, y: (22-15)/2, width: labelWidth, height: 15), title)
    let valueView: ValueField = ValueField(frame: NSRect(x: 18 + labelWidth, y: (22-16)/2, width: rowView.frame.width - labelWidth - 18, height: 16), value)
    
    rowView.addSubview(colorView)
    rowView.addSubview(labelView)
    rowView.addSubview(valueView)
    view.addSubview(rowView)
    
    return valueView
}

public extension Array where Element : Equatable {
    func allEqual() -> Bool {
        if let firstElem = first {
            return !dropFirst().contains { $0 != firstElem }
        }
        return true
    }
}

public extension Array where Element : Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}

public func FindAndToggleNSControlState(_ view: NSView?, state: NSControl.StateValue) {
    if let control = view?.subviews.first(where: { $0 is NSControl }) {
        ToggleNSControlState(control as? NSControl, state: state)
    }
}

public func FindAndToggleEnableNSControlState(_ view: NSView?, state: Bool) {
    if let control = view?.subviews.first(where: { $0 is NSControl }) {
        ToggleEnableNSControlState(control as? NSControl, state: state)
    }
}

public func ToggleNSControlState(_ control: NSControl?, state: NSControl.StateValue) {
    if #available(OSX 10.15, *) {
        if let checkbox = control as? NSSwitch {
            checkbox.state = state
        }
    } else {
        if let checkbox = control as? NSButton {
            checkbox.state = state
        }
    }
}

public func ToggleEnableNSControlState(_ control: NSControl?, state: Bool) {
    if #available(OSX 10.15, *) {
        if let checkbox = control as? NSSwitch {
            checkbox.isEnabled = state
        }
    } else {
        if let checkbox = control as? NSButton {
            checkbox.isEnabled = state
        }
    }
}

public func dialogOKCancel(question: String, text: String) {
    let alert = NSAlert()
    alert.messageText = question
    alert.informativeText = text
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    alert.runModal()
}

public func asyncShell(_ args: String) {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", args]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
}

public func syncShell(_ args: String) -> String {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", args]
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

public func colorFromString(_ colorString: String) -> NSColor {
    switch colorString {
    case "black":
        return NSColor.black
    case "darkGray":
        return NSColor.darkGray
    case "lightGray":
        return NSColor.lightGray
    case "gray":
        return NSColor.gray
    case "secondGray":
        return NSColor.systemGray
    case "white":
        return NSColor.white
    case "red":
        return NSColor.red
    case "secondRed":
        return NSColor.systemRed
    case "green":
        return NSColor.green
    case "secondGreen":
        return NSColor.systemGreen
    case "blue":
        return NSColor.blue
    case "secondBlue":
        return NSColor.systemBlue
    case "yellow":
        return NSColor.yellow
    case "secondYellow":
        return NSColor.systemYellow
    case "orange":
        return NSColor.orange
    case "secondOrange":
        return NSColor.systemOrange
    case "purple":
        return NSColor.purple
    case "secondPurple":
        return NSColor.systemPurple
    case "brown":
        return NSColor.brown
    case "secondBrown":
        return NSColor.systemBrown
    case "cyan":
        return NSColor.cyan
    case "magenta":
        return NSColor.magenta
    case "clear":
        return NSColor.clear
    case "pink":
        return NSColor.systemPink
    case "teal":
        return NSColor.systemTeal
    case "indigo":
        if #available(OSX 10.15, *) {
            return NSColor.systemIndigo
        } else {
            return NSColor(hexString: "#4B0082")
        }
    default:
        return NSColor.controlAccentColor
    }
}

public func IsNewestVersion(currentVersion: String, latestVersion: String) -> Bool {
    let currentNumber = currentVersion.replacingOccurrences(of: "v", with: "")
    let latestNumber = latestVersion.replacingOccurrences(of: "v", with: "")
    
    let currentArray = currentNumber.condenseWhitespace().split(separator: ".")
    let latestArray = latestNumber.condenseWhitespace().split(separator: ".")
    
    var current = Version(major: Int(currentArray[0]) ?? 0, minor: Int(currentArray[1]) ?? 0, patch: Int(currentArray[2]) ?? 0)
    var latest = Version(major: Int(latestArray[0]) ?? 0, minor: Int(latestArray[1]) ?? 0, patch: Int(latestArray[2]) ?? 0)
    
    if let patch = currentArray.last, patch.contains("-") {
        let arr = patch.split(separator: "-")
        if let patchNumber = arr.first {
            current.patch = Int(patchNumber) ?? 0
        }
        if let beta = arr.last {
            current.beta = Int(beta.replacingOccurrences(of: "beta", with: "")) ?? 0
        }
    }
    
    if let patch = latestArray.last, patch.contains("-") {
        let arr = patch.split(separator: "-")
        if let patchNumber = arr.first {
            latest.patch = Int(patchNumber) ?? 0
        }
        if let beta = arr.last {
            latest.beta = Int(beta.replacingOccurrences(of: "beta", with: "")) ?? 0
        }
    }
    
    // current is not beta + latest is not beta
    if current.beta == nil && latest.beta == nil {
        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch > current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
    }
    
    // current version is beta + last version is not beta
    if current.beta != nil && latest.beta == nil {
        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch >= current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
    }
    
    // current version is beta + last version is beta
    if current.beta != nil && latest.beta != nil {
        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch >= current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.beta! > current.beta! && latest.patch >= current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
    }
    
    return false
}

public func showNotification(title: String, subtitle: String, id: String = UUID().uuidString, icon: NSImage? = nil) -> NSUserNotification {
    let notification = NSUserNotification()
    
    notification.identifier = id
    notification.title = title
    notification.subtitle = subtitle
    notification.soundName = NSUserNotificationDefaultSoundName
    notification.hasActionButton = false
    
    if icon != nil {
        notification.setValue(icon, forKey: "_identityImage")
    }
    
    NSUserNotificationCenter.default.deliver(notification)
    
    return notification
}

public struct TopProcess {
    public var pid: Int
    public var command: String
    public var name: String?
    public var usage: Double
    public var icon: NSImage?
    
    public init(pid: Int, command: String, name: String?, usage: Double, icon: NSImage?) {
        self.pid = pid
        self.command = command
        self.name = name
        self.usage = usage
        self.icon = icon
    }
}

public func getIOParent(_ obj: io_registry_entry_t) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0
    
    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }
    
    if (IOObjectConformsTo(parent, "IOBlockStorageDriver") == 0) {
        IOObjectRelease(parent)
        return nil
    }
    
    return parent
}

public func fetchIOService(_ name: String) -> [NSDictionary]? {
    var iterator: io_iterator_t = io_iterator_t()
    var obj: io_registry_entry_t = 1
    var list: [NSDictionary] = []
    
    let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(name), &iterator)
    if result == kIOReturnSuccess {
        while obj != 0 {
            obj = IOIteratorNext(iterator)
            if let props = getIOProperties(obj) {
                list.append(props)
            }
            IOObjectRelease(obj)
        }
        IOObjectRelease(iterator)
    }
    
    return list.isEmpty ? nil : list
}

public func getIOProperties(_ entry: io_registry_entry_t) -> NSDictionary? {
    var properties: Unmanaged<CFMutableDictionary>? = nil
    
    if IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) != kIOReturnSuccess {
        return nil
    }
    
    defer {
        properties?.release()
    }
    
    return properties?.takeUnretainedValue()
}

public class ColorView: NSView {
    public var inactiveColor: NSColor = NSColor.lightGray.withAlphaComponent(0.75)
    
    private let color: NSColor
    private var state: Bool
    
    public init(frame: NSRect, color: NSColor, state: Bool = false, radius: CGFloat = 2) {
        self.color = color
        self.state = state
        
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = (state ? self.color : inactiveColor).cgColor
        self.layer?.cornerRadius = radius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setState(_ newState: Bool) {
        if newState != state {
            self.layer?.backgroundColor = (newState ? self.color : inactiveColor).cgColor
            self.state = newState
        }
    }
}

public struct Log: TextOutputStream {
    public func write(_ string: String) {
        let fm = FileManager.default
        let log = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("log.txt")
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            handle.write(string.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? string.data(using: .utf8)?.write(to: log)
        }
    }
}

public func LocalizedString(_ key: String, _ params: String..., comment: String = "") -> String {
    var string = NSLocalizedString(key, comment: comment)
    if !params.isEmpty {
        for (index, param) in params.enumerated() {
            string = string.replacingOccurrences(of: "%\(index)", with: param)
        }
    }
    return string
}

public func Temperature(_ value: Double) -> String {
    let stringUnit: String = Store.shared.string(key: "temperature_units", defaultValue: "system")
    let formatter = MeasurementFormatter()
    formatter.numberFormatter.maximumFractionDigits = 0
    formatter.unitOptions = .providedUnit
    
    var measurement = Measurement(value: value, unit: UnitTemperature.celsius)
    if stringUnit != "system" {
        if let temperatureUnit = TemperatureUnits.first(where: { $0.key == stringUnit }), let unit = temperatureUnit.additional as? UnitTemperature {
            measurement.convert(to: unit)
        }
    }
    
    return formatter.string(from: measurement)
}
