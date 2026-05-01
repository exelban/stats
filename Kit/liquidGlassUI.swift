//
//  liquidGlassUI.swift
//  Kit
//
//  App-wide Liquid Glass appearance for module popups (and any future
//  surfaces that opt in). On macOS 26 (Tahoe) we use the real
//  `NSGlassEffectView` API — the same primitive Apple's Wi-Fi / Battery
//  / Control Center popovers are built on. On older systems we fall
//  back to an `NSVisualEffectView` translucent panel.
//

import Cocoa

public extension Notification.Name {
    /// Posted whenever the global Liquid Glass UI preference (toggle or
    /// tint) changes. Open windows should rebuild their material in place.
    static let liquidGlassUIChanged = Notification.Name("liquidGlassUIChanged")
}

public struct LiquidGlassUI {
    public static let storeKey: String = "LiquidGlassUI"
    public static let tintStoreKey: String = "LiquidGlassUI_tint"
    public static let styleStoreKey: String = "LiquidGlassUI_style"

    /// Glass material thickness. Apple's `NSGlassEffectView` only ships
    /// two real styles in the macOS 26 SDK: `regular` (thicker, frosted
    /// — matches Wi-Fi / Battery popovers and menu bar menus) and
    /// `clear` (thinner, more transparent — matches floating HUDs and
    /// overlays on top of media).
    public enum Style: String, CaseIterable {
        case regular, clear

        public var localizedName: String {
            switch self {
            case .regular: return localizedString("Regular")
            case .clear:   return localizedString("Clear")
            }
        }

        @available(macOS 26.0, *)
        public var nsStyle: NSGlassEffectView.Style {
            switch self {
            case .regular: return .regular
            case .clear:   return .clear
            }
        }
    }

    public static var style: Style {
        get { Style(rawValue: Store.shared.string(key: styleStoreKey, defaultValue: Style.regular.rawValue)) ?? .regular }
        set {
            Store.shared.set(key: styleStoreKey, value: newValue.rawValue)
            NotificationCenter.default.post(name: .liquidGlassUIChanged, object: nil)
        }
    }

    /// Master toggle. Defaults to ON on macOS 26+ and OFF otherwise so
    /// users on older systems never get the new chrome unless they ask.
    public static var isEnabled: Bool {
        get { Store.shared.bool(key: storeKey, defaultValue: Constants.isTahoe) }
        set {
            Store.shared.set(key: storeKey, value: newValue)
            NotificationCenter.default.post(name: .liquidGlassUIChanged, object: nil)
        }
    }

    /// Tint applied to the glass material. `clear` is the default (pure
    /// system glass), `accent` follows the user's system accent color,
    /// `gray` picks a neutral monochrome wash similar to Control Center
    /// modules.
    public enum Tint: String, CaseIterable {
        case clear, dark, accent, gray

        public var localizedName: String {
            switch self {
            case .clear:  return localizedString("Clear")
            case .dark:   return localizedString("Dark")
            case .accent: return localizedString("Accent")
            case .gray:   return localizedString("Monochrome")
            }
        }

        /// Color fed to `NSGlassEffectView.tintColor` (Tahoe). Alpha is
        /// what determines how visible the wash is on top of the system
        /// material — go too low and the tint disappears, too high and
        /// the glass character is lost.
        public var glassTint: NSColor? {
            switch self {
            case .clear:
                return nil
            case .dark:
                // Matches the heavy dark frost of system Wi-Fi / Battery
                // popovers when the menu bar is dark. Combined with the
                // forced .darkAqua appearance below.
                return NSColor.black.withAlphaComponent(0.55)
            case .accent:
                return NSColor.controlAccentColor.withAlphaComponent(0.45)
            case .gray:
                return NSColor.gray.withAlphaComponent(0.35)
            }
        }

        /// Force a specific NSAppearance on the glass surface. Returning
        /// `nil` lets the surface follow the system. The Dark tint forces
        /// dark aqua so labels / text inside the popup recolor correctly.
        public var forcedAppearance: NSAppearance? {
            switch self {
            case .dark:
                return NSAppearance(named: .darkAqua)
            default:
                return nil
            }
        }
    }

    public static var tint: Tint {
        get { Tint(rawValue: Store.shared.string(key: tintStoreKey, defaultValue: Tint.clear.rawValue)) ?? .clear }
        set {
            Store.shared.set(key: tintStoreKey, value: newValue.rawValue)
            NotificationCenter.default.post(name: .liquidGlassUIChanged, object: nil)
        }
    }

    /// Corner radius used for popup-style surfaces. Tahoe menu bar menus
    /// (File / Edit / View dropdowns) use a small ~8pt radius — noticeably
    /// tighter than popovers (~20pt). We match the menu look here.
    public static var cornerRadius: CGFloat { Constants.isTahoe ? 8 : 6 }

