//
//  extensions.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public enum Unit : Float {
    case byte     = 1
    case kilobyte = 1024
    case megabyte = 1048576
    case gigabyte = 1073741824
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
    
    public func getReadableSpeed() -> String {
        switch bytes {
        case 0..<1_024:
            return "0 KB/s"
        case 1_024..<(1_024 * 1_024):
            return String(format: "%.0f KB/s", kilobytes)
        case 1_024..<(1_024 * 1_024 * 100):
            return String(format: "%.1f MB/s", megabytes)
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            return String(format: "%.0f MB/s", megabytes)
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.1f GB/s", gigabytes)
        default:
            return String(format: "%.0f KB/s", kilobytes)
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

extension String: LocalizedError {
    public var errorDescription: String? { return self }

    public func widthOfString(usingFont font: NSFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }

    public func heightOfString(usingFont font: NSFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.height
    }

    public func sizeOfString(usingFont font: NSFont) -> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: fontAttributes)
    }
    
    public func condenseWhitespace() -> String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    public mutating func findAndCrop(pattern: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        let stringRange = NSRange(location: 0, length: self.utf16.count)
        var line = self
        
        if let searchRange = regex.firstMatch(in: self, options: [], range: stringRange) {
            let start = self.index(self.startIndex, offsetBy: searchRange.range.lowerBound)
            let end = self.index(self.startIndex, offsetBy: searchRange.range.upperBound)
            let value  = String(self[start..<end]).trimmingCharacters(in: .whitespaces)
            line = self.replacingOccurrences(
                of: value,
                with: "",
                options: .regularExpression
            )
            self = line.trimmingCharacters(in: .whitespaces)
            return value.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    public var trimmed: String {
        var buf = [UInt8]()
        var trimming = true
        for c in self.utf8 {
            if trimming && c < 33 { continue }
            trimming = false
            buf.append(c)
        }
        
        while let last = buf.last, last < 33 {
            buf.removeLast()
        }
        
        buf.append(0)
        return String(cString: buf)
    }
    
    public func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
    
    public func removedRegexMatches(pattern: String, replaceWith: String = "") -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
            let range = NSMakeRange(0, self.count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch {
            return self
        }
    }
}

public extension Int {
    func pressureColor() -> NSColor {
        switch self {
        case 1:
            return NSColor.systemGreen
        case 2:
            return NSColor.systemYellow
        case 3:
            return NSColor.systemRed
        default:
            return NSColor.controlAccentColor
        }
    }
}

extension Float {
    init?(_ bytes: [UInt8]) {
        self = bytes.withUnsafeBytes {
            return $0.load(fromByteOffset: 0, as: Self.self)
        }
    }
}

public extension Double {
    func roundTo(decimalPlaces: Int) -> String {
        return NSString(format: "%.\(decimalPlaces)f" as NSString, self) as String
    }
    
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    func usageColor(reversed: Bool = false) -> NSColor {
        let firstColor: NSColor = NSColor.systemBlue
        let secondColor: NSColor = NSColor.orange
        let thirdColor: NSColor = NSColor.red
        
        if reversed {
            switch self {
            case 0.6...0.8:
                return secondColor
            case 0.8...1:
                return firstColor
            default:
                return thirdColor
            }
        } else {
            switch self {
            case 0.6...0.8:
                return secondColor
            case 0.8...1:
                return thirdColor
            default:
                return firstColor
            }
        }
    }
    
    func percentageColor(color: Bool) -> NSColor {
        if !color {
            return NSColor.textColor
        }
        
        switch self {
        case 0.6...0.8:
            return NSColor.systemOrange
        case 0.8...1:
            return NSColor.systemRed
        default:
            return NSColor.systemGreen
        }
    }
    
    func batteryColor(color: Bool = false) -> NSColor {
        switch self {
        case 0.2...0.4:
            if !color {
                return NSColor.textColor
            }
            return NSColor.systemOrange
        case 0.4...1:
            if self == 1 {
                return NSColor.textColor
            }
            if !color {
                return NSColor.textColor
            }
            return NSColor.systemGreen
        default:
            return NSColor.systemRed
        }
    }
    
    func secondsToHoursMinutesSeconds () -> (Int?, Int?, Int?) {
        let hrs = self / 3600
        let mins = (self.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = (self.truncatingRemainder(dividingBy:3600)).truncatingRemainder(dividingBy:60)
        return (Int(hrs) > 0 ? Int(hrs) : nil , Int(mins) > 0 ? Int(mins) : nil, Int(seconds) > 0 ? Int(seconds) : nil)
    }
    
    func printSecondsToHoursMinutesSeconds () -> String {
        let time = self.secondsToHoursMinutesSeconds()
        
        switch time {
        case (nil, let x? , let y?):
            return "\(x)min \(y)sec"
        case (nil, let x?, nil):
            return "\(x)min"
        case (let x?, nil, nil):
            return "\(x)h"
        case (nil, nil, let x?):
            return "\(x)sec"
        case (let x?, nil, let z?):
            return "\(x)h \(z)sec"
        case (let x?, let y?, nil):
            return "\(x)h \(y)min"
        case (let x?, let y?, let z?):
            return "\(x)h \(y)min \(z)sec"
        default:
            return "n/a"
        }
    }
}

public extension NSView {
    var isDarkMode: Bool {
        if #available(OSX 10.14, *) {
            switch effectiveAppearance.name {
            case .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark:
                return true
            default:
                return false
            }
        } else {
            switch effectiveAppearance.name {
            case .vibrantDark:
                return true
            default:
                return false
            }
        }
    }
    
    func ToggleTitleRow(frame: NSRect, title: String, action: Selector, state: Bool) -> NSView {
        let row: NSView = NSView(frame: frame)
        let state: NSControl.StateValue = state ? .on : .off
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17), title)
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        var toggle: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: row.frame.width - 50, y: 0, width: 50, height: row.frame.height))
            switchButton.state = state
            switchButton.action = action
            switchButton.target = self
            
            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: row.frame.width - 30, y: 0, width: 30, height: row.frame.height))
            button.setButtonType(.switch)
            button.state = state
            button.title = ""
            button.action = action
            button.isBordered = false
            button.isTransparent = true
            button.target = self
            
            toggle = button
        }
        
        row.addSubview(toggle)
        row.addSubview(rowTitle)
        
        return row
    }
    
    func SelectTitleRow(frame: NSRect, title: String, action: Selector, items: [String], selected: String) -> NSView {
        let row: NSView = NSView(frame: frame)
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17), title)
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        let select: NSPopUpButton = NSPopUpButton(frame: NSRect(x: row.frame.width - 50, y: (row.frame.height-26)/2, width: 50, height: 26))
        select.target = self
        select.action = action
        
        let menu = NSMenu()
        items.forEach { (color: String) in
            if color.contains("separator") {
                menu.addItem(NSMenuItem.separator())
            } else {
                let interfaceMenu = NSMenuItem(title: color, action: nil, keyEquivalent: "")
                menu.addItem(interfaceMenu)
                if selected == color {
                    interfaceMenu.state = .on
                }
            }
        }
        
        select.menu = menu
        select.sizeToFit()
        
        rowTitle.setFrameSize(NSSize(width: row.frame.width - select.frame.width, height: rowTitle.frame.height))
        select.setFrameOrigin(NSPoint(x: row.frame.width - select.frame.width, y: select.frame.origin.y))
        
        row.addSubview(select)
        row.addSubview(rowTitle)
        
        return row
    }
    
    func SelectColorRow(frame: NSRect, title: String, action: Selector, items: [String], selected: String) -> NSView {
        let row: NSView = NSView(frame: frame)
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17), title)
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        let select: NSPopUpButton = NSPopUpButton(frame: NSRect(x: row.frame.width - 50, y: (row.frame.height-26)/2, width: 50, height: 26))
        select.target = self
        select.action = action
        
        let menu = NSMenu()
        items.forEach { (color: String) in
            if color.contains("separator") {
                menu.addItem(NSMenuItem.separator())
            } else {
                let interfaceMenu = NSMenuItem(title: color, action: nil, keyEquivalent: "")
                menu.addItem(interfaceMenu)
                if selected == color {
                    interfaceMenu.state = .on
                }
            }
        }
        
        select.menu = menu
        select.sizeToFit()
        
        rowTitle.setFrameSize(NSSize(width: row.frame.width - select.frame.width, height: rowTitle.frame.height))
        select.setFrameOrigin(NSPoint(x: row.frame.width - select.frame.width, y: select.frame.origin.y))
        
        row.addSubview(select)
        row.addSubview(rowTitle)
        
        return row
    }
}

public extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let toggleModule = Notification.Name("toggleModule")
    static let openSettingsView = Notification.Name("openSettingsView")
    static let switchWidget = Notification.Name("switchWidget")
    static let checkForUpdates = Notification.Name("checkForUpdates")
    static let changeCronInterval = Notification.Name("changeCronInterval")
    static let clickInSettings = Notification.Name("clickInSettings")
    static let updatePopupSize = Notification.Name("updatePopupSize")
}

public class NSButtonWithPadding: NSButton {
    public var horizontalPadding: CGFloat = 0
    public var verticalPadding: CGFloat = 0

    public override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += self.horizontalPadding
        size.height += self.verticalPadding
        return size;
    }
}

public class TextView: NSTextField {
    public override init(frame: NSRect) {
        super.init(frame: frame)
        
        self.isEditable = false
        self.isSelectable = false
        self.isBezeled = false
        self.wantsLayer = true
        self.textColor = .labelColor
        self.backgroundColor = .clear
        self.canDrawSubviewsIntoLayer = true
        self.alignment = .natural
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public extension OperatingSystemVersion {
    func getFullVersion(separator: String = ".") -> String {
        return "\(majorVersion)\(separator)\(minorVersion)\(separator)\(patchVersion)"
    }
}

extension URL {
    func checkFileExist() -> Bool {
        return FileManager.default.fileExists(atPath: self.path)
    }
}

extension UInt32 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | UInt32(bytes.2) << 8 | UInt32(bytes.3)
    }
}

extension UInt16 {
    init(bytes: (UInt8, UInt8)) {
        self = UInt16(bytes.0) << 8 | UInt16(bytes.1)
    }
}

extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)

        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
    
    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

public extension NSColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
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
    
    let current = Version(major: Int(currentArray[0]) ?? 0, minor: Int(currentArray[1]) ?? 0, patch: Int(currentArray[2]) ?? 0)
    let latest = Version(major: Int(latestArray[0]) ?? 0, minor: Int(latestArray[1]) ?? 0, patch: Int(latestArray[2]) ?? 0)
    
    if latest.major > current.major {
        return true
    }
    
    if latest.minor > current.minor && latest.major >= current.major {
        return true
    }
    
    if latest.patch > current.patch && latest.minor >= current.minor && latest.major >= current.major {
        return true
    }
    
    return false
}

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
        for param in params {
            string = string.replacingOccurrences(of: "%@", with: param)
        }
    }
    return string
}
