//
//  helpers.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 29/09/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//
// swiftlint:disable file_length

import Cocoa
import ServiceManagement
import UserNotifications

public struct LaunchAtLogin {
    private static let id = "\(Bundle.main.bundleIdentifier!).LaunchAtLogin"
    
    public static var isEnabled: Bool {
        get {
            if #available(macOS 13, *) {
                return isEnabledNext
            } else {
                return isEnabledLegacy
            }
        }
        set {
            if #available(macOS 13, *) {
                isEnabledNext = newValue
            } else {
                isEnabledLegacy = newValue
            }
        }
    }
    
    private static var isEnabledLegacy: Bool {
        get {
            guard let jobs = (LaunchAtLogin.self as DeprecationWarningWorkaround.Type).jobsDict else {
                return false
            }
            let job = jobs.first { $0["Label"] as! String == id }
            return job?["OnDemand"] as? Bool ?? false
        }
        set {
            SMLoginItemSetEnabled(id as CFString, newValue)
        }
    }
    
    @available(macOS 13, *)
    private static var isEnabledNext: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }
    
    public static func migrate() {
        guard #available(macOS 13, *), !Store.shared.exist(key: "LaunchAtLoginNext") else {
            return
        }
        
        Store.shared.set(key: "LaunchAtLoginNext", value: true)
        isEnabledNext = isEnabledLegacy
        isEnabledLegacy = false
        try? SMAppService.loginItem(identifier: id).unregister()
    }
}

private protocol DeprecationWarningWorkaround {
    static var jobsDict: [[String: AnyObject]]? { get }
}

extension LaunchAtLogin: DeprecationWarningWorkaround {
    @available(*, deprecated)
    static var jobsDict: [[String: AnyObject]]? {
        SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]
    }
}

public protocol KeyValue_p {
    var key: String { get }
    var value: String { get }
    var additional: Any? { get }
}

public struct KeyValue_t: KeyValue_p {
    public let key: String
    public let value: String
    public let additional: Any?
    
    public init(key: String, value: String, additional: Any? = nil) {
        self.key = key
        self.value = value
        self.additional = additional
    }
}

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
    
    public func getReadableTuple(base: DataSizeBase = .byte) -> (String, String) {
        let stringBase = base == .byte ? "B" : "b"
        let multiplier: Double = base == .byte ? 1 : 8
        
        switch bytes {
        case 0..<1_024:
            return ("0", "K\(stringBase)/s")
        case 1_024..<(1_024 * 1_024):
            return (String(format: "%.0f", kilobytes*multiplier), "K\(stringBase)/s")
        case 1_024..<(1_024 * 1_024 * 100):
            return (String(format: "%.1f", megabytes*multiplier), "M\(stringBase)/s")
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            return (String(format: "%.0f", megabytes*multiplier), "M\(stringBase)/s")
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return (String(format: "%.1f", gigabytes*multiplier), "G\(stringBase)/s")
        default:
            return (String(format: "%.0f", kilobytes*multiplier), "K\(stringBase)B/s")
        }
    }
    
    public func getReadableSpeed(base: DataSizeBase = .byte, omitUnits: Bool = false) -> String {
        let stringBase = base == .byte ? "B" : "b"
        let multiplier: Double = base == .byte ? 1 : 8
        
        switch bytes*Int64(multiplier) {
        case 0..<1_024:
            let unit = omitUnits ? "" : " K\(stringBase)/s"
            return "0\(unit)"
        case 1_024..<(1_024 * 1_024):
            let unit = omitUnits ? "" : " K\(stringBase)/s"
            return String(format: "%.0f\(unit)", kilobytes*multiplier)
        case 1_024..<(1_024 * 1_024 * 100):
            let unit = omitUnits ? "" : " M\(stringBase)/s"
            return String(format: "%.1f\(unit)", megabytes*multiplier)
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            let unit = omitUnits ? "" : " M\(stringBase)/s"
            return String(format: "%.0f\(unit)", megabytes*multiplier)
        case (1_024 * 1_024 * 1_024)...Int64.max:
            let unit = omitUnits ? "" : " G\(stringBase)/s"
            return String(format: "%.1f\(unit)", gigabytes*multiplier)
        default:
            let unit = omitUnits ? "" : " K\(stringBase)/s"
            return String(format: "%.0f\(unit)", kilobytes*multiplier)
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
            return String(format: "%.1f GB", gigabytes)
        case (1_024 * 1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.1f TB", terabytes)
        default:
            return String(format: "%.0f KB", kilobytes)
        }
    }
}

