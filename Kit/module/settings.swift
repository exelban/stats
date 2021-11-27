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
    private var widgets: UnsafeMutablePointer<[Widget]>
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
        self.widgets = widgets
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
        
        view.addArrangedSubview(self.widgetSelector())
        view.addArrangedSubview(self.settings())
        
        return view
    }
    
    // MARK: - views
    
    private func widgetSelector() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: Constants.Widget.height + (Constants.Settings.margin*2)).isActive = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        view.layer?.cornerRadius = 3
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = Constants.Settings.margin
        
        if !self.widgets.pointee.isEmpty {
            for i in 0...self.widgets.pointee.count - 1 {
                let preview = WidgetPreview(&self.widgets.pointee[i])
                preview.stateCallback = { [weak self] in
                    self?.loadModuleSettings()
                    self?.loadWidgetSettings()
                }
                view.addArrangedSubview(preview)
            }
        }
        view.addArrangedSubview(NSView())
        
        return view
    }
    
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
    
    @objc private func loadModuleSettings() {
        self.moduleSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        
        if let settingsView = self.moduleSettings {
            settingsView.load(widgets: self.widgets.pointee.filter{ $0.isActive }.map{ $0.type })
            self.moduleSettingsContainer?.addArrangedSubview(settingsView)
        } else {
            self.moduleSettingsContainer?.addArrangedSubview(NSView())
        }
    }
    
    @objc private func loadWidgetSettings() {
        self.widgetSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        let list = self.widgets.pointee.filter({ $0.isActive && $0.type != .label })
        
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

internal class WidgetPreview: NSStackView {
    public var stateCallback: () -> Void = {}
    
    private var widget: UnsafeMutablePointer<Widget>
    
    public init(_ widget: UnsafeMutablePointer<Widget>) {
        self.widget = widget
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = widget.pointee.isActive ? NSColor.systemBlue.cgColor : NSColor(hexString: "#dddddd").cgColor
        self.layer?.borderWidth = 1
        self.toolTip = localizedString("Select widget", widget.pointee.type.name())
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .centerY
        self.spacing = 0
        
        let image = NSImageView(frame: NSRect(origin: .zero, size: widget.pointee.image.size))
        image.image = widget.pointee.image
        
        self.addArrangedSubview(image)
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(
                x: Constants.Widget.spacing,
                y: 0,
                width: image.frame.width + Constants.Widget.spacing*2,
                height: self.frame.height
            ),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: image.frame.width + Constants.Widget.spacing*2),
            self.heightAnchor.constraint(equalToConstant: self.frame.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with: NSEvent) {
        self.layer?.borderColor = NSColor.systemBlue.cgColor
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        self.layer?.borderColor = self.widget.pointee.isActive ? NSColor.systemBlue.cgColor : NSColor(hexString: "#dddddd").cgColor
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        self.widget.pointee.toggle()
        self.stateCallback()
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
