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
}

public protocol Settings_v: NSView {
    var callback: (() -> Void) { get set }
    func load(widgets: [widget_t])
}

open class Settings: NSView, Settings_p {
    public var toggleCallback: () -> () = {}
    
    private let headerHeight: CGFloat = 42
    
    private var config: UnsafePointer<module_c>
    private var store: UnsafePointer<Store>
    private var widgets: UnsafeMutablePointer<[Widget]>
    
    private var activeWidget: Widget? {
        get {
            return self.widgets.pointee.first{ $0.isActive }
        }
    }
    
    private var moduleSettings: Settings_v?
    private var enableControl: NSControl?
    private var container: ScrollableStackView?
    private var widgetSettings: widget_t?
    private var moduleSettingsContainer: NSView?
    
    init(store: UnsafePointer<Store>, config: UnsafePointer<module_c>, widgets: UnsafeMutablePointer<[Widget]>, enabled: Bool, moduleSettings: Settings_v?) {
        self.store = store
        self.config = config
        self.widgets = widgets
        self.moduleSettings = moduleSettings
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        
        self.wantsLayer = true
        self.appearance = NSAppearance(named: .aqua)
        self.layer?.backgroundColor = NSColor(hexString: "#ececec").cgColor
        
        NotificationCenter.default.addObserver(self, selector: #selector(externalModuleToggle), name: .toggleModule, object: nil)
        
        self.addSubview(self.header(state: enabled))
        self.addSubview(self.body())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Views
    
    private func header(state: Bool) -> NSView {
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
        
        return view
    }
    
    private func body() -> NSView {
        let view = ScrollableStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: Constants.Settings.height - self.headerHeight))
        view.stackView.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.stackView.spacing = Constants.Settings.margin
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hexString: "#ececec").cgColor
        self.container = view
        
        self.initWidgetSelector()
        self.initModuleSettings()
        
        return view
    }
    
    private func initWidgetSelector() {
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height + (Constants.Settings.margin*2)))
        container.wantsLayer = true
        container.layer?.backgroundColor = .white
        container.layer?.cornerRadius = 3
        
        let view: NSStackView = NSStackView()
        view.orientation = .horizontal
        view.translatesAutoresizingMaskIntoConstraints = false
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = Constants.Settings.margin
        
        for i in 0...self.widgets.pointee.count - 1 {
            let preview = WidgetPreview(&self.widgets.pointee[i])
            preview.settingsCallback = { [weak self] value in
                self?.toggleSettings(value)
            }
            preview.stateCallback = { [weak self] in
                self?.widgetStateCallback()
            }
            view.addArrangedSubview(preview)
        }
        
        container.addSubview(view)
        
        if let view = self.container {
            view.stackView.addArrangedSubview(container)
        }
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: container.frame.height),
            view.heightAnchor.constraint(equalTo: container.heightAnchor),
        ])
    }
    
    private func initModuleSettings() {
        guard let settingsView = self.moduleSettings else {
            return
        }
        
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        container.wantsLayer = true
        container.layer?.backgroundColor = .white
        container.layer?.cornerRadius = 3
        self.moduleSettingsContainer = container
        
        self.moduleSettings?.load(widgets: self.widgets.pointee.filter{ $0.isActive }.map{ $0.type })
        
        container.addSubview(settingsView)
        if let view = self.container {
            view.stackView.addArrangedSubview(container)
        }
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalTo: settingsView.heightAnchor),
        ])
    }
    
    // MARK: - helpers
    
    private func toggleSettings(_ type: widget_t) {
        guard let widget = self.widgets.pointee.first(where: { $0.type == type }) else {
            return
        }
        
        let container: NSView = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = .white
        container.layer?.cornerRadius = 3
        
        let width: CGFloat = (self.container?.clipView.bounds.width ?? self.frame.width) - (Constants.Settings.margin*2)
        let settingsView = widget.item.settings(width: width)
        container.addSubview(settingsView)
        
        if let view = self.container {
            if self.widgetSettings == nil {
                view.stackView.insertArrangedSubview(container, at: 1)
                self.widgetSettings = type
            } else if self.widgetSettings != nil && self.widgetSettings == type {
                view.stackView.arrangedSubviews[1].removeFromSuperview()
                self.widgetSettings = nil
            } else {
                view.stackView.arrangedSubviews[1].removeFromSuperview()
                self.widgetSettings = type
                view.stackView.insertArrangedSubview(container, at: 1)
            }
        }
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalTo: settingsView.heightAnchor),
        ])
    }
    
    @objc private func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    @objc private func externalModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String {
            if name == self.config.pointee.name {
                if let state = notification.userInfo?["state"] as? Bool {
                    ToggleNSControlState(self.enableControl, state: state ? .on : .off)
                }
            }
        }
    }
    
    @objc private func widgetStateCallback() {
        guard let container = self.moduleSettingsContainer, let settingsView = self.moduleSettings else {
            return
        }
        
        container.subviews.forEach{ $0.removeFromSuperview() }
        settingsView.load(widgets: self.widgets.pointee.filter{ $0.isActive }.map{ $0.type })
        self.moduleSettingsContainer?.addSubview(settingsView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalTo: settingsView.heightAnchor),
        ])
    }
}

