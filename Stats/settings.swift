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
//        self.center()
        self.setIsVisible(true)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    public func setModules(_ list: [Module]) {
        self.viewController.setModules(list)
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
    
    public func setModules(_ list: [Module]) {
        self.settings.setModules(list)
    }
    
    public func openMenu(_ title: String) {
        self.settings.openMenu(title)
    }
}

class SettingsView: NSView {
    private var modules: [Module] = []
    private let navigationWidth: CGFloat = 180
    
    private var navigationView: NSScrollView? = nil
    private var mainView: NSView? = nil
    private var titleView: NSTextField? = nil
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        let navigationView: NSScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: navigationWidth, height: frame.height))
        navigationView.wantsLayer = true
        navigationView.drawsBackground = false
        
        navigationView.addSubview(MenuView(n: 0, icon: NSImage(named:NSImage.Name("settings"))!, title: "Settings", callback: self.menuCallback(_:)))
        
        let mainView: NSView = NSView(frame: NSRect(x: navigationWidth, y: 0, width: frame.width - navigationWidth, height: frame.height))
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = .white
        
        let titleView = NSTextField(frame: NSMakeRect((mainView.frame.width-100)/2, (mainView.frame.height - 20)/2, 100, 20))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .black
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .center
        titleView.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleView.stringValue = ""
        mainView.addSubview(titleView)
        
        self.addSubview(navigationView)
        self.addSubview(mainView)
        
        self.navigationView = navigationView
        self.mainView = mainView
        self.titleView = titleView
        
        self.openMenu("Settings")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    
    public func setModules(_ list: [Module]) {
        list.forEach { (m: Module) in
            let n: Int = (self.navigationView?.subviews.count ?? 2)!-1
            let menu: NSView = MenuView(n: n, icon: m.icon, title: m.name, callback: self.menuCallback(_:))
            self.navigationView?.addSubview(menu)
        }
        self.modules = list
    }
    
    private func menuCallback(_ title: String) {
        self.titleView?.stringValue = title
        
        self.navigationView?.subviews.forEach({ (m: NSView) in
            if let menu = m as? MenuView {
                if menu.active {
                    menu.reset()
                }
            }
        })
    }
}

class MenuView: NSView {
    private let height: CGFloat = 40
    private let width: CGFloat = 180
    
    private var imageView: NSImageView? = nil
    private var titleView: NSTextField? = nil
    
    private let callback: (String) -> ()
    public let title: String
    public var active: Bool = false
    
    init(n: Int, icon: NSImage, title: String, callback: @escaping (String)->()) {
        self.callback = callback
        self.title = title
        super.init(frame: NSRect(x: 0, y: self.height*CGFloat(n), width: width, height: self.height))
        self.wantsLayer = true
        self.layer?.backgroundColor = .clear
        
        let rect = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: ["menu": title])
        self.addTrackingArea(trackingArea)
        
        let imageView = NSImageView(image: icon)
        imageView.frame = NSRect(x: 8, y: ((self.height - 18)/2)+1, width: 18, height: 18)
        imageView.wantsLayer = true
        imageView.contentTintColor = .secondaryLabelColor
        
        let titleView = NSTextField(frame: NSMakeRect(34, (self.height - 20)/2, 100, 20))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .secondaryLabelColor
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
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
        self.callback(self.title)
        
        self.titleView?.textColor = .labelColor
        self.imageView?.contentTintColor = .labelColor
        self.layer?.backgroundColor = .init(gray: 0.1, alpha: 0.5)
        self.active = true
    }
}
