//
//  CombinedView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09/01/2023
//  Using Swift 5.0
//  Running on macOS 13.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class CombinedView: NSObject, NSGestureRecognizerDelegate {
    private var menuBarItem: NSStatusItem? = nil
    private var view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height))
    private var popup: PopupWindow? = nil
    private var clickMonitor: Any? = nil
    private let summary: CombinedSummaryWidget = CombinedSummaryWidget()
    
    private var status: Bool {
        Store.shared.bool(key: "CombinedModules", defaultValue: false) && !Store.shared.bool(key: "pause", defaultValue: false)
    }
    private var spacing: CGFloat {
        CGFloat(Int(Store.shared.string(key: "CombinedModules_spacing", defaultValue: "")) ?? 0)
    }
    private var separator: Bool {
        Store.shared.bool(key: "CombinedModules_separator", defaultValue: false)
    }
    
    private var activeModules: [Module] {
        modules.filter({ $0.enabled }).sorted(by: { $0.combinedPosition < $1.combinedPosition })
    }
    
    private var combinedModulesPopup: Bool {
        get { Store.shared.bool(key: "CombinedModules_popup", defaultValue: true) }
        set { Store.shared.set(key: "CombinedModules_popup", value: newValue) }
    }
    private var combinedModulesAlternateDetails: Bool {
        get { Store.shared.bool(key: "CombinedModules_alternateDetails", defaultValue: true) }
        set { Store.shared.set(key: "CombinedModules_alternateDetails", value: newValue) }
    }
    private var combinedModulesModifierKeys: [UInt16] {
        get { Store.shared.array(key: "CombinedModules_modifierKeys", defaultValue: [58]) as? [UInt16] ?? [58] }
        set { Store.shared.set(key: "CombinedModules_modifierKeys", value: newValue) }
    }
    
    override init() {
        super.init()
        
        modules.forEach { (m: Module) in
            m.menuBar.callback = { [weak self] in
                if let s = self?.status, s {
                    DispatchQueue.main.async(execute: {
                        self?.recalculate()
                    })
                }
            }
            m.summaryCallback = { [weak self] module, value in
                guard let self else { return }
                self.summary.setValue(for: module, with: value)
                guard self.status, CombinedModulesWidget.current.isSummaryWidget else { return }
                self.updateSummary()
            }
        }
        
        self.popup = PopupWindow(title: "Combined modules", module: .combined, view: Popup()) { _ in }
        
        if self.status {
            self.enable()
        }
        
        self.clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleAlternateClick(event)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForStateChange), name: .toggleOneView, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForStateChange), name: .pause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleRearrrange), name: .moduleRearrange, object: nil)
    }
    
    deinit {
        if let monitor = self.clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
        NotificationCenter.default.removeObserver(self, name: .pause, object: nil)
        NotificationCenter.default.removeObserver(self, name: .moduleRearrange, object: nil)
    }
    
    public func enable() {
        guard self.menuBarItem == nil else { return }
        
        self.menuBarItem = NSStatusBar.system.statusItem(withLength: 0)
        DispatchQueue.main.async(execute: {
            self.menuBarItem?.autosaveName = "CombinedModules"
        })
        self.menuBarItem?.button?.addSubview(self.view)
        self.menuBarItem?.button?.image = NSImage()
        self.menuBarItem?.button?.toolTip = localizedString("Combined modules")
        
        self.menuBarItem?.button?.target = self
        self.menuBarItem?.button?.action = #selector(self.handleClick)
        self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        
        DispatchQueue.main.async(execute: {
            self.recalculate()
        })
    }
    
    public func disable() {
        self.popup?.setIsVisible(false)
        if let item = self.menuBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        self.menuBarItem = nil
    }
    
    private func recalculate() {
        guard self.status, self.menuBarItem != nil else { return }
        self.view.subviews.forEach({ $0.removeFromSuperview() })
        self.menuBarItem?.button?.toolTip = localizedString("Combined modules")
        self.menuBarItem?.button?.setAccessibilityLabel(localizedString("Combined modules"))
        
        if CombinedModulesWidget.current.isSummaryWidget {
            self.updateSummary()
            return
        }
        
        if CombinedModulesWidget.current == .icon {
            self.view.addSubview(AppIcon())
            self.view.setFrameSize(NSSize(width: AppIcon.size.width, height: self.view.frame.height))
            self.menuBarItem?.length = AppIcon.size.width
            return
        }
        
        let visibleModules = self.activeModules.filter({ !$0.menuBar.activeWidgets.isEmpty })
        var w: CGFloat = 0
        visibleModules.enumerated().forEach { (i, m) in
            if i != 0 {
                w += self.spacing
                if self.separator {
                    self.view.addSubview(SeparatorLineView(frame: NSRect(x: w, y: 3, width: 1, height: Constants.Widget.height-6)))
                    w += 3 + self.spacing
                }
            }
            self.view.addSubview(m.menuBar.view)
            m.menuBar.view.setFrameOrigin(NSPoint(x: w, y: 0))
            w += m.menuBar.view.frame.width
        }
        self.view.setFrameSize(NSSize(width: w, height: self.view.frame.height))
        self.menuBarItem?.length = w
    }
    
    private func updateSummary() {
        guard self.menuBarItem != nil else { return }
        let list = self.activeModules.filter({ $0.config.hasSummary })
        
        if list.isEmpty {
            self.view.subviews.forEach({ $0.removeFromSuperview() })
            self.view.addSubview(AppIcon())
            self.view.setFrameSize(NSSize(width: AppIcon.size.width, height: self.view.frame.height))
            self.menuBarItem?.length = AppIcon.size.width
            self.menuBarItem?.button?.toolTip = localizedString("Combined modules")
            self.menuBarItem?.button?.setAccessibilityLabel(localizedString("Combined modules"))
            return
        }
        
        if self.summary.superview == nil {
            self.view.subviews.forEach({ $0.removeFromSuperview() })
            self.view.addSubview(self.summary)
        }
        
        self.summary.update(list)
        self.view.setFrameSize(self.summary.frame.size)
        self.menuBarItem?.length = self.summary.frame.width
        
        self.menuBarItem?.button?.toolTip = self.summary.toolTip
        self.menuBarItem?.button?.setAccessibilityLabel(self.summary.toolTip)
    }
    
    // call when popup appear/disappear
    private func visibilityCallback(_ state: Bool) {}
    
    @objc private func handleClick() {
        if CombinedModulesWidget.current != .widgets || self.combinedModulesPopup {
            self.togglePopup()
        } else {
            self.openModulePopup()
        }
    }
    
    private func handleAlternateClick(_ event: NSEvent) -> NSEvent? {
        guard let window = self.menuBarItem?.button?.window, event.window == window,
              CombinedModulesWidget.current == .widgets, self.combinedModulesAlternateDetails else { return event }
        
        let flags = CGEventSource.flagsState(.combinedSessionState)
        guard flags.isDisjoint(with: [.maskControl, .maskCommand]) else { return event }
        
        let keys = self.combinedModulesModifierKeys
        let matches = !keys.isEmpty && keys.allSatisfy { key in
            switch key {
            case 60: return flags.contains(.maskShift)
            case 58: return flags.contains(.maskAlternate)
            default: return false
            }
        }
        guard matches else { return event }
        
        if self.combinedModulesPopup {
            self.openModulePopup()
        } else {
            self.togglePopup()
        }
        return nil
    }
    
    private func openModulePopup() {
        guard let window = self.menuBarItem?.button?.window else { return }
        let location = self.view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let visibleModules = self.activeModules.filter({ !$0.menuBar.activeWidgets.isEmpty })
        guard let module = visibleModules.last(where: { $0.menuBar.view.frame.minX <= location.x }) ?? visibleModules.first else { return }
        
        var userInfo: [String: Any] = [
            "module": module.name,
            "origin": window.frame.origin,
            "center": window.frame.width/2
        ]
        let widgetLocation = module.menuBar.view.convert(location, from: self.view)
        let widgets = module.menuBar.activeWidgets
        if let widget = widgets.last(where: { $0.item.frame.minX <= widgetLocation.x }) ?? widgets.first {
            userInfo["widget"] = widget.type
        }
        NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: userInfo)
    }
    
    private func togglePopup() {
        guard let popup = self.popup, let item = self.menuBarItem, let window = item.button?.window else { return }
        
        if popup.occlusionState.rawValue == 8192 {
            popup.contentView?.invalidateIntrinsicContentSize()
            
            let windowCenter = popup.contentView!.intrinsicContentSize.width / 2
            var x = window.frame.origin.x - windowCenter + window.frame.width/2
            let y = window.frame.origin.y - popup.contentView!.intrinsicContentSize.height - 3
            
            let buttonPoint = NSPoint(x: window.frame.midX, y: window.frame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonPoint) }) ?? NSScreen.main {
                if x + popup.contentView!.intrinsicContentSize.width > screen.frame.maxX {
                    x = screen.frame.maxX - popup.contentView!.intrinsicContentSize.width - 3
                }
                if x < screen.frame.minX {
                    x = screen.frame.minX + 3
                }
            }
            
            popup.setFrameOrigin(NSPoint(x: x, y: y))
            popup.orderFrontRegardless()
            popup.makeKey()
        } else {
            popup.setIsVisible(false)
        }
    }
    
    @objc private func listenForStateChange(_ notification: Notification) {
        guard notification.userInfo?["module"] == nil else { return }
        
        if self.status {
            self.enable()
        } else {
            self.disable()
        }
    }
    
    @objc private func listenForModuleRearrrange() {
        self.recalculate()
    }
}