internal class WidgetPreview: NSStackView {
    public var settingsCallback: (widget_t) -> Void = {_ in }
    public var stateCallback: () -> Void = {}
    
    private var widget: UnsafeMutablePointer<Widget>
    private var size: CGFloat = Constants.Widget.height
    
    public init(_ widget: UnsafeMutablePointer<Widget>) {
        self.widget = widget
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: widget.pointee.preview.frame.width + self.size + (Constants.Widget.spacing*2),
            height: self.size
        ))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = self.widget.pointee.isActive ? NSColor.systemBlue.cgColor : NSColor(hexString: "#dddddd").cgColor
        self.layer?.borderWidth = 1
        self.toolTip = LocalizedString("Select widget", widget.pointee.type.name())
        
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Widget.spacing,
            bottom: 0,
            right: Constants.Widget.spacing
        )
        
        let container: NSView = NSView(frame: NSRect(
            x: Constants.Widget.spacing,
            y: 0,
            width: widget.pointee.preview.frame.width,
            height: self.frame.height
        ))
        container.wantsLayer = true
        container.addSubview(widget.pointee.preview)
        
        self.addArrangedSubview(container)
        self.addArrangedSubview(self.separator())
        self.addArrangedSubview(self.button())
        
        widget.pointee.preview.widthHandler = { [weak self] value in
            self?.trackingAreas.forEach({ (area: NSTrackingArea) in
                self?.removeTrackingArea(area)
            })
            
            let rect = NSRect(x: Constants.Widget.spacing, y: 0, width: value, height: self!.frame.height)
            let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: nil)
            self?.addTrackingArea(trackingArea)
        }
        
        let rect = NSRect(x: Constants.Widget.spacing, y: 0, width: container.frame.width, height: self.frame.height)
        self.addTrackingArea(NSTrackingArea(
            rect: rect,
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        let additionalConstant: CGFloat = self.size + (Constants.Widget.spacing*3) + 1
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalTo: self.widget.pointee.preview.widthAnchor, constant: additionalConstant),
            self.heightAnchor.constraint(equalToConstant: self.size)
        ])
    }
    
    private func button() -> NSView {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: self.size, height: self.size))
        button.title = LocalizedString("Open widget settings")
        button.toolTip = LocalizedString("Open widget settings")
        button.bezelStyle = .regularSquare
        if let image = Bundle(for: type(of: self)).image(forResource: "widget_settings") {
            button.image = image
        }
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .lightGray
        button.isBordered = false
        button.action = #selector(self.toggleSettings)
        button.target = self
        button.focusRingType = .none
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: button.frame.width),
        ])
        
        return button
    }
    
    private func separator() -> NSView {
        let separator = NSView()
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(hexString: "#dddddd").cgColor
        
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: self.size),
        ])
        
        return separator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func toggleSettings() {
        self.settingsCallback(self.widget.pointee.type)
    }
    
    override func mouseEntered(with: NSEvent) {
        self.layer?.borderColor = NSColor.systemBlue.cgColor
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        self.layer?.borderColor = self.widget.pointee.isActive ? NSColor.systemBlue.cgColor : NSColor.tertiaryLabelColor.cgColor
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        self.widget.pointee.toggle()
        self.stateCallback()
    }
}
