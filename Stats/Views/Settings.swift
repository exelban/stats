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
    private let viewController: SettingsViewController = SettingsViewController()
    
    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.viewController.view.frame.width,
                y: NSScreen.main!.frame.height - self.viewController.view.frame.height,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.closable, .titled, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        if let close = self.standardWindowButton(.closeButton),
           let mini = self.standardWindowButton(.miniaturizeButton),
           let zoom = self.standardWindowButton(.zoomButton) {
            close.setFrameOrigin(NSPoint(x: 7, y: close.frame.origin.y))
            mini.setFrameOrigin(NSPoint(x: 27, y: close.frame.origin.y))
            zoom.setFrameOrigin(NSPoint(x: 47, y: close.frame.origin.y))
        }
        
        self.contentViewController = self.viewController
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.titlebarAppearsTransparent = true
        if #available(OSX 10.14, *) {
            self.appearance = NSAppearance(named: .darkAqua)
        }
        self.center()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(toggleSettingsHandler), name: .toggleSettings, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        if let name = notification.userInfo?["module"] as? String {
            self.viewController.openMenu(name)
        }
    }
    
    public func setModules() {
        self.viewController.setModules(modules)
        if modules.filter({ $0.enabled != false && $0.available != false && !$0.widgets.filter({ $0.isActive }).isEmpty }).isEmpty {
            self.setIsVisible(true)
        }
    }
    
    public func openMenu(_ title: String) {
        self.viewController.openMenu(title)
    }
    
    override func mouseUp(with: NSEvent) {
        NotificationCenter.default.post(name: .clickInSettings, object: nil, userInfo: nil)
    }
}

private class SettingsViewController: NSViewController {
    private var settings: SettingsView
    
    public init() {
        self.settings = SettingsView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self.settings
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public func setModules(_ list: [Module]) {
        self.settings.setModules(list)
    }
    
    public func openMenu(_ title: String) {
        self.settings.openMenu(title)
    }
}

private class SettingsView: NSView {
    private var modules: [Module] = []
    
    private let sidebarWidth: CGFloat = 180
    private let navigationHeight: CGFloat = 45
    
    private var menuView: NSScrollView = NSScrollView()
    private var navigationView: NSView = NSView()
    private var mainView: NSView = NSView()
    
    private var dashboard: NSView = Dashboard()
    private var settings: NSView = ApplicationSettings()
    
    private let supportPopover = NSPopover()
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(menuCallback), name: .openModuleSettings, object: nil)
        
