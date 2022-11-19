//
//  settings.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 13/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Settings_p: NSView {
    var toggleCallback: () -> Void { get set }
    func setState(_ newState: Bool)
}

public protocol Settings_v: NSView {
    var callback: (() -> Void) { get set }
    func load(widgets: [widget_t])
}

open class Settings: NSStackView, Settings_p {
    public var toggleCallback: () -> Void = {}
    
    private var config: UnsafePointer<module_c>
    private var widgets: [Widget]
    private var moduleSettings: Settings_v?
    private var popupSettings: Popup_p?
    
    private var moduleSettingsContainer: NSStackView?
    private var widgetSettingsContainer: NSStackView?
    private var popupSettingsContainer: NSStackView?
    
    private var enableControl: NSControl?
    
    private let headerSeparator: NSView = {
        let view: NSView = NSView()
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hexString: "#d1d1d1").cgColor
        
        return view
    }()
    private let noWidgetsView: EmptyView = EmptyView(msg: localizedString("No available widgets to configure"))
    private let noPopupSettingsView: EmptyView = EmptyView(msg: localizedString("No options to configure for the popup in this module"))
    
    private var oneViewState: Bool {
        get {
            return Store.shared.bool(key: "\(self.config.pointee.name)_oneView", defaultValue: false)
        }
        set {
            Store.shared.set(key: "\(self.config.pointee.name)_oneView", value: newValue)
        }
    }
    
    init(config: UnsafePointer<module_c>, widgets: UnsafeMutablePointer<[Widget]>, enabled: Bool, moduleSettings: Settings_v?, popupSettings: Popup_p?) {
        self.config = config
        self.widgets = widgets.pointee
        self.moduleSettings = moduleSettings
        self.popupSettings = popupSettings
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        
        NotificationCenter.default.addObserver(self, selector: #selector(externalModuleToggle), name: .toggleModule, object: nil)
        
        self.wantsLayer = true
        self.appearance = NSAppearance(named: .aqua)
        self.layer?.backgroundColor = NSColor(hexString: "#ececec").cgColor
        
        self.orientation = .vertical
        self.alignment = .width
        self.distribution = .fill
        self.spacing = 0
        
        self.addArrangedSubview(self.header(enabled))
        self.addArrangedSubview(self.headerSeparator)
        self.addArrangedSubview(self.body())
        
        self.addArrangedSubview(NSView())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - parts
    
    private func header(_ enabled: Bool) -> NSStackView {
        let view: NSStackView = NSStackView()
        
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.alignment = .centerY
        view.distribution = .fillProportionally
        view.spacing = 0
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        
        let titleView = NSTextField()
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .black
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 18, weight: .light)
        titleView.stringValue = localizedString(self.config.pointee.name)
        
        var toggleBtn: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch()
            switchButton.state = enabled ? .on : .off
            switchButton.action = #selector(self.toggleEnable)
            switchButton.target = self
            
            toggleBtn = switchButton
        } else {
            let button: NSButton = NSButton()
            button.setButtonType(.switch)
            button.state = enabled ? .on : .off
            button.title = ""
            button.action = #selector(self.toggleEnable)
            button.isBordered = false
            button.isTransparent = false
            button.target = self
            
            toggleBtn = button
        }
        self.enableControl = toggleBtn
        
        view.addArrangedSubview(titleView)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(toggleBtn)
        
        return view
    }
    
    private func body() -> NSStackView {
        let view: NSStackView = NSStackView()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.orientation = .vertical
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = Constants.Settings.margin
        
        view.addArrangedSubview(WidgetSelectorView(module: self.config.pointee.name, widgets: self.widgets, stateCallback: self.loadWidget))
        view.addArrangedSubview(self.settings())
        
        return view
    }
    
    // MARK: - views
    
    private func settings() -> NSView {
        let view: NSTabView = NSTabView(frame: NSRect(x: 0, y: 0,
            width: Constants.Settings.width - Constants.Settings.margin*2,
            height: Constants.Settings.height - 40 - Constants.Widget.height - (Constants.Settings.margin*5)
        ))
        view.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: view.frame.height).isActive = true
        view.tabViewType = .topTabsBezelBorder
        view.tabViewBorderType = .line
        
        let moduleTab: NSTabViewItem = NSTabViewItem()
        moduleTab.label = localizedString("Module settings")
        moduleTab.view = {
            let view = ScrollableStackView(frame: view.frame)
            self.moduleSettingsContainer = view.stackView
            self.loadModuleSettings()
            return view
        }()
        
        let widgetTab: NSTabViewItem = NSTabViewItem()
        widgetTab.label = localizedString("Widget settings")
        widgetTab.view = {
            let view = ScrollableStackView(frame: view.frame)
            view.stackView.spacing = 0
            self.widgetSettingsContainer = view.stackView
            self.loadWidgetSettings()
            return view
        }()
        
        let popupTab: NSTabViewItem = NSTabViewItem()
        popupTab.label = localizedString("Popup settings")
        popupTab.view = {
            let view = ScrollableStackView(frame: view.frame)
            view.stackView.spacing = 0
            self.popupSettingsContainer = view.stackView
            self.loadPopupSettings()
            return view
        }()
        
        view.addTabViewItem(moduleTab)
        view.addTabViewItem(widgetTab)
        view.addTabViewItem(popupTab)
        
        return view
    }
    
    // MARK: - helpers
    
    @objc private func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    @objc private func externalModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String {
            if name == self.config.pointee.name {
                if let state = notification.userInfo?["state"] as? Bool {
                    toggleNSControlState(self.enableControl, state: state ? .on : .off)
                }
            }
        }
    }
    
    public func setState(_ newState: Bool) {
        toggleNSControlState(self.enableControl, state: newState ? .on : .off)
    }
    
    private func loadWidget() {
        self.loadModuleSettings()
        self.loadWidgetSettings()
    }
    
    private func loadModuleSettings() {
        self.moduleSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        
        if let settingsView = self.moduleSettings {
            settingsView.load(widgets: self.widgets.filter{ $0.isActive }.map{ $0.type })
            self.moduleSettingsContainer?.addArrangedSubview(settingsView)
        } else {
            self.moduleSettingsContainer?.addArrangedSubview(NSView())
        }
    }
    
    private func loadWidgetSettings() {
        self.widgetSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        let list = self.widgets.filter({ $0.isActive && $0.type != .label })
        
        guard !list.isEmpty else {
            self.widgetSettingsContainer?.addArrangedSubview(self.noWidgetsView)
            return
        }
        
        if self.widgets.filter({ $0.isActive }).count > 1 {
            let container = NSStackView()
            container.orientation = .vertical
            container.distribution = .gravityAreas
            container.translatesAutoresizingMaskIntoConstraints = false
            container.edgeInsets = NSEdgeInsets(
                top: Constants.Settings.margin,
                left: Constants.Settings.margin,
                bottom: Constants.Settings.margin,
                right: Constants.Settings.margin
            )
            container.spacing = Constants.Settings.margin
            
            container.addArrangedSubview(toggleSettingRow(
                title: "\(localizedString("Merge widgets"))",
                action: #selector(self.toggleOneView),
                state: self.oneViewState
            ))
            
            self.widgetSettingsContainer?.addArrangedSubview(container)
        }
        
        for i in 0...list.count - 1 {
            self.widgetSettingsContainer?.addArrangedSubview(WidgetSettings(
                title: list[i].type.name(),
                image: list[i].image,
                settingsView: list[i].item.settings()
            ))
        }
    }
    
    private func loadPopupSettings() {
        self.popupSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        
        if let settingsView = self.popupSettings, let view = settingsView.settings() {
            self.popupSettingsContainer?.addArrangedSubview(view)
        } else {
            self.popupSettingsContainer?.addArrangedSubview(self.noPopupSettingsView)
        }
    }
    
    @objc private func toggleOneView(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.oneViewState = state! == .on ? true : false
        NotificationCenter.default.post(name: .toggleOneView, object: nil, userInfo: ["module": self.config.pointee.name])
    }
}

