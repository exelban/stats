//
//  Settings.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 12/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public extension NSToolbarItem.Identifier {
    static let toggleButton = NSToolbarItem.Identifier("toggleButton")
}

class SettingsWindow: NSWindow, NSWindowDelegate, NSToolbarDelegate {
    static let size: CGSize = CGSize(width: 720, height: 480)
    
    private let mainView: MainView = MainView(frame: NSRect(x: 0, y: 0, width: 540, height: 480))
    private let sidebarView: SidebarView = SidebarView(frame: NSRect(x: 0, y: 0, width: 180, height: 480))
    
    private var dashboard: NSView = Dashboard()
    private var settings: ApplicationSettings = ApplicationSettings()
    
    private var toggleButton: NSControl? = nil
    private var activeModuleName: String? = nil
    
    private var pauseState: Bool {
        Store.shared.bool(key: "pause", defaultValue: false)
    }
    
    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - SettingsWindow.size.width,
                y: NSScreen.main!.frame.height - SettingsWindow.size.height,
                width: SettingsWindow.size.width,
                height: SettingsWindow.size.height
            ),
            styleMask: [.closable, .titled, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        let sidebarViewController = NSSplitViewController()
        
        let sidebarVC: NSViewController = NSViewController(nibName: nil, bundle: nil)
        sidebarVC.view = self.sidebarView
        let mainVC: NSViewController = NSViewController(nibName: nil, bundle: nil)
        mainVC.view = self.mainView
        
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        let contentItem = NSSplitViewItem(viewController: mainVC)
        
        sidebarItem.canCollapse = false
        contentItem.canCollapse = false
        
        sidebarViewController.addSplitViewItem(sidebarItem)
        sidebarViewController.addSplitViewItem(contentItem)
        
        let newToolbar = NSToolbar(identifier: "eu.exelban.Stats.Settings.Toolbar")
        newToolbar.allowsUserCustomization = false
        newToolbar.autosavesConfiguration = true
        newToolbar.displayMode = .default
        newToolbar.showsBaselineSeparator = true
        newToolbar.delegate = self
        
        self.toolbar = newToolbar
        self.contentViewController = sidebarViewController
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.positionCenter()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
        
        NSLayoutConstraint.activate([
            self.sidebarView.widthAnchor.constraint(equalToConstant: 180),
            self.mainView.widthAnchor.constraint(equalToConstant: 540),
            self.mainView.container.widthAnchor.constraint(equalToConstant: 540),
            self.mainView.container.topAnchor.constraint(equalTo: (self.contentLayoutGuide as! NSLayoutGuide).topAnchor),
            self.mainView.container.bottomAnchor.constraint(equalTo: (self.contentLayoutGuide as! NSLayoutGuide).bottomAnchor)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(menuCallback), name: .openModuleSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleSettingsHandler), name: .toggleSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(externalModuleToggle), name: .toggleModule, object: nil)
        
        self.sidebarView.openMenu("Dashboard")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleSettings, object: nil)
        NotificationCenter.default.removeObserver(self, name: .openModuleSettings, object: nil)
        NotificationCenter.default.removeObserver(self, name: .toggleModule, object: nil)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown && event.modifierFlags.contains(.command) {
            if event.keyCode == 12 || event.keyCode == 13 {
                self.setIsVisible(false)
                return true
            } else if event.keyCode == 46 {
                self.miniaturize(event)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func mouseUp(with: NSEvent) {
        NotificationCenter.default.post(name: .clickInSettings, object: nil, userInfo: nil)
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleButton:
            var toggleBtn: NSControl = NSControl()
            if #available(OSX 10.15, *) {
                let switchButton = NSSwitch()
                switchButton.state = .on
                switchButton.action = #selector(self.toggleEnable)
                switchButton.target = self
                toggleBtn = switchButton
            } else {
                let button: NSButton = NSButton()
                button.setButtonType(.switch)
                button.state = .on
                button.title = ""
                button.action = #selector(self.toggleEnable)
                button.isBordered = false
                button.isTransparent = false
                button.target = self
                toggleBtn = button
            }
            self.toggleButton = toggleBtn
            
            let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            toolbarItem.toolTip = "Toggle the module"
            toolbarItem.view = toggleBtn
            
            return toolbarItem
        default:
            return nil
        }
    }
        
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .toggleButton]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .toggleButton]
    }
    
    @objc private func toggleSettingsHandler(_ notification: Notification) {
        if !self.isVisible {
            self.setIsVisible(true)
            self.makeKeyAndOrderFront(nil)
        }
        if !self.isKeyWindow {
            self.orderFrontRegardless()
        }
        
        if var name = notification.userInfo?["module"] as? String {
            if name == "Combined modules" { name = "Dashboard" }
            self.sidebarView.openMenu(name)
        }
    }
    
    @objc private func menuCallback(_ notification: Notification) {
        if let title = notification.userInfo?["module"] as? String {
            var view: NSView = NSView()
            if let detectedModule = modules.first(where: { $0.config.name == title }) {
                if let v = detectedModule.settings {
                    view = v
                }
                self.activeModuleName = detectedModule.config.name
                toggleNSControlState(self.toggleButton, state: detectedModule.enabled ? .on : .off)
                self.toggleButton?.isHidden = false
            } else if title == "Dashboard" {
                view = self.dashboard
                self.toggleButton?.isHidden = true
            } else if title == "Settings" {
                self.settings.viewWillAppear()
                view = self.settings
                self.toggleButton?.isHidden = true
            }
            
            self.title = localizedString(title)
            
            self.mainView.setView(view)
            self.sidebarView.openMenu(title)
        }
    }
    
    @objc private func toggleEnable(_ sender: NSControl) {
        guard let moduleName = self.activeModuleName else { return }
        NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": moduleName, "state": controlState(sender)])
    }
    
    @objc private func externalModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String, name == self.activeModuleName {
            if let state = notification.userInfo?["state"] as? Bool {
                toggleNSControlState(self.toggleButton, state: state ? .on : .off)
            }
        }
    }
    
    public func setModules() {
        self.sidebarView.setModules(modules)
        if !self.pauseState && modules.filter({ $0.enabled != false && $0.available != false && !$0.menuBar.widgets.filter({ $0.isActive }).isEmpty }).isEmpty {
            self.setIsVisible(true)
        }
    }
    
    private func positionCenter() {
        self.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - SettingsWindow.size.width)/2,
            y: ((NSScreen.main!.frame.height - SettingsWindow.size.height)/1.75)
        ))
    }
}

