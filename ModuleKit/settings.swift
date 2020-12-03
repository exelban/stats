//
//  settings.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 13/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public protocol Settings_p: NSView {
    var toggleCallback: () -> () { get set }
    func setActiveWidget(_ widget: Widget_p?)
}

public protocol Settings_v: NSView {
    var callback: (() -> Void) { get set }
    func load(widget: widget_t)
}

open class Settings: NSView, Settings_p {
    public var toggleCallback: () -> () = {}
    
    private let headerHeight: CGFloat = 42
    private var widgetSelectorHeight: CGFloat = Constants.Widget.height + (Constants.Settings.margin*2)
    
    private var settingsView: NSView = NSView()
    
    private var widgetSelectorView: NSView? = nil
    private var widgetSettingsView: NSView? = nil
    private var moduleSettingsView: NSView? = nil
    
    private var config: UnsafePointer<module_c>
    private var activeWidget: Widget_p?
    
    private var moduleSettings: Settings_v?
    private var enableControl: NSControl?
    
    init(config: UnsafePointer<module_c>, enabled: Bool, activeWidget: Widget_p?, moduleSettings: Settings_v?) {
        self.config = config
        self.activeWidget = activeWidget
        self.moduleSettings = moduleSettings
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.wantsLayer = true
        self.appearance = NSAppearance(named: .aqua)
        self.layer?.backgroundColor = NSColor(hexString: "#ececec").cgColor
        
        NotificationCenter.default.addObserver(self, selector: #selector(externalModuleToggle), name: .toggleModule, object: nil)
        
        self.addHeader(state: enabled)
        self.addSettings()
        
        self.addWidgetSelector()
        self.addWidgetSettings()
        
        if self.moduleSettings != nil {
            self.moduleSettings?.load(widget: self.activeWidget?.type ?? .unknown)
            self.addModuleSettings()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSettings() {
        let view: NSScrollView = NSScrollView(frame: NSRect(
            x: 0,
            y: 0,
            width: self.frame.width,
            height: Constants.Settings.height - self.headerHeight
        ))
        view.wantsLayer = true
        view.backgroundColor = NSColor(hexString: "#ececec")
        
        view.translatesAutoresizingMaskIntoConstraints = true
        view.borderType = .noBorder
        view.hasVerticalScroller = true
        view.hasHorizontalScroller = false
        view.autohidesScrollers = true
        view.horizontalScrollElasticity = .none
        
        let settings: NSView = FlippedView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        settings.wantsLayer = true
        settings.layer?.backgroundColor = NSColor(hexString: "#ececec").cgColor
        
        view.documentView = settings
        
        self.addSubview(view)
        self.settingsView = settings
    }
    
    private func addWidgetSelector() {
        if self.config.pointee.availableWidgets.count == 0 {
            self.widgetSelectorHeight = 0
            return
        }
        
        let view: NSView = NSView(frame: NSRect(
            x : Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: self.settingsView.frame.width - (Constants.Settings.margin*2),
            height: self.widgetSelectorHeight
        ))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        var x: CGFloat = Constants.Settings.margin
        for i in 0...self.config.pointee.availableWidgets.count - 1 {
            let widgetType = self.config.pointee.availableWidgets[i]
            if let widget = LoadWidget(widgetType, preview: true, name: self.config.pointee.name, config: self.config.pointee.widgetsConfig, store: nil) {
                let preview = WidgetPreview(
                    frame: NSRect(
                        x: x,
                        y: Constants.Settings.margin,
                        width: widget.frame.width + (Constants.Widget.spacing*2),
                        height: self.widgetSelectorHeight - (Constants.Settings.margin*2)
                    ),
                    title: self.config.pointee.name,
                    widget: widget,
                    state: self.activeWidget?.type == widgetType
                )
                preview.widthCallback = { [weak self] in
                    self?.recalculateWidgetSelectorOptionsWidth()
                }
                view.addSubview(preview)
                x += preview.frame.width + Constants.Settings.margin
            }
        }
        
        self.settingsView.addSubview(view)
        self.widgetSelectorView = view
        self.resize()
    }
    
    private func addWidgetSettings() {
        if self.activeWidget == nil {
            return
        }
        
        var y: CGFloat = Constants.Settings.margin
        if self.widgetSelectorView != nil {
            y += self.widgetSelectorView!.frame.height + Constants.Settings.margin
        }
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: y,
            width: self.settingsView.frame.width - (Constants.Settings.margin*2),
            height: 0
        ))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        self.activeWidget?.settings(superview: view)
        
        if view.frame.height != 0 {
            self.settingsView.addSubview(view)
            self.widgetSettingsView = view
            self.resize()
        }
    }
    
    private func addModuleSettings() {
        if self.moduleSettings == nil || self.moduleSettings?.frame.height == 0 {
            return
        }
        
        var y: CGFloat = Constants.Settings.margin
        if self.widgetSelectorView != nil {
            y += self.widgetSelectorView!.frame.height + Constants.Settings.margin
        }
        if self.widgetSettingsView != nil {
            y += self.widgetSettingsView!.frame.height + Constants.Settings.margin
        }
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: y,
            width: self.settingsView.frame.width - (Constants.Settings.margin*2),
            height: self.moduleSettings?.frame.height ?? 0
        ))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        view.addSubview(self.moduleSettings!)
        