public struct DiskSize {
    public let value: Int64
    
    public init(_ size: Int64) {
        self.value = size
    }
    
    public var kilobytes: Double {
        return Double(value) / 1_000
    }
    public var megabytes: Double {
        return kilobytes / 1_000
    }
    public var gigabytes: Double {
        return megabytes / 1_000
    }
    public var terabytes: Double {
        return gigabytes / 1_000
    }
    
    public func getReadableMemory() -> String {
        switch value {
        case 0..<1_000:
            return "0 KB"
        case 1_000..<(1_000 * 1_000):
            return String(format: "%.0f KB", kilobytes)
        case 1_000..<(1_000 * 1_000 * 1_000):
            return String(format: "%.0f MB", megabytes)
        case 1_000..<(1_000 * 1_000 * 1_000 * 1_000):
            return String(format: "%.1f GB", gigabytes)
        case (1_000 * 1_000 * 1_000 * 1_000)...Int64.max:
            return String(format: "%.1f TB", terabytes)
        default:
            return String(format: "%.0f KB", kilobytes)
        }
    }
}

public class LabelField: NSTextField {
    public init(frame: NSRect, _ label: String = "") {
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
    public init(frame: NSRect, _ value: String = "") {
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
        let arrowLine1 = CGPoint(
            x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle + arrowAngle),
            y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle + arrowAngle)
        )
        let arrowLine2 = CGPoint(
            x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle - arrowAngle),
            y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle - arrowAngle)
        )
        
        self.line(to: arrowLine1)
        self.move(to: end)
        self.line(to: arrowLine2)
    }
}

public func separatorView(_ title: String, origin: NSPoint = NSPoint(x: 0, y: 0), width: CGFloat) -> NSView {
    let view: NSView = NSView(frame: NSRect(x: origin.x, y: origin.y, width: width, height: 30))
    view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
    
    let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-18)/2, width: view.frame.width, height: 18))
    labelView.stringValue = title
    labelView.alignment = .center
    labelView.textColor = .secondaryLabelColor
    labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    labelView.stringValue = title
    
    view.addSubview(labelView)
    
    return view
}

public func popupRow(_ view: NSView, n: CGFloat = 0, title: String, value: String) -> (LabelField, ValueField) {
    let rowView: NSView = NSView(frame: NSRect(x: 0, y: 22*n, width: view.frame.width, height: 22))
    
    let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 4
    let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: (22-16)/2, width: labelWidth, height: 16), title)
    let valueView: ValueField = ValueField(frame: NSRect(x: labelWidth, y: (22-16)/2, width: rowView.frame.width - labelWidth, height: 16), value)
    
    rowView.addSubview(labelView)
    rowView.addSubview(valueView)
    
    if let view = view as? NSStackView {
        rowView.heightAnchor.constraint(equalToConstant: rowView.bounds.height).isActive = true
        view.addArrangedSubview(rowView)
    } else {
        view.addSubview(rowView)
    }
    
    return (labelView, valueView)
}

public func popupWithColorRow(_ view: NSView, color: NSColor, n: CGFloat, title: String, value: String) -> (NSView, ValueField) {
    let rowView: NSView = NSView(frame: NSRect(x: 0, y: 22*n, width: view.frame.width, height: 22))
    
    let colorView: NSView = NSView(frame: NSRect(x: 2, y: 5, width: 12, height: 12))
    colorView.wantsLayer = true
    colorView.layer?.backgroundColor = color.cgColor
    colorView.layer?.cornerRadius = 2
    let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 5
    let labelView: LabelField = LabelField(frame: NSRect(x: 18, y: (22-16)/2, width: labelWidth, height: 16), title)
    let valueView: ValueField = ValueField(frame: NSRect(x: 18 + labelWidth, y: (22-16)/2, width: rowView.frame.width - labelWidth - 18, height: 16), value)
    
    rowView.addSubview(colorView)
    rowView.addSubview(labelView)
    rowView.addSubview(valueView)
    
    if let view = view as? NSStackView {
        rowView.heightAnchor.constraint(equalToConstant: rowView.bounds.height).isActive = true
        view.addArrangedSubview(rowView)
    } else {
        view.addSubview(rowView)
    }
    
    return (colorView, valueView)
}