class WidgetSelectorView: NSStackView {
    private var module: String
    private var stateCallback: () -> Void = {}
    
    public init(module: String, widgets: [Widget], stateCallback: @escaping () -> Void) {
        self.module = module
        self.stateCallback = stateCallback
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.wantsLayer = true
        self.layer?.backgroundColor = .white
        self.layer?.cornerRadius = 3
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
        
        var active: [WidgetPreview] = []
        var inactive: [WidgetPreview] = []
        
        if !widgets.isEmpty {
            for i in 0...widgets.count - 1 {
                let widget = widgets[i]
                let preview = WidgetPreview(
                    id: "\(widget.module)_\(widget.type)",
                    type: widget.type,
                    image: widget.image,
                    isActive: widget.isActive, { [weak self] state in
                        widget.toggle(state)
                        self?.stateCallback()
                })
                if widget.isActive {
                    active.append(preview)
                } else {
                    inactive.append(preview)
                }
            }
        }
        
        active.sort(by: { $0.position < $1.position })
        inactive.sort(by: { $0.position < $1.position })
        
        active.forEach { (widget: WidgetPreview) in
            self.addArrangedSubview(widget)
        }
        
        let separator = NSView()
        separator.identifier = NSUserInterfaceItemIdentifier(rawValue: "separator")
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(hexString: "#d5d5d5").cgColor
        self.addArrangedSubview(separator)
        
        inactive.forEach { (widget: WidgetPreview) in
            self.addArrangedSubview(widget)
        }
        
        self.addArrangedSubview(NSView())
        
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: Constants.Widget.height + (Constants.Settings.margin*2)),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalTo: self.heightAnchor, constant: -6)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let targetIdx = self.views.firstIndex(where: { $0.hitTest(location) != nil }),
              let separatorIdx = self.views.firstIndex(where: { $0.identifier?.rawValue == "separator" }),
              let window = self.window, self.views[targetIdx].identifier != nil else {
            super.mouseDragged(with: event)
            return
        }
        
        let view = self.views[targetIdx]
        let copy = ViewCopy(view)
        copy.zPosition = 2
        copy.transform = CATransform3DMakeScale(0.9, 0.9, 1)
        
        // hide the original view, show the copy
        view.subviews.forEach({ $0.isHidden = true })
        self.layer?.addSublayer(copy)
        
        // hide the copy view, show the original
        defer {
            copy.removeFromSuperlayer()
            view.subviews.forEach({ $0.isHidden = false })
        }
        
        var newIdx = -1
        let originCenter = view.frame.midX
        let originX = view.frame.origin.x
        let p0 = convert(event.locationInWindow, from: nil).x
        
        window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: 1e6, mode: .eventTracking) { event, stop in
            guard let event = event else {
                stop.pointee = true
                return
            }
            
            if event.type == .leftMouseDragged {
                let p1 = self.convert(event.locationInWindow, from: nil).x
                let diff = p1 - p0
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                copy.frame.origin.x = originX + diff
                CATransaction.commit()
                
                let reordered = self.views.map{
                    (view: $0, x: $0 !== view ? $0.frame.midX : originCenter + diff)
                }.sorted{ $0.x < $1.x }.map { $0.view }
                
                guard let nextIndex = reordered.firstIndex(of: view),
                      let prevIndex = self.views.firstIndex(of: view) else {
                    stop.pointee = true
                    return
                }
                
                if nextIndex != prevIndex && nextIndex != self.views.count - 1 {
                    newIdx = nextIndex
                    view.removeFromSuperviewWithoutNeedingDisplay()
                    self.insertArrangedSubview(view, at: newIdx)
                    self.layoutSubtreeIfNeeded()
                    
                    for (i, v) in self.views(in: .leading).compactMap({$0 as? WidgetPreview}).enumerated() {
                        v.position = i
                    }
                }
            } else {
                if newIdx != -1, let view = self.views[newIdx] as? WidgetPreview {
                    if newIdx <= separatorIdx && newIdx < targetIdx {
                        view.status(true)
                    } else if newIdx >= separatorIdx {
                        view.status(false)
                    }
                    NotificationCenter.default.post(name: .widgetRearrange, object: nil, userInfo: ["module": self.module])
                }
                
                view.mouseUp(with: event)
                stop.pointee = true
            }
        }
    }
}