        self.settingsView.addSubview(view)
        self.moduleSettingsView = view
        self.resize()
    }
    
    private func resize() {
        var height: CGFloat = Constants.Settings.margin
        
        self.settingsView.subviews.forEach({ (v: NSView) in
            height += v.frame.height + Constants.Settings.margin
        })
        
        if self.settingsView.frame.height != height {
            self.settingsView.setFrameSize(NSSize(width: self.settingsView.frame.width, height: height))
        }
    }
    
    private func recalculateWidgetSelectorOptionsWidth() {
        var x: CGFloat = Constants.Settings.margin
        self.widgetSelectorView?.subviews.forEach({ (v: NSView) in
            v.setFrameOrigin(NSPoint(x: x, y: v.frame.origin.y))
            x += v.frame.width + Constants.Settings.margin
        })
    }
    
    private func addHeader(state: Bool) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.headerHeight, width: self.frame.width, height: self.headerHeight))
        view.wantsLayer = true
        
        let titleView = NSTextField(frame: NSRect(x: Constants.Settings.margin, y: (view.frame.height-20)/2, width: self.frame.width - 65, height: 20))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .black
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 18, weight: .light)
        titleView.stringValue = self.config.pointee.name
        
        var toggle: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: self.frame.width-55, y: 0, width: 50, height: view.frame.height))
            switchButton.state = state ? .on : .off
            switchButton.action = #selector(self.toggleEnable)
            switchButton.target = self
            
            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: self.frame.width-30, y: 0, width: 15, height: view.frame.height))
            button.setButtonType(.switch)
            button.state = state ? .on : .off
            button.title = ""
            button.action = #selector(self.toggleEnable)
            button.isBordered = false
            button.isTransparent = true
            button.target = self
            
            toggle = button
        }
        
        let line: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(hexString: "#d1d1d1").cgColor
        
        view.addSubview(titleView)
        view.addSubview(toggle)
        view.addSubview(line)
        
        self.enableControl = toggle
        self.addSubview(view)
    }
    
    @objc func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    @objc func externalModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String {
            if name == self.config.pointee.name {
                if let state = notification.userInfo?["state"] as? Bool {
                    ToggleNSControlState(self.enableControl, state: state ? .on : .off)
                }
            }
        }
    }
    
    public func setActiveWidget(_ widget: Widget_p?) {
        self.activeWidget = widget
        
        self.widgetSettingsView?.removeFromSuperview()
        self.moduleSettingsView?.removeFromSuperview()
        
        self.widgetSettingsView = nil
        self.addWidgetSettings()
        
        if self.moduleSettings != nil {
            self.moduleSettings?.load(widget: self.activeWidget?.type ?? .unknown)
            self.addModuleSettings()
        }
    }
}

open class FlippedView: NSView {
    open override var isFlipped: Bool { true }
}

class WidgetPreview: NSView {
    private let type: widget_t
    private var state: Bool
    private let title: String
    
    public var widthCallback: () -> Void = {}
    
    public init(frame: NSRect, title: String, widget: Widget_p, state: Bool) {
        self.type = widget.type
        self.state = state
        self.title = title
        
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector(maybeActivate), name: .switchWidget, object: nil)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = self.state ? NSColor.systemBlue.cgColor : NSColor(hexString: "#dddddd").cgColor
        self.layer?.borderWidth = 1
        
        self.toolTip = LocalizedString("Select widget", widget.name)
        
        let container: NSView = NSView(frame: NSRect(
            x: Constants.Widget.spacing,
            y: 0,
            width: frame.width - (Constants.Widget.spacing*2),
            height: frame.height
        ))
        container.wantsLayer = true
        container.addSubview(widget)
        
        self.addSubview(container)
        
        widget.widthHandler = { [weak self] value in
            self?.removeTrackingArea((self?.trackingAreas.first)!)
            let newWidth = value + (Constants.Widget.spacing*2)
            
            let rect = NSRect(x: 0, y: 0, width: newWidth, height: self!.frame.height)
            let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["menu": self!.type])
            self?.addTrackingArea(trackingArea)
            
            DispatchQueue.main.async(execute: {
                container.setFrameSize(NSSize(width: value, height: container.frame.height))
                self?.setFrameSize(NSSize(width: newWidth, height: self?.frame.height ?? Constants.Widget.height))
                self?.widthCallback()
            })
        }
        
        let rect = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["menu": self.type])
        self.addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with: NSEvent) {
        self.layer?.borderColor = NSColor.systemBlue.cgColor
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        self.layer?.borderColor = self.state ? NSColor.systemBlue.cgColor : NSColor.tertiaryLabelColor.cgColor
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        if !self.state {
            NotificationCenter.default.post(name: .switchWidget, object: nil, userInfo: ["module": self.title, "widget": self.type.rawValue])
        }
    }
    
    @objc private func maybeActivate(_ notification: Notification) {
        if let moduleName = notification.userInfo?["module"] as? String {
            if moduleName == self.title {
                if let widgetName = notification.userInfo?["widget"] as? String {
                    if widgetName == self.type.rawValue {
                        self.layer?.borderColor = NSColor.systemBlue.cgColor
                        self.state = true
                    } else {
                        self.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
                        self.state = false
                    }
                }
            }
        }
    }
}