public extension Array where Element: Equatable {
    func allEqual() -> Bool {
        if let firstElem = first {
            return !dropFirst().contains { $0 != firstElem }
        }
        return true
    }
}

public extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}

public func findAndToggleNSControlState(_ view: NSView?, state: NSControl.StateValue) {
    if let control = view?.subviews.first(where: { $0 is NSControl && !($0 is NSTextField) }) {
        toggleNSControlState(control as? NSControl, state: state)
    }
}

public func findAndToggleEnableNSControlState(_ view: NSView?, state: Bool) {
    if let control = view?.subviews.first(where: { ($0 is NSControl || $0 is NSPopUpButton) && !($0 is NSTextField) }) {
        if control is NSControl {
            toggleEnableNSControlState(control as? NSControl, state: state)
        } else if control is NSPopUpButton {
            toggleEnableNSControlState(control as? NSPopUpButton, state: state)
        }
    }
}

public func toggleNSControlState(_ control: NSControl?, state: NSControl.StateValue) {
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

public func toggleEnableNSControlState(_ control: NSControl?, state: Bool) {
    if #available(OSX 10.15, *) {
        if let checkbox = control as? NSSwitch {
            checkbox.isEnabled = state
        } else if let checkbox = control as? NSPopUpButton {
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

public func isNewestVersion(currentVersion: String, latestVersion: String) -> Bool {
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

@available(macOS 10.14, *)
public func showNotification(title: String, subtitle: String? = nil, userInfo: [AnyHashable: Any] = [:], delegate: UNUserNotificationCenterDelegate? = nil) -> String {
    let id = UUID().uuidString
    
    let content = UNMutableNotificationContent()
    content.title = title
    if let value = subtitle {
        content.subtitle = value
    }
    content.userInfo = userInfo
    content.sound = UNNotificationSound.default
    
    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
    let center = UNUserNotificationCenter.current()
    center.delegate = delegate
    
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    center.add(request) { (error: Error?) in
        if let err = error {
            print(err)
        }
    }
    
    return id
}

@available(macOS 10.14, *)
public func removeNotification(_ id: String) {
    let center = UNUserNotificationCenter.current()
    center.removeDeliveredNotifications(withIdentifiers: [id])
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
        self.icon = icon != nil ? icon : Constants.defaultProcessIcon
    }
}

public func getIOParent(_ obj: io_registry_entry_t) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0
    
    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }
    
    if IOObjectConformsTo(parent, "IOBlockStorageDriver") == 0 {
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
    if result != kIOReturnSuccess {
        print("Error IOServiceGetMatchingServices(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    while obj != 0 {
        obj = IOIteratorNext(iterator)
        if let props = getIOProperties(obj) {
            list.append(props)
        }
        IOObjectRelease(obj)
    }
    IOObjectRelease(iterator)
    
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

public func getIOName(_ entry: io_registry_entry_t) -> String? {
    let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
    
    let result = IORegistryEntryGetName(entry, pointer)
    if result != kIOReturnSuccess {
        print("Error IORegistryEntryGetName(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
}

public func getIOChildrens(_ entry: io_registry_entry_t) -> [String]? {
    var iter: io_iterator_t = io_iterator_t()
    if IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iter) != kIOReturnSuccess {
        return nil
    }
    
    var iterator: io_registry_entry_t = 1
    var list: [String] = []
    while iterator != 0 {
        iterator = IOIteratorNext(iter)
        
        let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        if IORegistryEntryGetName(iterator, pointer) != kIOReturnSuccess {
            continue
        }
        
        list.append(String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self)))
        IOObjectRelease(iterator)
    }
    
    return list
}

public class ColorView: NSView {
    public var inactiveColor: NSColor = NSColor.lightGray.withAlphaComponent(0.75)
    
    private var color: NSColor
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
    
    public func setColor(_ newColor: NSColor) {
        guard self.color != newColor else { return }
        self.color = newColor
        self.layer?.backgroundColor = newColor.cgColor
    }
}

public func localizedString(_ key: String, _ params: String..., comment: String = "") -> String {
    var string = NSLocalizedString(key, comment: comment)
    if !params.isEmpty {
        for (index, param) in params.enumerated() {
            string = string.replacingOccurrences(of: "%\(index)", with: param)
        }
    }
    return string
}

public extension UnitTemperature {
    static var system: UnitTemperature {
        let measureFormatter = MeasurementFormatter()
        let measurement = Measurement(value: 0, unit: UnitTemperature.celsius)
        return measureFormatter.string(from: measurement).hasSuffix("C") ? .celsius : .fahrenheit
    }
    
    static var current: UnitTemperature {
        let stringUnit: String = Store.shared.string(key: "temperature_units", defaultValue: "system")
        var unit = UnitTemperature.system
        if stringUnit != "system" {
            if let value = TemperatureUnits.first(where: { $0.key == stringUnit }), let temperatureUnit = value.additional as? UnitTemperature {
                unit = temperatureUnit
            }
        }
        return unit
    }
}

// swiftlint:disable identifier_name
public func Temperature(_ value: Double, defaultUnit: UnitTemperature = UnitTemperature.celsius) -> String {
    let formatter = MeasurementFormatter()
    formatter.locale = Locale.init(identifier: "en_US")
    formatter.numberFormatter.maximumFractionDigits = 0
    formatter.unitOptions = .providedUnit
    
    var measurement = Measurement(value: value, unit: defaultUnit)
    measurement.convert(to: UnitTemperature.current)
    
    return formatter.string(from: measurement)
}

public func sysctlByName(_ name: String) -> Int64 {
    var num: Int64 = 0
    var size = MemoryLayout<Int64>.size
    
    if sysctlbyname(name, &num, &size, nil, 0) != 0 {
        print(POSIXError.Code(rawValue: errno).map { POSIXError($0) } ?? CocoaError(.fileReadUnknown))
    }
    
    return num
}

public class ProcessView: NSStackView {
    private var pid: Int? = nil
    private var lock: Bool = false
    
    private var imageView: NSImageView = NSImageView(frame: NSRect(x: 5, y: 5, width: 12, height: 12))
    private var killView: NSButton = NSButton(frame: NSRect(x: 5, y: 5, width: 12, height: 12))
    private var labelView: LabelField = {
        let view = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        view.cell?.truncatesLastVisibleLine = true
        return view
    }()
    private var valueView: ValueField = ValueField(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 264, height: 22))
        
        self.wantsLayer = true
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.layer?.cornerRadius = 3
        
        let imageBox: NSView = {
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
            
            self.killView.bezelStyle = .regularSquare
            self.killView.translatesAutoresizingMaskIntoConstraints = false
            self.killView.imageScaling = .scaleNone
            self.killView.image = Bundle(for: type(of: self)).image(forResource: "cancel")!
            if #available(OSX 10.14, *) {
                self.killView.contentTintColor = .lightGray
            }
            self.killView.isBordered = false
            self.killView.action = #selector(self.kill)
            self.killView.target = self
            self.killView.toolTip = localizedString("Kill process")
            self.killView.focusRingType = .none
            self.killView.isHidden = true
            
            view.addSubview(self.imageView)
            view.addSubview(self.killView)
            
            return view
        }()
        
        self.addArrangedSubview(imageBox)
        self.addArrangedSubview(self.labelView)
        self.addArrangedSubview(self.valueView)
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            imageBox.widthAnchor.constraint(equalToConstant: self.bounds.height),
            imageBox.heightAnchor.constraint(equalToConstant: self.bounds.height),
            self.labelView.heightAnchor.constraint(equalToConstant: 16),
            self.widthAnchor.constraint(equalToConstant: self.bounds.width),
            self.heightAnchor.constraint(equalToConstant: self.bounds.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func mouseEntered(with: NSEvent) {
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
            return
        }
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.05)
    }
    
    public override func mouseExited(with: NSEvent) {
        if self.lock {
            self.imageView.isHidden = false
            self.killView.isHidden = true
            return
        }
        self.layer?.backgroundColor = .none
    }
    
    public override func mouseDown(with: NSEvent) {
        self.setLock(!self.lock)
    }
    
    public func set(_ process: TopProcess, _ value: String) {
        if self.lock && process.pid != self.pid { return }
        
        self.labelView.stringValue = process.name != nil ? process.name! : process.command
        self.valueView.stringValue = value
        self.imageView.image = process.icon
        self.pid = process.pid
        self.toolTip = "pid: \(process.pid)"
    }
    
    public func clear() {
        self.labelView.stringValue = ""
        self.valueView.stringValue = ""
        self.imageView.image = nil
        self.pid = nil
        self.setLock(false)
        self.toolTip = ""
    }
    
    private func setLock(_ state: Bool) {
        self.lock = state
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
            self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.1)
        } else {
            self.imageView.isHidden = false
            self.killView.isHidden = true
            self.layer?.backgroundColor = .none
        }
    }
    
    @objc public func kill() {
        if let pid = self.pid {
            asyncShell("kill \(pid)")
        }
    }
}