internal class WidgetPreview: NSStackView {
    private var stateCallback: (_ status: Bool) -> Void = {_ in }
    
    private let rgbImage: NSImage
    private let grayImage: NSImage
    private let imageView: NSImageView
    
    private var state: Bool
    private let id: String
    
    public var position: Int {
        get {
            return Store.shared.int(key: "\(self.id)_position", defaultValue: 0)
        }
        set {
            Store.shared.set(key: "\(self.id)_position", value: newValue)
        }
    }
    
    public init(id: String, type: widget_t, image: NSImage, isActive: Bool, _ callback: @escaping (_ status: Bool) -> Void) {
        self.id = id
        self.stateCallback = callback
        self.rgbImage = image
        self.grayImage = grayscaleImage(image) ?? image
        self.imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        self.state = isActive
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = NSColor(hexString: "#dddddd").cgColor
        self.layer?.borderWidth = 1
        
        self.identifier = NSUserInterfaceItemIdentifier(rawValue: type.rawValue)
        self.toolTip = localizedString("Move widget", type.name())
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .centerY
        self.spacing = 0
        
        self.imageView.image = isActive ? self.rgbImage : self.grayImage
        self.imageView.alphaValue = isActive ? 1 : 0.75
        
        self.addArrangedSubview(self.imageView)
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(
                x: Constants.Widget.spacing,
                y: 0,
                width: self.imageView.frame.width + Constants.Widget.spacing*2,
                height: self.frame.height
            ),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: self.imageView.frame.width + Constants.Widget.spacing*2),
            self.heightAnchor.constraint(equalToConstant: self.frame.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func status(_ newState: Bool) {
        self.state = newState
        self.stateCallback(newState)
        self.imageView.image = newState ? self.rgbImage : self.grayImage
        self.imageView.alphaValue = newState ? 1 : 0.8
    }
    
    override func mouseEntered(with: NSEvent) {
        NSCursor.pointingHand.set()
        if !self.state {
            self.imageView.image = self.rgbImage
            self.imageView.alphaValue = 0.9
        }
    }
    
    override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
        if !self.state {
            self.imageView.image = self.grayImage
            self.imageView.alphaValue = 0.8
        }
    }
}

