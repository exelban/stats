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
    
    init(fromFPE2 bytes: (UInt8, UInt8)) {
        self = (Int(bytes.0) << 6) + (Int(bytes.1) >> 2)
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
    
    func secondsToHoursMinutesSeconds() -> (Int, Int) {
        let mins = (self.truncatingRemainder(dividingBy: 3600)) / 60
        return (Int(self / 3600) , Int(mins))
    }
    
    func printSecondsToHoursMinutesSeconds(short: Bool = false) -> String {
        let (h, m) = self.secondsToHoursMinutesSeconds()
        
        if self == 0 || h < 0 || m < 0 {
            return "n/a"
        }
        
        let minutes = m > 9 ? "\(m)" : "0\(m)"
        
        if short {
            return "\(h):\(minutes)"
        }
        
        if h == 0 {
            return "\(minutes)min"
        } else if m == 0 {
            return "\(h)h"
        }
        
        return "\(h)h \(minutes)min"
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
    
    func SelectRow(frame: NSRect, title: String, action: Selector, items: [KeyValue_t], selected: String) -> NSView {
        let row: NSView = NSView(frame: frame)
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17), title)
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        let select: NSPopUpButton = SelectView(action: action, items: items, selected: selected)
        select.sizeToFit()
        
        rowTitle.setFrameSize(NSSize(width: row.frame.width - select.frame.width, height: rowTitle.frame.height))
        select.setFrameOrigin(NSPoint(x: row.frame.width - select.frame.width, y: select.frame.origin.y))
        
        row.addSubview(select)
        row.addSubview(rowTitle)
        
        return row
    }
    
    func SelectView(action: Selector, items: [KeyValue_t], selected: String) -> NSPopUpButton {
        let select: NSPopUpButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 50, height: 26))
        select.target = self
        select.action = action
        
        let menu = NSMenu()
        items.forEach { (item) in
            if item.key.contains("separator") {
                menu.addItem(NSMenuItem.separator())
            } else {
                let interfaceMenu = NSMenuItem(title: LocalizedString(item.value), action: nil, keyEquivalent: "")
                interfaceMenu.representedObject = item.key
                menu.addItem(interfaceMenu)
                if selected == item.key {
                    interfaceMenu.state = .on
                }
            }
        }
        select.menu = menu
        
        return select
    }
}

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
}

public class NSButtonWithPadding: NSButton {
    public var horizontalPadding: CGFloat = 0
    public var verticalPadding: CGFloat = 0
    
    public override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += self.horizontalPadding
        size.height += self.verticalPadding
        return size
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

public extension CATransaction {
    static func disableAnimations(_ closure: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        CATransaction.setAnimationDuration(0)
        closure()
        CATransaction.commit()
    }
}

public final class FlippedClipView: NSClipView {
    public override var isFlipped: Bool {
        return true
    }
}

public final class ScrollableStackView: NSView {
    public let stackView: NSStackView = NSStackView()
    public let clipView: FlippedClipView = FlippedClipView()
    private let scrollView: NSScrollView = NSScrollView()
    
    public override init(frame: NSRect) {
        super.init(frame: frame)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.drawsBackground = false
        self.addSubview(self.scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leftAnchor.constraint(equalTo: self.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: self.rightAnchor),
            scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
        
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        
        stackView.orientation = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stackView
        
        NSLayoutConstraint.activate([
            stackView.leftAnchor.constraint(equalTo: clipView.leftAnchor),
            stackView.rightAnchor.constraint(equalTo: clipView.rightAnchor),
            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
        ])
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
