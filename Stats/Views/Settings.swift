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

class SettingsWindow: NSWindow, NSWindowDelegate {
    static let size: CGSize = CGSize(width: 720, height: 480)
    private let vc: SettingsView = SettingsView()
    
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
        
        self.contentViewController = self.vc
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.center()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
        
        let newToolbar = NSToolbar(identifier: "eu.exelban.Stats.Settings.Toolbar")
        newToolbar.allowsUserCustomization = false
        newToolbar.autosavesConfiguration = true
        newToolbar.displayMode = .default
        newToolbar.showsBaselineSeparator = true
        
        self.toolbar = newToolbar
        
        NotificationCenter.default.addObserver(self, selector: #selector(toggleSettingsHandler), name: .toggleSettings, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleSettings, object: nil)
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
    
    @objc private func toggleSettingsHandler(_ notification: Notification) {
        if !self.isVisible {
            self.setIsVisible(true)
            self.makeKeyAndOrderFront(nil)
        }
        if !self.isKeyWindow {
            self.orderFrontRegardless()
        }
        
        if let name = notification.userInfo?["module"] as? String {
            self.vc.openMenu(name)
        }
    }
    
    public func setModules() {
        self.vc.setModules(modules)
        if !self.pauseState && modules.filter({ $0.enabled != false && $0.available != false && !$0.menuBar.widgets.filter({ $0.isActive }).isEmpty }).isEmpty {
            self.setIsVisible(true)
        }
    }
    
    public func openMenu(_ title: String) {
        self.vc.openMenu(title)
    }
    
    override func mouseUp(with: NSEvent) {
        NotificationCenter.default.post(name: .clickInSettings, object: nil, userInfo: nil)
    }
}

private class SettingsView: NSSplitViewController {
    private var modules: [Module] = []
    
    private let split: NSSplitView = SplitView()
    
    private let sidebar: SidebarView = SidebarView(frame: NSRect(x: 0, y: 0, width: 180, height: 480))
    private let main: MainView = MainView(frame: NSRect(x: 0, y: 0, width: 540, height: 480))
    
    private var dashboard: NSView = Dashboard()
    private var settings: ApplicationSettings = ApplicationSettings()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.splitView = self.split
        
        let sidebarVC: NSViewController = NSViewController(nibName: nil, bundle: nil)
        sidebarVC.view = self.sidebar
        let mainVC: NSViewController = NSViewController(nibName: nil, bundle: nil)
        mainVC.view = self.main
        
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        let contentItem = NSSplitViewItem(viewController: mainVC)
        
        self.addSplitViewItem(sidebarItem)
        self.addSplitViewItem(contentItem)
        
        self.splitViewItems[0].canCollapse = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(menuCallback), name: .openModuleSettings, object: nil)
        
        self.openMenu("Dashboard")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func openMenu(_ title: String) {
        self.sidebar.openMenu(title)
    }
    
    public func setModules(_ list: [Module]) {
        self.sidebar.setModules(list)
        self.modules = list
    }
    
    @objc private func menuCallback(_ notification: Notification) {
        if let title = notification.userInfo?["module"] as? String {
            var view: NSView = NSView()
            if let detectedModule = self.modules.first(where: { $0.config.name == title }) {
                if let v = detectedModule.settings {
                    view = v
                }
            } else if title == "Dashboard" {
                view = self.dashboard
            } else if title == "Settings" {
                self.settings.viewWillAppear()
                view = self.settings
            }
            
            self.main.setView(view)
            self.sidebar.openMenu(title)
        }
    }
}

