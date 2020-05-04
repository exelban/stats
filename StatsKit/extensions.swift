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
    
    public func getReadableTuple() -> (Double, String) {
        switch bytes {
        case 0..<1_024:
            return (0, "KB/s")
        case 1_024..<(1_024 * 1_024):
            return (Double(String(format: "%.2f", kilobytes))!, "KB/s")
        case 1_024..<(1_024 * 1_024 * 1_024):
            return (Double(String(format: "%.2f", megabytes))!, "MB/s")
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return (Double(String(format: "%.2f", gigabytes))!, "GB/s")
        default:
            return (Double(String(format: "%.2f", kilobytes))!, "KB/s")
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
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.2f GB", gigabytes)
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
    
    func usageColor(reversed: Bool = false, color: Bool = false) -> NSColor {
        if !color {
            return NSColor.textColor
        }

        if reversed {
            switch self {
            case 0.6...0.8:
                return NSColor.systemOrange
            case 0.8...1:
                return NSColor.systemGreen
            default:
                return NSColor.systemRed
            }
        } else {
            switch self {
            case 0.6...0.8:
                return NSColor.systemOrange
            case 0.8...1:
                return NSColor.systemRed
            default:
                return NSColor.systemGreen
            }
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
        rowTitle.textColor = .labelColor
        
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
            
            toggle = button
        }

        row.addSubview(toggle)
        row.addSubview(rowTitle)
        
        return row
    }
}

public extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let toggleModule = Notification.Name("toggleModule")
    static let openSettingsView = Notification.Name("openSettingsView")
    static let switchWidget = Notification.Name("switchWidget")
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
