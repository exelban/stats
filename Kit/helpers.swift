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

public struct LaunchAtLogin {
    private static let id = "\(Bundle.main.bundleIdentifier!).LaunchAtLogin"
    
    public static var isEnabled: Bool {
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
            return String(format: "%.2f GB", gigabytes)
        case (1_024 * 1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.2f TB", terabytes)
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
            return String(format: "%.2f GB", gigabytes)
        case (1_000 * 1_000 * 1_000 * 1_000)...Int64.max:
            return String(format: "%.2f TB", terabytes)
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

public func popupWithColorRow(_ view: NSView, color: NSColor, n: CGFloat, title: String, value: String) -> ValueField {
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
    
    return valueView
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
    if let control = view?.subviews.first(where: { $0 is NSControl && !($0 is NSTextField) }) {
        toggleEnableNSControlState(control as? NSControl, state: state)
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

public func showNotification(title: String, subtitle: String? = nil, text: String? = nil, id: String = UUID().uuidString, icon: NSImage? = nil) -> NSUserNotification {
    let notification = NSUserNotification()
    
    notification.identifier = id
    notification.title = title
    notification.subtitle = subtitle
    notification.informativeText = text
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

public func localizedString(_ key: String, _ params: String..., comment: String = "") -> String {
    var string = NSLocalizedString(key, comment: comment)
    if !params.isEmpty {
        for (index, param) in params.enumerated() {
            string = string.replacingOccurrences(of: "%\(index)", with: param)
        }
    }
    return string
}

extension UnitTemperature {
    static var current: UnitTemperature {
        let measureFormatter = MeasurementFormatter()
        let measurement = Measurement(value: 0, unit: UnitTemperature.celsius)
        return measureFormatter.string(from: measurement).hasSuffix("C") ? .celsius : .fahrenheit
    }
}

// swiftlint:disable identifier_name
public func Temperature(_ value: Double) -> String {
    let stringUnit: String = Store.shared.string(key: "temperature_units", defaultValue: "system")
    let formatter = MeasurementFormatter()
    formatter.locale = Locale.init(identifier: "en_US")
    formatter.numberFormatter.maximumFractionDigits = 0
    formatter.unitOptions = .providedUnit
    
    var measurement = Measurement(value: value, unit: UnitTemperature.celsius)
    if stringUnit == "system" {
        measurement.convert(to: UnitTemperature.current)
    } else {
        if let temperatureUnit = TemperatureUnits.first(where: { $0.key == stringUnit }) {
            if let unit = temperatureUnit.additional as? UnitTemperature {
                measurement.convert(to: unit)
            }
        }
    }
    
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
        self.lock = !self.lock
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
        self.toolTip = ""
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
    private let smc: String
    
    public init() {
        self.smc = Bundle.main.path(forResource: "smc", ofType: nil)!
    }
    
    public func setFanSpeed(_ id: Int, speed: Int) {
        if !self.checkRights() {
            if !self.ensureRights() {
                return
            }
        }
        
        _ = syncShell("\(self.smc) fan -id \(id) -v \(speed)")
    }
    
    public func setFanMode(_ id: Int, mode: Int) {
        if !self.checkRights() {
            if !self.ensureRights() {
                return
            }
        }
        
        _ = syncShell("\(self.smc) fan -id \(id) -m \(mode)")
    }
    
    private func checkRights() -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.smc)
            guard let owner = attributes[FileAttributeKey(rawValue: "NSFileOwnerAccountName")] as? String,
                  let ownerGroup = attributes[FileAttributeKey(rawValue: "NSFileGroupOwnerAccountName")] as? String,
                  let permissions = attributes[FileAttributeKey(rawValue: "NSFilePosixPermissions")]  as? Int else {
                print("some of the smc attributes is missing")
                return false
            }
            
            if owner == "root" && ownerGroup == "admin" && permissions == 3437 {
                return true
            }
        } catch let error {
            print("get smc attributes, \(error)")
            return false
        }
        
        return false
    }
    
    private func ensureRights() -> Bool {
        guard let script = NSAppleScript(source: "do shell script \"/usr/sbin/chown root:admin \(self.smc) && /bin/chmod 6555 \(self.smc)\" with administrator privileges") else {
            return false
        }
        
        var err: NSDictionary? = nil
        script.executeAndReturnError(&err)
        if err != nil {
            print("cannot upgrade owner to root: \(String(describing: err))")
            return false
        }
        
        return true
    }
}