private class SplitView: NSSplitView, NSSplitViewDelegate {
    init() {
        super.init(frame: NSRect.zero)
        
        self.isVertical = true
        self.delegate = self
        
        self.widthAnchor.constraint(equalToConstant: SettingsWindow.size.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: SettingsWindow.size.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}

private class SidebarView: NSStackView {
    private let scrollView: ScrollableStackView
    
    private let supportPopover = NSPopover()
    
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
        
        self.scrollView.stackView.addArrangedSubview(MenuItem(icon: NSImage(named: NSImage.Name("apps"))!, title: "Dashboard"))
        self.scrollView.stackView.addArrangedSubview(spacer)
        self.scrollView.stackView.addArrangedSubview(MenuItem(icon: NSImage(named: NSImage.Name("settings"))!, title: "Settings"))
        
        self.supportPopover.behavior = .transient
        self.supportPopover.contentViewController = self.supportView()
        
        let additionalButtons: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: frame.width, height: 40))
        additionalButtons.orientation = .horizontal
        additionalButtons.distribution = .fillEqually
        additionalButtons.spacing = 0
        
        additionalButtons.addArrangedSubview(self.makeButton(title: localizedString("Report a bug"), image: "bug", action: #selector(reportBug)))
        additionalButtons.addArrangedSubview(self.makeButton(title: localizedString("Support the application"), image: "donate", action: #selector(donate)))
        additionalButtons.addArrangedSubview(self.makeButton(title: localizedString("Close application"), image: "power", action: #selector(closeApp)))
        
        self.addArrangedSubview(self.scrollView)
        self.addArrangedSubview(additionalButtons)
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
    
    private func makeButton(title: String, image: String, action: Selector) -> NSButton {
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.verticalPadding = 20
        button.horizontalPadding = 20
        button.title = title
        button.toolTip = title
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleNone
        button.image = Bundle(for: type(of: self)).image(forResource: image)!
        if #available(OSX 10.14, *) {
            button.contentTintColor = .secondaryLabelColor
        }
        button.isBordered = false
        button.action = action
        button.target = self
        button.focusRingType = .none
        
        let rect = NSRect(x: 0, y: 0, width: 44, height: 44)
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
        view.spacing = 0
        view.orientation = .horizontal
        
        view.addArrangedSubview(supportButton(name: "GitHub Sponsors", image: "github", action: #selector(self.openGithub)))
        view.addArrangedSubview(supportButton(name: "PayPal", image: "paypal", action: #selector(self.openPaypal)))
        view.addArrangedSubview(supportButton(name: "Ko-fi", image: "ko-fi", action: #selector(self.openKofi)))
        view.addArrangedSubview(supportButton(name: "Patreon", image: "patreon", action: #selector(self.openPatreon)))
        
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
    
    @objc private func openGithub(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/exelban")!)
    }
    
    @objc private func openPaypal(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://www.paypal.com/donate?hosted_button_id=3DS5JHDBATMTC")!)
    }
    
    @objc private func openKofi(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/exelban")!)
    }
    
    @objc private func openPatreon(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://patreon.com/exelban")!)
    }
    
    @objc private func closeApp(_ sender: Any) {
        NSApp.terminate(sender)
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
        if #available(OSX 10.14, *) {
            imageView.contentTintColor = .labelColor
        }
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
        
        if #available(macOS 10.14, *) {
            self.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        } else {
            self.layer?.backgroundColor = NSColor.systemBlue.cgColor
        }
        
        if #available(macOS 10.14, *) {
            self.imageView?.contentTintColor = .white
        }
        self.titleView?.textColor = .white
    }
    
    public func reset() {
        self.layer?.backgroundColor = .clear
        if #available(macOS 10.14, *) {
            self.imageView?.contentTintColor = .labelColor
        }
        self.titleView?.textColor = .labelColor
        self.active = false
    }
}

private class MainView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        
        self.wantsLayer = true
        
        let foreground = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        foreground.blendingMode = .withinWindow
        if #available(macOS 10.14, *) {
            foreground.material = .windowBackground
        } else {
            foreground.material = .popover
        }
        foreground.state = .active
        
        self.addSubview(foreground, positioned: .below, relativeTo: .none)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setView(_ view: NSView) {
        self.subviews.filter{ !($0 is NSVisualEffectView) }.forEach{ $0.removeFromSuperview() }
        self.addSubview(view)
    }
}