// MARK: - MainView

private class MainView: NSView {
    public let container: NSStackView
    
    override init(frame: NSRect) {
        self.container = NSStackView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        
        let foreground = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        foreground.blendingMode = .withinWindow
        foreground.material = .windowBackground
        foreground.state = .active
        
        super.init(frame: NSRect.zero)
        
        self.container.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(foreground, positioned: .below, relativeTo: .none)
        self.addSubview(self.container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setView(_ view: NSView) {
        self.container.subviews.forEach{ $0.removeFromSuperview() }
        self.container.addArrangedSubview(view)
        
        NSLayoutConstraint.activate([
            view.leftAnchor.constraint(equalTo: self.container.leftAnchor),
            view.rightAnchor.constraint(equalTo: self.container.rightAnchor),
            view.topAnchor.constraint(equalTo: self.container.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.container.bottomAnchor)
        ])
    }
}

// MARK: - Sidebar

private class SidebarView: NSStackView {
    private let scrollView: ScrollableStackView
    
    private let supportPopover = NSPopover()
    private var pauseButton: NSButton? = nil
    
    private var pauseState: Bool {
        get {
            return Store.shared.bool(key: "pause", defaultValue: false)
        }
        set {
            Store.shared.set(key: "pause", value: newValue)
        }
    }
    
    private var dashboardIcon: NSImage {
        if #available(macOS 11.0, *), let icon = NSImage(systemSymbolName: "circle.grid.3x3.fill", accessibilityDescription: nil) {
            return icon
        }
        return NSImage(named: NSImage.Name("apps"))!
    }
    private var settingsIcon: NSImage {
        if #available(macOS 11.0, *), let icon = NSImage(systemSymbolName: "gear", accessibilityDescription: nil) {
            return icon
        }
        return NSImage(named: NSImage.Name("settings"))!
    }
    
