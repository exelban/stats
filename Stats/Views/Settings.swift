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
import ModuleKit
import StatsKit

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
        
        self.contentViewController = self.viewController
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.titlebarAppearsTransparent = true
        self.appearance = NSAppearance(named: .darkAqua)
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
        if modules.filter({ $0.enabled != false && $0.available != false }).isEmpty {
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
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(menuCallback), name: .openModuleSettings, object: nil)
        
        let sidebar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: self.sidebarWidth, height: self.frame.height))
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        
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
        button.contentTintColor = .lightGray
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
    
    @objc private func openSettings(_ sender: Any) {
        NotificationCenter.default.post(name: .openModuleSettings, object: nil, userInfo: ["module": "settings"])
    }
    
    @objc private func reportBug(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats/issues/new")!)
    }
    
    @objc private func donate(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats")!)
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
        self.toolTip = title == "Stats" ? localizedString("Open application settings") : localizedString("Open moduleName settings", title)
        
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
        imageView.contentTintColor = .labelColor
        
        let titleView = TextView(frame: NSRect(x: 34, y: (self.height - 16)/2, width: 100, height: 16))
        titleView.alignment = .natural
        titleView.textColor = .labelColor
        titleView.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleView.stringValue = title
        
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
        self.layer?.backgroundColor = .init(gray: 0.1, alpha: 0.4)
        self.active = true
    }
    
    public func reset() {
        self.layer?.backgroundColor = .clear
        self.active = false
    }
}