public class CAText: CATextLayer {
    public init(fontSize: CGFloat = 12, weight: NSFont.Weight = .regular) {
        super.init()
        
        self.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        self.fontSize = fontSize
        
        self.allowsFontSubpixelQuantization = true
        self.contentsScale = NSScreen.main?.backingScaleFactor ?? 1
        self.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 1
        
        self.foregroundColor = NSColor.textColor.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
    }
    
    public func getWidth(add: CGFloat = 0) -> CGFloat {
        let value = self.string as? String ?? ""
        return value.widthOfString(usingFont: self.font as! NSFont).rounded(.up) + add
    }
}

public class WidgetLabelView: NSView {
    private var title: String
    
    public init(_ title: String, height: CGFloat) {
        self.title = title
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: 6,
            height: height
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        let title = self.title.prefix(3)
        let letterHeight = self.frame.height / 3
        let letterWidth: CGFloat = self.frame.height / CGFloat(title.count)
        
        var yMargin: CGFloat = 0
        for char in title.uppercased().reversed() {
            let rect = CGRect(x: 0, y: yMargin, width: letterWidth, height: letterHeight-1)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)
            yMargin += letterHeight
        }
    }
}

public func isRoot() -> Bool {
    return getuid() == 0
}

public func ensureRoot() {
    if isRoot() {
        return
    }
    
    let pwd = Bundle.main.bundleURL.absoluteString.replacingOccurrences(of: "file://", with: "")
    guard let script = NSAppleScript(source: "do shell script \"\(pwd)/Contents/MacOS/Stats > /dev/null 2>&1 &\" with administrator privileges") else {
        return
    }
    
    var err: NSDictionary? = nil
    script.executeAndReturnError(&err)
    
    if err != nil {
        print("cannot run script as root: \(String(describing: err))")
        return
    }
    
    NSApp.terminate(nil)
    return
}