        let sidebar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: self.sidebarWidth, height: self.frame.height))
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        
        self.supportPopover.behavior = .transient
        self.supportPopover.contentViewController = self.supportView()
        
        self.menuView.frame = NSRect(
            x: 0,
            y: self.navigationHeight,
            width: self.sidebarWidth,
            height: frame.height - self.navigationHeight - 26
        )
        self.menuView.wantsLayer = true
        self.menuView.drawsBackground = false
        self.menuView.addSubview(MenuView(n: 0, icon: NSImage(named: NSImage.Name("apps"))!, title: "Dashboard"))
        
        self.navigationView.frame = NSRect(x: 0, y: 0, width: self.sidebarWidth, height: navigationHeight)
        self.navigationView.wantsLayer = true
        
        self.navigationView.addSubview(self.makeButton(4, title: localizedString("Open application settings"), image: "settings", action: #selector(openSettings)))
        self.navigationView.addSubview(self.makeButton(3, title: localizedString("Report a bug"), image: "bug", action: #selector(reportBug)))
        self.navigationView.addSubview(self.makeButton(2, title: localizedString("Support the application"), image: "donate", action: #selector(donate)))
        self.navigationView.addSubview(self.makeButton(1, title: localizedString("Close application"), image: "power", action: #selector(closeApp)))
        
        self.mainView.frame = NSRect(
            x: self.sidebarWidth + 1, // separation line
            y: 1,
            width: frame.width - self.sidebarWidth - 1, // separation line
            height: frame.height - 2
        )
        self.mainView.wantsLayer = true
        
        self.addSubview(sidebar)
        self.addSubview(self.menuView)
        self.addSubview(self.navigationView)
        self.addSubview(self.mainView)
        
        self.openMenu("Dashboard")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let line = NSBezierPath()
        line.move(to: NSPoint(x: self.sidebarWidth, y: 0))
        line.line(to: NSPoint(x: self.sidebarWidth, y: self.frame.height))
        line.lineWidth = 1
        
        NSColor.black.set()
        line.stroke()
    }
    
    public func openMenu(_ title: String) {
        self.menuView.subviews.forEach({ (m: NSView) in
            if let menu = m as? MenuView {
                if menu.title == title {
                    menu.activate()
                }
            }
        })
    }
    
    public func setModules(_ list: [Module]) {
        list.forEach { (m: Module) in
            if !m.available { return }
            let n: Int = self.menuView.subviews.count - 1
            let menu: NSView = MenuView(n: n, icon: m.config.icon, title: m.config.name)
            self.menuView.addSubview(menu)
        }
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
            } else if title == "settings" {
                view = self.settings
            }
            
            self.mainView.subviews.forEach{ $0.removeFromSuperview() }
            self.mainView.addSubview(view)
            
            self.menuView.subviews.forEach({ (m: NSView) in
                if let menu = m as? MenuView {
                    if menu.active {
                        menu.reset()
                    }
                }
            })
        }
    }
    
    private func makeButton(_ n: Int, title: String, image: String, action: Selector) -> NSButton {
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: Int(self.sidebarWidth) - (45*n), y: 0, width: 44, height: 44)
        button.verticalPadding = 20
        button.horizontalPadding = 20
        button.title = title
        button.toolTip = title
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleNone
        button.image = Bundle(for: type(of: self)).image(forResource: image)!
        if #available(OSX 10.14, *) {
            button.contentTintColor = .lightGray
        }
        button.isBordered = false
        button.action = action
        button.target = self
        button.focusRingType = .none
        
        let rect = NSRect(x: Int(self.sidebarWidth) - (45*n), y: 0, width: 44, height: 44)
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
    
    @objc private func openSettings(_ sender: Any) {
        NotificationCenter.default.post(name: .openModuleSettings, object: nil, userInfo: ["module": "settings"])
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

private class MenuView: NSView {
    private let height: CGFloat = 40
    private let width: CGFloat = 180
    
    private var imageView: NSImageView? = nil
    private var titleView: NSTextField? = nil
    
    public let title: String
    public var active: Bool = false
    
    init(n: Int, icon: NSImage?, title: String) {
        self.title = title
        super.init(frame: NSRect(x: 0, y: self.height*CGFloat(n), width: width, height: self.height))
        self.wantsLayer = true
        self.layer?.backgroundColor = .clear
        
        var toolTip = ""
        if title == "State" {
            toolTip = localizedString("Open application settings")
        } else if title == "Dashboard" {
            toolTip = localizedString("Open dashboard")
        } else {
            toolTip = localizedString("Open \(title) settings")
        }
        self.toolTip = toolTip
        
        let rect = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let trackingArea = NSTrackingArea(
            rect: rect,
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: ["menu": title]
        )
        self.addTrackingArea(trackingArea)
        
        let imageView = NSImageView()
        if icon != nil {
            imageView.image = icon!
        }
        imageView.frame = NSRect(x: 8, y: (self.height - 18)/2, width: 18, height: 18)
        imageView.wantsLayer = true
        if #available(OSX 10.14, *) {
            imageView.contentTintColor = .labelColor
        }
        
        let titleView = TextView(frame: NSRect(x: 34, y: (self.height - 16)/2, width: 100, height: 16))
        titleView.alignment = .natural
        titleView.textColor = .labelColor
        titleView.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleView.stringValue = localizedString(title)
        
        self.addSubview(imageView)
        self.addSubview(titleView)
        
        self.imageView = imageView
        self.titleView = titleView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with: NSEvent) {
        self.activate()
    }
    
    public func activate() {
        NotificationCenter.default.post(name: .openModuleSettings, object: nil, userInfo: ["module": self.title])
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.25)
        self.active = true
    }
    
    public func reset() {
        self.layer?.backgroundColor = .clear
        self.active = false
    }
}