    /// Background color for the per-section "card" backgrounds inside
    /// module popups. When Liquid Glass is on we want the underlying
    /// glass to show through, so we return a near-clear wash; otherwise
    /// the legacy gray cards are returned. The legacy colors are kept
    /// here verbatim so the original look is preserved when the toggle
    /// is off.
    public static func popupCardColor(isDarkMode: Bool) -> NSColor {
        if isEnabled {
            // Match the look of menu items sitting on glass: faint hover
            // wash, slightly stronger in dark mode for contrast.
            return isDarkMode
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.black.withAlphaComponent(0.04)
        }
        return isDarkMode
            ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25)
            : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
    }
}

/// A composite background view that renders a Liquid Glass surface.
/// On macOS 26+ it embeds an `NSGlassEffectView`; on older systems it
/// falls back to `NSVisualEffectView` with a layer tint overlay. Use
/// it as a sibling background — header / body should be added on top
/// of it as siblings, not as subviews of this view.
public final class LiquidGlassBackgroundView: NSView {
    private var glass: NSView?
    private var fallback: NSVisualEffectView?
    private var fallbackTintHost: NSView?
    /// Faux specular rim drawn on top of the glass to make the edge
    /// pop a little more. The real `NSGlassEffectView` rim is subtle;
    /// this hairline 1px stroke approximates the brighter rim seen on
    /// some system surfaces. It does not refract — it is purely cosmetic.
    private var rim: CALayer?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.masksToBounds = true

        if #available(macOS 26.0, *) {
            let g = NSGlassEffectView(frame: self.bounds)
            g.autoresizingMask = [.width, .height]
            // .regular = thicker frosted glass, matches the system
            // Wi-Fi / Battery / Control Center popovers. .clear is
            // for translucent overlays on top of busy content.
            g.style = .regular
            self.glass = g
            self.addSubview(g)
        } else {
            let fx = NSVisualEffectView(frame: self.bounds)
            fx.autoresizingMask = [.width, .height]
            fx.blendingMode = .behindWindow
            fx.state = .active
            // .menu matches the look of menu bar dropdowns (File / Edit / View)
            // — a darker, more frosted material than .popover.
            fx.material = .menu
            fx.wantsLayer = true
            self.fallback = fx
            self.addSubview(fx)

            let tint = NSView(frame: self.bounds)
            tint.autoresizingMask = [.width, .height]
            tint.wantsLayer = true
            self.fallbackTintHost = tint
            self.addSubview(tint)
        }

        let r = CALayer()
        r.frame = self.bounds
        r.borderWidth = 1
        r.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        r.backgroundColor = NSColor.clear.cgColor
        r.allowsEdgeAntialiasing = true
        self.rim = r
        self.layer?.addSublayer(r)

        self.apply()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func layout() {
        super.layout()
        if let r = self.rim {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            r.frame = self.bounds
            CATransaction.commit()
        }
    }

    /// Re-read the global preference and reconfigure material, tint and
    /// corner radius. Safe to call repeatedly.
    public func apply() {
        let on = LiquidGlassUI.isEnabled
        let radius: CGFloat = on ? LiquidGlassUI.cornerRadius : 6

        if let layer = self.layer {
            layer.cornerRadius = radius
            if #available(macOS 11.0, *) { layer.cornerCurve = .continuous }
        }

        if #available(macOS 26.0, *), let g = self.glass as? NSGlassEffectView {
            g.isHidden = !on
            g.cornerRadius = radius
            g.style = LiquidGlassUI.style.nsStyle
            // Real Liquid Glass tinting — affects the material itself so
            // it is visible even where opaque content sits on top.
            g.tintColor = on ? LiquidGlassUI.tint.glassTint : nil
        }
        if let fx = self.fallback {
            fx.isHidden = !on
            if let layer = fx.layer {
                layer.cornerRadius = radius
                if #available(macOS 11.0, *) { layer.cornerCurve = .continuous }
            }
        }
        if let host = self.fallbackTintHost {
            host.isHidden = !on
            host.layer?.cornerRadius = radius
            if let tint = LiquidGlassUI.tint.glassTint, on {
                host.layer?.backgroundColor = tint.withAlphaComponent(tint.alphaComponent * 0.5).cgColor
            } else {
                host.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        if let r = self.rim {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            r.isHidden = !on
            r.cornerRadius = radius
            if #available(macOS 11.0, *) { r.cornerCurve = .continuous }
            // Slightly brighter rim for the dark tint where the underlying
            // material is darkest; subtler elsewhere.
            let alpha: CGFloat = LiquidGlassUI.tint == .dark ? 0.28 : 0.18
            r.borderColor = NSColor.white.withAlphaComponent(alpha).cgColor
            CATransaction.commit()
        }
    }
}
