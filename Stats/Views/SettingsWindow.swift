//
//  settings.swift
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
        let w = NSScreen.main!.frame.width
        let h = NSScreen.main!.frame.height
        super.init(
            contentRect: NSMakeRect(w - self.viewController.view.frame.width, h - self.viewController.view.frame.height, self.viewController.view.frame.width, self.viewController.view.frame.height),
            styleMask: [.closable, .titled, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = self.viewController
        self.animationBehavior = .default
        self.collectionBehavior = .transient
        self.titlebarAppearsTransparent = true
        self.appearance = NSAppearance(named: .darkAqua)
        self.center()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    public func setModules() {
        self.viewController.setModules(&modules)
        if modules.filter({ $0.enabled != false}).count == 0 {
            self.setIsVisible(true)
        }
    }
    
    public func openMenu(_ title: String) {
        self.viewController.openMenu(title)
    }
}

class SettingsViewController: NSViewController {
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
    
    public func setModules(_ list: UnsafeMutablePointer<[Module]>) {
        self.settings.setModules(list)
    }
    
    public func openMenu(_ title: String) {
        self.settings.openMenu(title)
    }
}

class SettingsView: NSView {
    private var modules: UnsafeMutablePointer<[Module]>?
    private let navigationWidth: CGFloat = 180
    private let buttonHeight: CGFloat = 45
    
    private var navigationView: NSScrollView? = nil
    private var buttonsView: NSView? = nil
    private var mainView: NSView? = nil
    
    private var applicationSettings: NSView = ApplicationSettings()
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(menuCallback), name: .openSettingsView, object: nil)
        
        let navigationView: NSScrollView = NSScrollView(frame: NSRect(x: 0, y: buttonHeight, width: navigationWidth, height: frame.height - buttonHeight))
        navigationView.wantsLayer = true
        navigationView.drawsBackground = false
        
        navigationView.addSubview(MenuView(n: 0, icon: NSImage(named: NSImage.Name("apps"))!, title: "Stats"))
        
        let buttonsView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: navigationWidth, height: buttonHeight))
        buttonsView.wantsLayer = true
        
        buttonsView.addSubview(self.makeButton(4, title: "Open Activity Monitor", image: "chart", action: #selector(openActivityMonitor)))
        buttonsView.addSubview(self.makeButton(3, title: "Report a bug", image: "bug", action: #selector(reportBug)))
        buttonsView.addSubview(self.makeButton(1, title: "Close application", image: "power", action: #selector(closeApp)))
        
        let mainView: NSView = NSView(frame: NSRect(x: navigationWidth, y: 1, width: frame.width - navigationWidth-1, height: frame.height-1))
        mainView.wantsLayer = true
        mainView.layer?.cornerRadius = 3
        mainView.layer?.maskedCorners = [.layerMaxXMinYCorner]
        
        self.addSubview(navigationView)
        self.addSubview(buttonsView)
        self.addSubview(mainView)
        
        self.navigationView = navigationView
        self.mainView = mainView
        self.buttonsView = buttonsView
        
        self.openMenu("Stats")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.gridColor.set()
        var line = NSBezierPath()
        line.move(to: NSMakePoint(0, self.buttonHeight))
        line.line(to: NSMakePoint(self.navigationWidth, self.buttonHeight))
        line.lineWidth = 1
        line.stroke()
        
        line = NSBezierPath()
        line.move(to: NSMakePoint(self.navigationWidth, 0))
        line.line(to: NSMakePoint(self.navigationWidth, self.frame.height))
        line.lineWidth = 1
        line.stroke()
    }
    
    public func openMenu(_ title: String) {
        self.navigationView?.subviews.forEach({ (m: NSView) in
            if let menu = m as? MenuView {
                if menu.title == title {
                    menu.activate()
                }
            }
        })
    }
    
    public func setModules(_ list: UnsafeMutablePointer<[Module]>) {
        list.pointee.forEach { (m: Module) in
            let n: Int = (self.navigationView?.subviews.count ?? 2)!-1
            let menu: NSView = MenuView(n: n, icon: m.config.icon, title: m.config.name)
            self.navigationView?.addSubview(menu)
        }
        self.modules = list
//        self.openMenu("CPU")
    }
    
    @objc private func menuCallback(_ notification: Notification) {
        if let title = notification.userInfo?["module"] as? String {
            var view: NSView = self.applicationSettings
            
            let detectedModule = self.modules?.pointee.first{ $0.config.name == title }
            if detectedModule != nil {
                if let v = detectedModule?.settings {
                    view = v
                }
            }
            
            self.mainView?.subviews.forEach{ $0.removeFromSuperview() }
            self.mainView?.addSubview(view)
            
            self.navigationView?.subviews.forEach({ (m: NSView) in
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
        button.frame = CGRect(x: Int(self.navigationWidth) - (45*n), y: 0, width: 44, height: 44)
        button.verticalPadding = 20
        button.horizontalPadding = 20
        button.title = title
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleNone
        button.image = Bundle(for: type(of: self)).image(forResource: image)!
        button.contentTintColor = .lightGray
        button.isBordered = false
        button.action = action
        button.target = self
        
        let rect = NSRect(x: Int(self.navigationWidth) - (45*n), y: 0, width: 44, height: 44)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["button": title])
        self.addTrackingArea(trackingArea)
        
        return button
    }
    
    override func mouseEntered(with: NSEvent) {
        if let userData = with.trackingArea?.userInfo as? [String : AnyObject] {
            if let title = userData["button"] as? String {
                let b = self.buttonsView?.subviews.first{ $0 is NSButton && ($0 as! NSButton).title == title }
                if b != nil && b is NSButton {
                    (b as! NSButton).contentTintColor = .labelColor
                    (b as! NSButton).layer?.backgroundColor = .init(gray: 0.1, alpha: 0.5)
                    NSCursor.pointingHand.set()
                }
            }
        }
    }
    
    override func mouseExited(with: NSEvent) {
        if let userData = with.trackingArea?.userInfo as? [String : AnyObject] {
            if let title = userData["button"] as? String {
                let b = self.buttonsView?.subviews.first{ $0 is NSButton && ($0 as! NSButton).title == title }
                if b != nil && b is NSButton {
                    (b as! NSButton).contentTintColor = .lightGray
                    (b as! NSButton).layer?.backgroundColor = .clear
                    NSCursor.arrow.set()
                }
            }
        }
    }
    
    @objc public func openActivityMonitor(_ sender: Any) {
        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.apple.ActivityMonitor",
            options: [.default],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
        self.window?.setIsVisible(false)
    }
    
    @objc public func reportBug(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats/issues/new")!)
    }
    
    @objc public func aboutApp(_ sender: Any) {
        print("about app")
    }
    
    @objc public func closeApp(_ sender: Any) {
        NSApp.terminate(sender)
    }
}

class MenuView: NSView {
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
        
        let rect = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["menu": title])
        self.addTrackingArea(trackingArea)
        
        let imageView = NSImageView()
        if icon != nil {
            imageView.image = icon!
        }
        imageView.frame = NSRect(x: 8, y: (self.height - 18)/2, width: 18, height: 18)
        imageView.wantsLayer = true
        imageView.contentTintColor = .secondaryLabelColor
        
        let titleView = TextView(frame: NSMakeRect(34, (self.height - 16)/2, 100, 17))
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        titleView.stringValue = title
        
        self.addSubview(imageView)
        self.addSubview(titleView)
        
        self.imageView = imageView
        self.titleView = titleView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with: NSEvent) {
        self.titleView?.textColor = .labelColor
        self.imageView?.contentTintColor = .labelColor
        self.layer?.backgroundColor = .init(gray: 0.1, alpha: 0.5)
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        if !self.active {
            self.reset()
        }
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        self.activate()
    }
    
    public func reset() {
        self.titleView?.textColor = .secondaryLabelColor
        self.imageView?.contentTintColor = .secondaryLabelColor
        self.layer?.backgroundColor = .clear
        self.active = false
    }
    
    public func activate() {
        NotificationCenter.default.post(name: .openSettingsView, object: nil, userInfo: ["module": self.title])
        
        self.titleView?.textColor = .labelColor
        self.imageView?.contentTintColor = .labelColor
        self.layer?.backgroundColor = .init(gray: 0.1, alpha: 0.5)
        self.active = true
    }
}
