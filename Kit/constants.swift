//
//  constants.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public struct Popup_c_s {
    public let width: CGFloat = 264
    public let height: CGFloat = 300
    /// Outer inset between the popup window edge (the glass surface)
    /// and its content. Applied symmetrically to header (top + sides)
    /// and body (sides + bottom + gap above body) so the dialog has
    /// a uniform frame matching system menus / popovers.
    public let margins: CGFloat = 16
    public let spacing: CGFloat = 2
    public let headerHeight: CGFloat = 28
    public let separatorHeight: CGFloat = 30
    public let portalHeight: CGFloat = 120
}

public struct Settings_c_s {
    public let width: CGFloat = 540
    public let height: CGFloat = 480
    public let margin: CGFloat = 10
    public let row: CGFloat = 30
}

public struct Widget_c_s {
    public let width: CGFloat = 32
    public var height: CGFloat {
        get {
            let systemHeight = NSApplication.shared.mainMenu?.menuBarHeight
            return (systemHeight == 0 ? 22 : systemHeight) ?? 22
        }
    }
    public var margin: CGPoint {
        get { CGPoint(x: 0, y: 2) }
    }
    public let spacing: CGFloat = 2
}

public struct Constants {
    public static let Popup: Popup_c_s = Popup_c_s()
    public static let Settings: Settings_c_s = Settings_c_s()
    public static let Widget: Widget_c_s = Widget_c_s()
    
    public static let defaultProcessIcon = NSWorkspace.shared.icon(forFile: "/bin/bash")
    
    /// `true` on macOS Tahoe (macOS 26) and later. Used by menu bar status
    /// items (referred to internally as "widgets") to opt into the Liquid
    /// Glass pill style by default while preserving the classic look on
    /// older systems.
    public static let isTahoe: Bool = ProcessInfo().isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
    )
    
    /// Default monochrome ink for Liquid Glass widgets. In Tahoe the light
    /// menu bar uses a desaturated near-black (~`#3C3C43`, matching the
    /// system's `secondaryLabelColor` ink) rather than pure black, and pure
    /// white in the dark menu bar. Use this anywhere a widget would otherwise
    /// hardcode `.white` / `.black` for its outline / fill.
    public static var liquidGlassInk: NSColor {
        // Resolve against the currently-drawing appearance (set on the
        // graphics stack by AppKit during `draw(_:)`). This lets the preview
        // window override appearance per-widget via `view.appearance`, and
        // also picks up live system menu bar light/dark changes.
        let appearance = NSAppearance.current ?? NSApp.effectiveAppearance
        let isDark: Bool = {
            switch appearance.name {
            case .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark:
                return true
            default:
                return false
            }
        }()
        return isDark
            ? NSColor.white.withAlphaComponent(0.85)
            : NSColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.85)
    }
    
    /// Resolve a Liquid Glass warning color for a normalized 0…1 value. When
    /// the value crosses the warning threshold the ink turns yellow; past the
    /// critical threshold it turns red. Below warning, the regular menu-bar
    /// ink is returned. Alpha matches the rest of the menu bar (~0.85).
    /// In the light menu bar the system colors are too bright and wash out
    /// against white chrome, so a darker amber/scarlet pair is substituted.
    public static func liquidGlassWarningColor(value: Double, warning: Double, critical: Double) -> NSColor {
        let appearance = NSAppearance.current ?? NSApp.effectiveAppearance
        let isDark: Bool = {
            switch appearance.name {
            case .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark:
                return true
            default:
                return false
            }
        }()
        if value >= critical {
            // Dark menu bar: stock systemRed reads well at 0.85 alpha.
            // Light menu bar: shift to a deeper, less saturated red so it
            // doesn't bloom against the bright background.
            return isDark
                ? NSColor.systemRed.withAlphaComponent(0.85)
                : NSColor(red: 0.70, green: 0.10, blue: 0.10, alpha: 0.90)
        }
        if value >= warning {
            // Light menu bar: yellow is the worst offender on white. Use a
            // darker amber/orange so the warning stays legible.
            return isDark
                ? NSColor.systemYellow.withAlphaComponent(0.85)
                : NSColor(red: 0.72, green: 0.45, blue: 0.05, alpha: 0.90)
        }
        return liquidGlassInk
    }
}

public enum ModuleType: Int {
    case CPU
    case RAM
    case GPU
    case disk
    case sensors
    case network
    case battery
    case bluetooth
    case clock
    
    case combined
    
    public var stringValue: String {
        switch self {
        case .CPU: return "CPU"
        case .RAM: return "RAM"
        case .GPU: return "GPU"
        case .disk: return "Disk"
        case .sensors: return "Sensors"
        case .network: return "Network"
        case .battery: return "Battery"
        case .bluetooth: return "Bluetooth"
        case .clock: return "Clock"
        case .combined: return ""
        }
    }
}