public func process(path: String, arguments: [String]) -> String? {
    let task = Process()
    task.launchPath = path
    task.arguments = arguments
    
    let outputPipe = Pipe()
    defer {
        outputPipe.fileHandleForReading.closeFile()
    }
    task.standardOutput = outputPipe
    
    do {
        try task.run()
    } catch let error {
        debug("system_profiler SPMemoryDataType: \(error.localizedDescription)")
        return nil
    }
    
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: outputData, as: UTF8.self)
    
    if output.isEmpty {
        return nil
    }
    
    return output
}

public class SettingsContainerView: NSStackView {
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class SMCHelper {
    public static let shared = SMCHelper()
    
    public var isInstalled: Bool {
        syncShell("ls /Library/PrivilegedHelperTools/").contains("eu.exelban.Stats.SMC.Helper")
    }
    
    private var connection: NSXPCConnection? = nil
    
    public func setFanSpeed(_ id: Int, speed: Int) {
        guard let helper = self.helper(nil) else { return }
        helper.setFanSpeed(id: id, value: speed) { result in
            if let result, !result.isEmpty {
                print(result)
            }
        }
    }
    
    public func setFanMode(_ id: Int, mode: Int) {
        guard let helper = self.helper(nil) else { return }
        helper.setFanMode(id: id, mode: mode) { result in
            if let result, !result.isEmpty {
                print(result)
            }
        }
    }
    
    public func isActive() -> Bool {
        return self.connection != nil
    }
    
    private func helperStatus(completion: @escaping (_ installed: Bool) -> Void) {
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/eu.exelban.Stats.SMC.Helper")
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleShortVersionString"] as? String,
            let helper = self.helper(completion) else {
                completion(false)
                return
        }
        
        helper.version { installedHelperVersion in
            completion(installedHelperVersion == helperVersion)
        }
    }
    
    public func install(completion: @escaping (_ installed: Bool) -> Void) {
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [.preAuthorize], &authRef)
        
        guard authStatus == errAuthorizationSuccess else {
            print("Unable to get a valid empty authorization reference to load Helper daemon")
            completion(false)
            return
        }
        
        let authItem = kSMRightBlessPrivilegedHelper.withCString { authorizationString in
            AuthorizationItem(name: authorizationString, valueLength: 0, value: nil, flags: 0)
        }
        
        let pointer = UnsafeMutablePointer<AuthorizationItem>.allocate(capacity: 1)
        pointer.initialize(to: authItem)
        
        defer {
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }
        
        var authRights = AuthorizationRights(count: 1, items: pointer)
        
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        authStatus = AuthorizationCreate(&authRights, nil, flags, &authRef)
        
        guard authStatus == errAuthorizationSuccess else {
            print("Unable to get a valid loading authorization reference to load Helper daemon")
            completion(false)
            return
        }
        
        var error: Unmanaged<CFError>?
        if SMJobBless(kSMDomainUserLaunchd, "eu.exelban.Stats.SMC.Helper" as CFString, authRef, &error) == false {
            let blessError = error!.takeRetainedValue() as Error
            print("Error while installing the Helper: \(blessError.localizedDescription)")
            completion(false)
            return
        }
        
        AuthorizationFree(authRef!, [])
        completion(true)
    }
    