    private var bugIcon: NSImage {
        if #available(macOS 12.0, *), let icon = iconFromSymbol(name: "ladybug", scale: .large) {
            return icon
        }
        return NSImage(named: NSImage.Name("bug"))!
    }
    private var supportIcon: NSImage {
        if #available(macOS 12.0, *), let icon = iconFromSymbol(name: "heart.fill", scale: .large) {
            return icon
        }
        return NSImage(named: NSImage.Name("donate"))!
    }
    private var pauseIcon: NSImage {
        if #available(macOS 11.0, *), let icon = iconFromSymbol(name: "pause.fill", scale: .large) {
            return icon
        }
        return NSImage(named: NSImage.Name("pause"))!
    }
    private var resumeIcon: NSImage {
        if #available(macOS 11.0, *), let icon = iconFromSymbol(name: "play.fill", scale: .large) {
            return icon
        }
        return NSImage(named: NSImage.Name("resume"))!
    }
    private var closeIcon: NSImage {
        if #available(macOS 12.0, *), let icon = iconFromSymbol(name: "power", scale: .large) {
            return icon
        }
        return NSImage(named: NSImage.Name("power"))!
    }
    
    override init(frame: NSRect) {
        self.scrollView = ScrollableStackView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        self.scrollView.stackView.spacing = 0
        self.scrollView.stackView.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        
        super.init(frame: frame)
        self.orientation = .vertical
        self.spacing = 0
        self.widthAnchor.constraint(equalToConstant: frame.width).isActive = true
        
        let spacer = NSView()
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        
        self.scrollView.stackView.addArrangedSubview(MenuItem(icon: self.dashboardIcon, title: "Dashboard"))
        self.scrollView.stackView.addArrangedSubview(spacer)
        self.scrollView.stackView.addArrangedSubview(MenuItem(icon: self.settingsIcon, title: "Settings"))
        
        self.supportPopover.behavior = .transient
        self.supportPopover.contentViewController = self.supportView()
        
        let additionalButtons: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: frame.width, height: 45))
        additionalButtons.heightAnchor.constraint(equalToConstant: 45).isActive = true
        additionalButtons.orientation = .horizontal
        additionalButtons.distribution = .fillEqually
        additionalButtons.alignment = .centerY
        additionalButtons.spacing = 0
        
        let pauseButton = self.makeButton(title: localizedString("Pause the Stats"), image: self.pauseState ? self.resumeIcon : self.pauseIcon, action: #selector(togglePause))
        self.pauseButton = pauseButton
        
        additionalButtons.addArrangedSubview(self.makeButton(title: localizedString("Report a bug"), image: self.bugIcon, action: #selector(reportBug)))
        additionalButtons.addArrangedSubview(self.makeButton(title: localizedString("Support the application"), image: self.supportIcon, action: #selector(donate)))
        additionalButtons.addArrangedSubview(pauseButton)
        additionalButtons.addArrangedSubview(self.makeButton(title: localizedString("Close application"), image: self.closeIcon, action: #selector(closeApp)))
        
        let emptySpace = NSView()
        emptySpace.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        if #unavailable(macOS 11) {
            self.addArrangedSubview(emptySpace)
        }
        self.addArrangedSubview(self.scrollView)
        self.addArrangedSubview(additionalButtons)
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForPause), name: .pause, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .pause, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func openMenu(_ title: String) {
        self.scrollView.stackView.subviews.forEach({ (m: NSView) in
            if let menu = m as? MenuItem {
                if menu.title == title {
                    menu.activate()
                } else {
                    menu.reset()
                }
            }
        })
    }
    
    public func setModules(_ list: [Module]) {
        list.reversed().forEach { (m: Module) in
            if !m.available { return }
            let menu: NSView = MenuItem(icon: m.config.icon, title: m.config.name)
            self.scrollView.stackView.insertArrangedSubview(menu, at: 2)
        }
        
        let spacer = NSView()
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        self.scrollView.stackView.insertArrangedSubview(spacer, at: self.scrollView.stackView.subviews.count - 1)
    }
    
    private func makeButton(title: String, image: NSImage, action: Selector) -> NSButton {
        let button = NSButton()
        button.title = title
        button.toolTip = title
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleNone
        button.image = image
        button.contentTintColor = .secondaryLabelColor
        button.isBordered = false
        button.action = action
        button.target = self
        button.focusRingType = .none
        button.widthAnchor.constraint(equalToConstant: 45).isActive = true
        
        let rect = NSRect(x: 0, y: 0, width: 45, height: 45)
        let trackingArea = NSTrackingArea(
            rect: rect,
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: ["button": title]
        )
        self.addTrackingArea(trackingArea)
        
        return button
    }
    
    private func supportView() -> NSViewController {
        let vc: NSViewController = NSViewController(nibName: nil, bundle: nil)
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 160, height: 40))
        view.spacing = 7
        view.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        view.orientation = .horizontal
        
        let github = SupportButtonView(name: "GitHub Sponsors", image: "github", action: {
            NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/exelban")!)
        })
        let paypal = SupportButtonView(name: "PayPal", image: "paypal", action: {
            NSWorkspace.shared.open(URL(string: "https://www.paypal.com/donate?hosted_button_id=3DS5JHDBATMTC")!)
        })
        let koFi = SupportButtonView(name: "Ko-fi", image: "ko-fi", action: {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/exelban")!)
        })
        let patreon = SupportButtonView(name: "Patreon", image: "patreon", action: {
            NSWorkspace.shared.open(URL(string: "https://patreon.com/exelban")!)
        })
        
        view.addArrangedSubview(github)
        view.addArrangedSubview(paypal)
        view.addArrangedSubview(koFi)
        view.addArrangedSubview(patreon)
        
        vc.view = view
        return vc
    }
    
    private func supportButton(name: String, image: String, action: Selector) -> NSButton {
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        button.verticalPadding = 16
        button.horizontalPadding = 16
        button.title = name
        button.toolTip = name
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleNone
        button.image = Bundle(for: type(of: self)).image(forResource: image)!
        button.isBordered = false
        button.target = self
        button.focusRingType = .none
        button.action = action
        
        return button
    }
    
    @objc private func reportBug(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats/issues/new")!)
    }
    
    @objc private func donate(_ sender: NSButton) {
        self.supportPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.minY)
    }
    
    @objc private func closeApp(_ sender: Any) {
        NSApp.terminate(sender)
    }
    
    @objc private func togglePause(_ sender: NSButton) {
        self.pauseState = !self.pauseState
        self.pauseButton?.toolTip = localizedString(self.pauseState ? "Resume the Stats" : "Pause the Stats")
        self.pauseButton?.image = self.pauseState ? self.resumeIcon : self.pauseIcon
        NotificationCenter.default.post(name: .pause, object: nil, userInfo: ["state": self.pauseState])
    }
    
    @objc func listenForPause() {
        self.pauseButton?.toolTip = localizedString(self.pauseState ? "Resume the Stats" : "Pause the Stats")
        self.pauseButton?.image = self.pauseState ? self.resumeIcon : self.pauseIcon
    }
}

private class MenuItem: NSView {
    public let title: String
    public var active: Bool = false
    
    private var imageView: NSImageView? = nil
    private var titleView: NSTextField? = nil
    
    init(icon: NSImage?, title: String) {
        self.title = title
        
        super.init(frame: NSRect.zero)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 5
        
        var toolTip = ""
        if title == "Settings" {
            toolTip = localizedString("Open application settings")
        } else if title == "Dashboard" {
            toolTip = localizedString("Open dashboard")
        } else {
            toolTip = localizedString("Open \(title) settings")
        }
        self.toolTip = toolTip
        
        let imageView = NSImageView()
        if icon != nil {
            imageView.image = icon!
        }
        imageView.frame = NSRect(x: 8, y: (32 - 18)/2, width: 18, height: 18)
        imageView.wantsLayer = true
        imageView.contentTintColor = .labelColor
        self.imageView = imageView
        
        let titleView = TextView(frame: NSRect(x: 34, y: ((32 - 16)/2) + 1, width: 100, height: 16))
        titleView.textColor = .labelColor
        titleView.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleView.stringValue = localizedString(title)
        self.titleView = titleView
        
        self.addSubview(imageView)
        self.addSubview(titleView)
        
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with: NSEvent) {
        self.activate()
    }
    
    public func activate() {
        guard !self.active else { return }
        self.active = true
        
        NotificationCenter.default.post(name: .openModuleSettings, object: nil, userInfo: ["module": self.title])
        
        self.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        self.imageView?.contentTintColor = .white
        self.titleView?.textColor = .white
    }
    
    public func reset() {
        self.layer?.backgroundColor = .clear
        self.imageView?.contentTintColor = .labelColor
        self.titleView?.textColor = .labelColor
        self.active = false
    }
}
