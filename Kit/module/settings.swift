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
    
    private var moduleSettingsContainer: NSStackView?
    private var widgetSettingsContainer: NSStackView?
    
    private var enableControl: NSControl?
    
    private let headerSeparator: NSView = {
        let view: NSView = NSView()
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hexString: "#d1d1d1").cgColor
        
        return view
    }()
    
    init(config: UnsafePointer<module_c>, widgets: UnsafeMutablePointer<[Widget]>, enabled: Bool, moduleSettings: Settings_v?) {
        self.config = config
        self.widgets = widgets.pointee
        self.moduleSettings = moduleSettings
        
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
        
        view.addArrangedSubview(WidgetSelectorView(widgets: self.widgets, stateCallback: self.loadWidget))
        view.addArrangedSubview(self.settings())
        
        return view
    }
    
    // MARK: - views
    
    private func settings() -> NSView {
        let view: NSTabView = NSTabView()
        view.widthAnchor.constraint(equalToConstant: Constants.Settings.width - Constants.Settings.margin*2).isActive = true
        view.heightAnchor.constraint(equalToConstant: Constants.Settings.height - 40 - Constants.Widget.height - (Constants.Settings.margin*5)).isActive = true
        view.tabViewType = .topTabsBezelBorder
        view.tabViewBorderType = .line
        
        let moduleTab: NSTabViewItem = NSTabViewItem()
        moduleTab.label = localizedString("Module settings")
        moduleTab.view = {
            let view = ScrollableStackView()
            self.moduleSettingsContainer = view.stackView
            self.loadModuleSettings()
            return view
        }()
        
        let widgetTab: NSTabViewItem = NSTabViewItem()
        widgetTab.label = localizedString("Widget settings")
        widgetTab.view = {
            let view = ScrollableStackView()
            view.stackView.spacing = 0
            self.widgetSettingsContainer = view.stackView
            self.loadWidgetSettings()
            return view
        }()
        
        view.addTabViewItem(moduleTab)
        view.addTabViewItem(widgetTab)
        
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
            return
        }
        
        for i in 0...list.count - 1 {
            self.widgetSettingsContainer?.addArrangedSubview(WidgetSettings(
                title: list[i].type.name(),
                image: list[i].image,
                settingsView: list[i].item.settings()
            ))
        }
    }
}

class WidgetSelectorView: NSStackView {
    private var stateCallback: () -> Void = {}
    
    public init(widgets: [Widget], stateCallback: @escaping () -> Void) {
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
                let preview = WidgetPreview(type: widget.type, image: widget.image, isActive: widget.isActive, { [weak self] state in
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
        
        let target = self.views[targetIdx]
        
        var newIdx = -1
        let originCenter = target.frame.midX
        let p0 = convert(event.locationInWindow, from: nil).x
        
        window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: 1e6, mode: .eventTracking) { event, stop in
            guard let event = event else {
                stop.pointee = true
                return
            }
            
            if event.type == .leftMouseDragged {
                let p1 = self.convert(event.locationInWindow, from: nil).x
                let diff = p1 - p0
                
                let reordered = self.views.map{
                    (view: $0, x: $0 !== target ? $0.frame.midX : originCenter + diff)
                }.sorted{ $0.x < $1.x }.map { $0.view }
                
                guard let nextIndex = reordered.firstIndex(of: target),
                      let prevIndex = self.views.firstIndex(of: target) else {
                    stop.pointee = true
                    return
                }
                
                if nextIndex != prevIndex && nextIndex != self.views.count - 1 {
                    newIdx = nextIndex
                    target.removeFromSuperviewWithoutNeedingDisplay()
                    self.insertArrangedSubview(target, at: newIdx)
                    self.layoutSubtreeIfNeeded()
                }
            } else {
                if newIdx != -1, let view = self.views[newIdx] as? WidgetPreview {
                    if newIdx <= separatorIdx && newIdx < targetIdx {
                        view.status(true)
                    } else if newIdx >= separatorIdx {
                        view.status(false)
                    }
                }
                
                target.mouseUp(with: event)
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
    
    public init(type: widget_t, image: NSImage, isActive: Bool, _ callback: @escaping (_ status: Bool) -> Void) {
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