    private func helperConnection() -> NSXPCConnection? {
        guard self.connection == nil else {
            return self.connection
        }
        
        let connection = NSXPCConnection(machServiceName: "eu.exelban.Stats.SMC.Helper", options: .privileged)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler = {
            self.connection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                self.connection = nil
            }
        }
        
        self.connection = connection
        self.connection?.resume()
        
        return self.connection
    }
    
    private func helper(_ completion: ((Bool) -> Void)?) -> HelperProtocol? {
        guard let helper = self.helperConnection()?.remoteObjectProxyWithErrorHandler({ _ in
            if let onCompletion = completion { onCompletion(false) }
        }) as? HelperProtocol else { return nil }
        
        helper.setSMCPath(Bundle.main.path(forResource: "smc", ofType: nil)!)
        
        return helper
    }
    
    public func uninstall() {
        if let count = SMC.shared.getValue("FNum") {
            for i in 0..<Int(count) {
                self.setFanMode(i, mode: 0)
            }
        }
        guard let helper = self.helper(nil) else { return }
        helper.uninstall()
        NotificationCenter.default.post(name: .fanHelperState, object: nil, userInfo: ["state": false])
    }
}

internal func grayscaleImage(_ image: NSImage) -> NSImage? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    
    guard let grayscale = bitmap.converting(to: .genericGray, renderingIntent: .default) else {
        return nil
    }
    let greyImage = NSImage(size: image.size)
    greyImage.addRepresentation(grayscale)
    
    return greyImage
}