private class CombinedSummaryWidget: NSView {
    private var values: [(ModuleType, Double?)] = []
    
    private var color: NSColor { self.isDarkMode ? .white : .black }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        switch CombinedModulesWidget.current {
        case .rings: self.drawRings()
        case .dial: self.drawDial()
        default: self.drawBars()
        }
    }
    
    private func color(for value: Double?, moduleType: ModuleType) -> NSColor {
        guard let value else { return self.color }
        return (moduleType == .battery ? value < 0.1 : value > 0.9) ? .systemRed : self.color
    }
    
    private func drawBars() {
        let height: CGFloat = min(16, self.bounds.height - 4)
        let width = CGFloat(self.values.count) * 6 - 2
        let origin = ((self.bounds.width - width) / 2).rounded()
        let y = ((self.bounds.height - height) / 2).rounded()
        
        for (i, (module, value)) in self.values.enumerated() {
            let color = self.color(for: value, moduleType: module)
            let rect = NSRect(x: origin + CGFloat(i) * 6, y: y, width: 4, height: height)
            let track = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
            color.withAlphaComponent(0.25).setFill()
            track.fill()
            
            if let value, value > 0 {
                let fill = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: height * CGFloat(value))
                NSGraphicsContext.saveGraphicsState()
                track.addClip()
                color.setFill()
                NSBezierPath(rect: fill).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
    
    private func drawRings() {
        guard !self.values.isEmpty else { return }
        let diameter = min(20, self.bounds.height - 2)
        let spacing = min(3, diameter / (CGFloat(self.values.count) * 2))
        let lineWidth = spacing - 0.5
        let center = NSPoint(x: self.bounds.midX, y: self.bounds.midY)
        
        for (i, (module, value)) in self.values.enumerated() {
            let color = self.color(for: value, moduleType: module)
            let radius = (diameter - lineWidth) / 2 - CGFloat(i) * spacing
            let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            track.lineWidth = lineWidth
            color.withAlphaComponent(0.25).setStroke()
            track.stroke()
            
            if let value, value > 0 {
                color.setStroke()
                if value == 1 {
                    track.stroke()
                } else {
                    let fill = NSBezierPath()
                    fill.lineWidth = lineWidth
                    fill.lineCapStyle = .round
                    fill.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - CGFloat(value) * 360, clockwise: true)
                    fill.stroke()
                }
            }
        }
    }
    
    private func drawDial() {
        guard !self.values.isEmpty else { return }
        let lineWidth: CGFloat = 2.5
        let radius = (min(20, self.bounds.height - 2) - lineWidth) / 2
        let center = NSPoint(x: self.bounds.midX, y: self.bounds.midY)
        let segment = 360 / CGFloat(self.values.count)
        let gap: CGFloat = self.values.count > 1 ? 32 : 0
        
        for (i, (module, value)) in self.values.enumerated() {
            let color = self.color(for: value, moduleType: module)
            let start = 90 - CGFloat(i) * segment - gap / 2
            let length = segment - gap
            let track = NSBezierPath()
            track.lineWidth = lineWidth
            track.lineCapStyle = .round
            track.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start - length, clockwise: true)
            color.withAlphaComponent(0.25).setStroke()
            track.stroke()
            
            if let value, value > 0 {
                let fill = NSBezierPath()
                fill.lineWidth = lineWidth
                fill.lineCapStyle = .round
                fill.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start - length * CGFloat(value), clockwise: true)
                color.setStroke()
                fill.stroke()
            }
        }
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.needsDisplay = true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    
    fileprivate func setValue(for module: ModuleType, with value: Double?) {
        let value = value.flatMap({ $0.isFinite ? min(max($0, 0), 1) : nil })
        if let index = self.values.firstIndex(where: { $0.0 == module }) {
            self.values[index].1 = value
        } else {
            self.values.append((module, value))
        }
    }
    
    fileprivate func update(_ list: [Module]) {
        self.values = list.map { module in
            (module.moduleType, self.values.first(where: { $0.0 == module.moduleType })?.1)
        }
        let width: CGFloat = CombinedModulesWidget.current == .bars ? max(22, CGFloat(self.values.count) * 6 + 2) : 22
        self.setFrameSize(NSSize(width: width, height: Constants.Widget.height))
        self.toolTip = list.map { module in
            let value = self.values.first(where: { $0.0 == module.moduleType })?.1.map({ "\(Int($0 * 100))%" }) ?? localizedString("Unknown")
            return "\(localizedString(module.name)): \(value)"
        }.joined(separator: "\n")
        self.needsDisplay = true
    }
}

