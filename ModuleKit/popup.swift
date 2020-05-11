//
//  popup.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 11/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

class PopupWindow: NSPanel, NSWindowDelegate {
    let viewController: PopupViewController = PopupViewController()
    
    init(title: String, view: NSView?) {
        self.viewController.setup(title: title, view: view)
        
        super.init(
            contentRect: NSMakeRect(0, 0, self.viewController.view.frame.width, self.viewController.view.frame.height),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = viewController
        self.backingType = .buffered
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.styleMask = .borderless
        self.animationBehavior = .default
        self.collectionBehavior = .transient
        self.backgroundColor = .clear
        self.hasShadow = true
        self.setIsVisible(false)
    }
}

class PopupViewController: NSViewController {
    private var popup: PopupView
    
    public init() {
        self.popup = PopupView(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width + (Constants.Popup.margins * 2), height: Constants.Popup.height+Constants.Popup.headerHeight))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self.popup
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        self.popup.appear()
    }
    
    override func viewWillDisappear() {
        self.popup.disappear()
    }
    
    public func setup(title: String, view: NSView?) {
        self.title = title
        self.popup.headerView?.titleView?.stringValue = title
        self.popup.setView(view)
    }
}

class PopupView: NSView {
    public var headerView: HeaderView? = nil
    private var mainView: NSView? = nil
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        self.canDrawConcurrently = true
        self.layer!.cornerRadius = 3
        
        self.headerView = HeaderView(frame: NSRect(x: 0, y: frame.height - Constants.Popup.headerHeight, width: frame.width, height: Constants.Popup.headerHeight))
        
        let mainView: NSView = NSView(frame: NSRect(x: Constants.Popup.margins, y: Constants.Popup.margins, width: frame.width - (Constants.Popup.margins*2), height: Constants.Popup.height - (Constants.Popup.margins*2)))
        
        self.addSubview(self.headerView!)
        self.addSubview(mainView)
        
        self.mainView = mainView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer!.backgroundColor = self.isDarkMode ? NSColor.windowBackgroundColor.cgColor : NSColor.white.cgColor
    }
    
    public func setView(_ view: NSView?) {
        if view == nil {
            self.setFrameSize(NSSize(width: Constants.Popup.width+(Constants.Popup.margins*2), height: Constants.Popup.headerHeight))
            self.headerView?.setFrameOrigin(NSPoint(x: 0, y: 0))
            return
        }
        
        self.mainView?.addSubview(view!)
        self.setHeight(view!.frame.size)
    }
    
    private func setHeight(_ size: CGSize) {
        self.mainView?.setFrameSize(NSSize(width: self.mainView!.frame.width, height: size.height))
        self.setFrameSize(NSSize(width: size.width + (Constants.Popup.margins*2), height: size.height + Constants.Popup.headerHeight + Constants.Popup.margins*2))
        self.headerView?.setFrameOrigin(NSPoint(x: 0, y: self.frame.height - Constants.Popup.headerHeight))
    }
    
    open func appear() {
        self.display()
    }
    open func disappear() {}
}

class HeaderView: NSView {
    public var titleView: NSTextField? = nil
    
    private var settingsButton: NSButton?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        
        let titleView = NSTextField(frame: NSMakeRect(frame.width/4, (frame.height - 18)/2, frame.width/2, 18))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .labelColor
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .center
        titleView.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleView.stringValue = ""
        
        self.titleView = titleView
        self.addSubview(titleView)
        
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: frame.width - 38, y: 5, width: 30, height: 30)
        button.verticalPadding = 14
        button.horizontalPadding = 14
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageScaling = .scaleNone
        button.image = Bundle(for: type(of: self)).image(forResource: "settings")!
        button.contentTintColor = .lightGray
        button.isBordered = false
        button.action = #selector(openMenu)
        button.target = self
        
        let trackingArea = NSTrackingArea(rect: button.frame, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
        
        self.addSubview(button)
        
        self.settingsButton = button
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.gridColor.set()
        let line = NSBezierPath()
        line.move(to: NSMakePoint(0, 0))
        line.line(to: NSMakePoint(self.frame.width, 0))
        line.lineWidth = 1
        line.stroke()
    }
    
    override func mouseEntered(with: NSEvent) {
        self.settingsButton!.contentTintColor = .gray
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        self.settingsButton!.contentTintColor = .lightGray
        NSCursor.arrow.set()
    }
    
    @objc func openMenu(_ sender: Any) {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.titleView?.stringValue ?? ""])
    }
}