internal class ViewCopy: CALayer {
    init(_ view: NSView) {
        super.init()
        
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        
        frame = view.frame
        contents = bitmap.cgImage
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class EmptyView: NSStackView {
    public init(height: CGFloat = 120, isHidden: Bool = false, msg: String) {
        super.init(frame: NSRect())
        
        self.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        self.translatesAutoresizingMaskIntoConstraints = true
        self.orientation = .vertical
        self.distribution = .fillEqually
        self.isHidden = isHidden
        self.identifier = NSUserInterfaceItemIdentifier(rawValue: "emptyView")
        
        let textView: NSTextView = NSTextView()
        textView.heightAnchor.constraint(equalToConstant: (height/2)+6).isActive = true
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.string = msg
        
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public func saveNSStatusItemPosition(id: String) {
    let position = Store.shared.int(key: "NSStatusItem Preferred Position \(id)", defaultValue: -1)
    if position != -1 {
        Store.shared.set(key: "NSStatusItem Restore Position \(id)", value: position)
    }
}
public func restoreNSStatusItemPosition(id: String) {
    let prevPosition = Store.shared.int(key: "NSStatusItem Restore Position \(id)", defaultValue: -1)
    if prevPosition != -1 {
        Store.shared.set(key: "NSStatusItem Preferred Position \(id)", value: prevPosition)
        Store.shared.remove("NSStatusItem Restore Position \(id)")
    }
}

public class AppIcon: NSView {
    public static let size: CGSize = CGSize(width: 16, height: 16)
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 3, width: AppIcon.size.width, height: AppIcon.size.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(true)
        
        NSColor.textColor.set()
        NSBezierPath(roundedRect: NSRect(
            x: 0,
            y: 0,
            width: AppIcon.size.width,
            height: AppIcon.size.height
        ), xRadius: 4, yRadius: 4).fill()
        
        NSColor.controlTextColor.set()
        NSBezierPath(roundedRect: NSRect(
            x: 1.5,
            y: 1.5,
            width: AppIcon.size.width - 3,
            height: AppIcon.size.height - 3
        ), xRadius: 3, yRadius: 3).fill()
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1) / 2
        let offset = lineWidth/2
        let zero = (AppIcon.size.height - 3 + 1.5)/2 + lineWidth
        let x = 1.5
        
        let downloadLine = drawLine(points: [
            (x+0, zero-offset),
            (x+1, zero-offset),
            (x+2, zero-offset-2.5),
            (x+3, zero-offset-4),
            (x+4, zero-offset),
            (x+5, zero-offset-2),
            (x+6, zero-offset),
            (x+7, zero-offset),
            (x+8, zero-offset-2),
            (x+9, zero-offset),
            (x+10, zero-offset-4),
            (x+11, zero-offset-0.5),
            (x+12, zero-offset)
        ], color: NSColor.systemBlue, lineWidth: lineWidth)
        
        let uploadLine = drawLine(points: [
            (x+0, zero+offset),
            (x+1, zero+offset),
            (x+2, zero+offset+2),
            (x+3, zero+offset),
            (x+4, zero+offset),
            (x+5, zero+offset),
            (x+6, zero+offset+3),
            (x+7, zero+offset+3),
            (x+8, zero+offset),
            (x+9, zero+offset+1),
            (x+10, zero+offset+5),
            (x+11, zero+offset),
            (x+12, zero+offset)
        ], color: NSColor.systemRed, lineWidth: lineWidth)
        
        ctx.saveGState()
        drawUnderLine(dirtyRect, path: downloadLine, color: NSColor.systemBlue, x: x, y: zero-offset)
        ctx.restoreGState()
        ctx.saveGState()
        drawUnderLine(dirtyRect, path: uploadLine, color: NSColor.systemRed, x: x, y: zero+offset)
        ctx.restoreGState()
    }
    
    private func drawLine(points: [(CGFloat, CGFloat)], color: NSColor, lineWidth: CGFloat) -> NSBezierPath {
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for i in 1..<points.count {
            linePath.line(to: CGPoint(x: points[i].0, y: points[i].1))
        }
        color.setStroke()
        linePath.lineWidth = lineWidth
        linePath.stroke()
        return linePath
    }
    
    private func drawUnderLine(_ rect: NSRect, path: NSBezierPath, color: NSColor, x: CGFloat, y: CGFloat) {
        let underLinePath = path.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: x, y: y))
        underLinePath.line(to: CGPoint(x: x, y: y))
        underLinePath.close()
        underLinePath.addClip()
        color.withAlphaComponent(0.5).setFill()
        NSBezierPath(rect: rect).fill()
    }
}

public func controlState(_ sender: NSControl) -> Bool {
    var state: NSControl.StateValue
    
    if #available(OSX 10.15, *) {
        state = sender is NSSwitch ? (sender as! NSSwitch).state : .off
    } else {
        state = sender is NSButton ? (sender as! NSButton).state : .off
    }
    
    return state == .on
}

@available(macOS 11.0, *)
public func iconFromSymbol(name: String, scale: NSImage.SymbolScale) -> NSImage? {
    let config = NSImage.SymbolConfiguration(textStyle: .body, scale: scale)
    if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
        return symbol.withSymbolConfiguration(config)
    }
    return nil
}
