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

public protocol Settings_p: NSView {
    var toggleCallback: () -> () { get set }
    func setActiveWidget(_ widget: Widget_p?)
}

public protocol Settings_v: NSView {
    func load(rect: NSRect, widget: widget_t)
}

open class Settings: NSView, Settings_p {
    public var toggleCallback: () -> () = {}
    
    private let headerHeight: CGFloat = 42
    private var widgetSelectorHeight: CGFloat = Constants.Widget.height + (Constants.Settings.margin*2)
    
    private var widgetSelectorView: NSView? = nil
    private var widgetSettingsView: NSView? = nil
    private var moduleSettingsView: NSView? = nil
    
    private var config: UnsafePointer<module_c>
    private var activeWidget: Widget_p?
    
    private var moduleSettings: (_ superview: NSView) -> ()
    
    init(config: UnsafePointer<module_c>, enabled: Bool, activeWidget: Widget_p?, moduleSettings: @escaping (_ superview: NSView) -> ()) {
        self.config = config
        self.activeWidget = activeWidget
        self.moduleSettings = moduleSettings
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        addHeader(state: enabled)
        addWidgetSelector()
        addWidgetSettings()
        addModuleSettings()
    }
    
    private func addModuleSettings() {
        let y: CGFloat = self.frame.height - headerHeight - widgetSelectorHeight - (self.widgetSettingsView?.frame.height ?? 0)
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: y - (Constants.Settings.margin*3), width: self.frame.width - (Constants.Settings.margin*2), height: 0))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        self.appearance = NSAppearance(named: .aqua)
        
        self.moduleSettings(view)
        
        if view.frame.height != 0 {
            view.setFrameOrigin(NSPoint(x: view.frame.origin.x, y: view.frame.origin.y - view.frame.height))
            self.addSubview(view)
            self.moduleSettingsView = view
        }
    }
    
    private func addWidgetSettings() {
        if self.activeWidget == nil {
            return
        }
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: self.frame.height - headerHeight - widgetSelectorHeight - (Constants.Settings.margin*2), width: self.frame.width - (Constants.Settings.margin*2), height: 0))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        self.activeWidget?.settings(superview: view)
        
        if view.frame.height != 0 {
            view.setFrameOrigin(NSPoint(x: view.frame.origin.x, y: view.frame.origin.y - view.frame.height))
            self.addSubview(view)
            self.widgetSettingsView = view
        }
    }
    
    private func addWidgetSelector() {
        if self.config.pointee.availableWidgets.count == 0 {
            self.widgetSelectorHeight = 0
            return
        }
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: self.frame.height - self.headerHeight - self.widgetSelectorHeight - Constants.Settings.margin, width: self.frame.width - (Constants.Settings.margin*2), height: self.widgetSelectorHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer!.cornerRadius = 3
        
        var x: CGFloat = Constants.Settings.margin
        for i in 0...self.config.pointee.availableWidgets.count - 1 {
            let widgetType = self.config.pointee.availableWidgets[i]
            if let widget = LoadWidget(widgetType, preview: true, title: self.config.pointee.name, config: self.config.pointee.widgetsConfig, store: nil) {
                let preview = WidgetPreview(
                    frame: NSRect(x: x, y: Constants.Settings.margin, width: widget.frame.width, height: self.widgetSelectorHeight - (Constants.Settings.margin*2)),
                    title: self.config.pointee.name,
                    widget: widget,
                    state: self.activeWidget?.type == widgetType
                )
                preview.widthCallback = { [weak self] in
                    self?.recalculateWidgetSelectorOptionsWidth()
                }
                view.addSubview(preview)
                x += widget.frame.width + Constants.Settings.margin
            }
        }
        
        self.addSubview(view)
        self.widgetSelectorView = view
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
            let button: NSButton = NSButton(frame: NSRect(x: self.frame.width-55, y: 0, width: 30, height: view.frame.height))
            button.setButtonType(.switch)
            button.state = state ? .on : .off
            button.title = ""
            button.action = #selector(self.toggleEnable)
            button.isBordered = false
            button.isTransparent = true
            
            toggle = button
        }
        
        let line: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(hexString: "#d1d1d1").cgColor
        
        view.addSubview(titleView)
        view.addSubview(toggle)
        view.addSubview(line)
        
        self.addSubview(view)
    }
    
    @objc func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    public func setActiveWidget(_ widget: Widget_p?) {
        self.activeWidget = widget
        
        self.subviews.filter{ $0 == self.widgetSettingsView || $0 == self.moduleSettingsView }.forEach{ $0.removeFromSuperview() }
        self.addWidgetSettings()
        self.addModuleSettings()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
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
        
        widget.widthHandler = { [weak self] value in
            self?.removeTrackingArea((self?.trackingAreas.first)!)
            
            let rect = NSRect(x: 0, y: 0, width: value, height: self!.frame.height)
            let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["menu": self!.type])
            self?.addTrackingArea(trackingArea)
            
            DispatchQueue.main.async(execute: {
                self?.setFrameSize(NSSize(width: value, height: self?.frame.height ?? Constants.Widget.height))
                self?.widthCallback()
            })
        }
        self.addSubview(widget)
        
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