internal class WidgetSettings: NSStackView {
    public init(title: String, image: NSImage, settingsView: NSView) {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.orientation = .vertical
        self.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Settings.margin,
            bottom: 0,
            right: Constants.Settings.margin
        )
        self.spacing = 0
        
        self.addArrangedSubview(self.header(title, image))
        self.addArrangedSubview(self.settings(settingsView))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func header(_ title: String, _ image: NSImage) -> NSView {
        let container = NSStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.orientation = .horizontal
        container.edgeInsets = NSEdgeInsets(
            top: 6,
            left: 0,
            bottom: 6,
            right: 0
        )
        container.spacing = 0
        container.distribution = .equalCentering
        
        let content = NSStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.orientation = .vertical
        content.distribution = .fill
        content.spacing = 0
        
        let title: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0), title)
        title.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        title.textColor = .textColor
        
        let imageContainer = NSStackView()
        imageContainer.orientation = .vertical
        imageContainer.spacing = 0
        imageContainer.wantsLayer = true
        imageContainer.layer?.backgroundColor = NSColor.white.cgColor
        imageContainer.layer?.cornerRadius = 2
        imageContainer.edgeInsets = NSEdgeInsets(
            top: 2,
            left: 2,
            bottom: 2,
            right: 2
        )
        
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        
        imageContainer.addArrangedSubview(imageView)
        
        content.addArrangedSubview(imageContainer)
        content.addArrangedSubview(title)
        
        container.addArrangedSubview(NSView())
        container.addArrangedSubview(content)
        container.addArrangedSubview(NSView())
        
        return container
    }
    
    private func settings(_ view: NSView) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 0
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.init(calibratedWhite: 0.1, alpha: 0.06).cgColor
        container.layer?.cornerRadius = 4
        container.edgeInsets = NSEdgeInsets(
            top: 2,
            left: 2,
            bottom: 2,
            right: 2
        )
        container.addArrangedSubview(view)
        
        return container
    }
}