private class SeparatorLineView: NSView {
    override var wantsUpdateLayer: Bool { true }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (self.isDarkMode ? NSColor.white : NSColor.black).cgColor
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.needsDisplay = true
    }
}

private class Popup: NSStackView, Popup_p {
    fileprivate var keyboardShortcut: [UInt16] = []
    fileprivate var sizeCallback: ((NSSize) -> Void)? = nil
    
    init() {
        self.keyboardShortcut = Store.shared.array(key: "CombinedModules_popup_keyboardShortcut", defaultValue: []) as? [UInt16] ?? []
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .width
        self.spacing = Constants.Popup.spacing*3
        
        self.reinit()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reinit), name: .toggleModule, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
    }
    
    fileprivate func settings() -> NSView? { return nil }
    fileprivate func appear() {}
    fileprivate func disappear() {}
    fileprivate func setKeyboardShortcut(_ binding: [UInt16]) {
        self.keyboardShortcut = binding
        Store.shared.set(key: "CombinedModules_popup_keyboardShortcut", value: binding)
    }
    
    @objc private func reinit() {
        self.subviews.forEach({ $0.removeFromSuperview() })
        
        let availableModules = modules.filter({ $0.enabled && $0.portal != nil })
        var modulesHeight: CGFloat = 0
        availableModules.forEach { (m: Module) in
            if let p = m.portal {
                modulesHeight += p.height
                self.addArrangedSubview(p)
                p.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
            }
        }
        
        let h = modulesHeight + (CGFloat(availableModules.count-1)*self.spacing)
        if h > 0 {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
}
