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

public protocol Popup_p: NSView {
    var sizeCallback: ((NSSize) -> Void)? { get set }
}

internal class PopupWindow: NSWindow, NSWindowDelegate {
    private let viewController: PopupViewController = PopupViewController()
    internal var locked: Bool = false
    
    init(title: String, view: Popup_p?, visibilityCallback: @escaping (_ state: Bool) -> Void) {
        self.viewController.setup(title: title, view: view)
        self.viewController.visibilityCallback = visibilityCallback
        
        super.init(
            contentRect: NSMakeRect(0, 0, self.viewController.view.frame.width, self.viewController.view.frame.height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.backgroundColor = .clear
        self.hasShadow = true
        self.setIsVisible(false)
        self.delegate = self
    }
    
    func windowWillMove(_ notification: Notification) {
        self.locked = true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if self.locked {
            return
        }
        
        self.setIsVisible(false)
    }
}

internal class PopupViewController: NSViewController {
    public var visibilityCallback: (_ state: Bool) -> Void = {_ in }
    private var popup: PopupView
    
    public init() {
        self.popup = PopupView(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width + (Constants.Popup.margins * 2),
            height: Constants.Popup.height+Constants.Popup.headerHeight
        ))
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
        super.viewWillAppear()
        
        self.popup.appear()
        self.visibilityCallback(true)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        self.popup.disappear()
        self.visibilityCallback(false)
    }
    
    public func setup(title: String, view: Popup_p?) {
        self.title = title
        self.popup.setTitle(title)
        self.popup.setView(view)
    }
}

internal class PopupView: NSView {
    private var title: String? = nil
    
    private let header: HeaderView
    private let body: NSScrollView
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.width, height: self.frame.height)
    }
    
    override init(frame: NSRect) {
        self.header = HeaderView(frame: NSRect(
            x: 0,
            y: frame.height - Constants.Popup.headerHeight,
            width: frame.width,
            height: Constants.Popup.headerHeight
        ))
        self.body = NSScrollView(frame: NSRect(
            x: Constants.Popup.margins,
            y: Constants.Popup.margins,
            width: frame.width - Constants.Popup.margins*2,
            height: frame.height - self.header.frame.height - Constants.Popup.margins*2
        ))
        
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        
        self.body.drawsBackground = false
        self.body.translatesAutoresizingMaskIntoConstraints = true
        self.body.borderType = .noBorder
        self.body.hasVerticalScroller = true
        self.body.hasHorizontalScroller = false
        self.body.autohidesScrollers = true
        self.body.horizontalScrollElasticity = .none
        
        self.addSubview(self.header)
        self.addSubview(self.body)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer!.backgroundColor = self.isDarkMode ? NSColor.windowBackgroundColor.cgColor : NSColor.white.cgColor
    }
    
    public func setView(_ view: Popup_p?) {
        let width: CGFloat = (view?.frame.width ?? Constants.Popup.width) + (Constants.Popup.margins*2)
        let height: CGFloat = (view?.frame.height ?? 0) + Constants.Popup.headerHeight + (Constants.Popup.margins*2)
        
        self.setFrameSize(NSSize(width: width, height: height))
        self.header.setFrameOrigin(NSPoint(x: 0, y: height - Constants.Popup.headerHeight))
        self.body.setFrameSize(NSSize(width: (view?.frame.width ?? Constants.Popup.width), height: (view?.frame.height ?? 0)))
        
        if let view = view {
            self.body.documentView = view
            
            view.sizeCallback = { [weak self] size in
                var isScrollVisible: Bool = false
                var windowSize: NSSize = NSSize(
                    width: size.width + (Constants.Popup.margins*2),
                    height: size.height + Constants.Popup.headerHeight + (Constants.Popup.margins*2)
                )
                
                if let screenHeight = NSScreen.main?.frame.height, windowSize.height > screenHeight {
                    windowSize.height = screenHeight - Constants.Widget.height - 6
                    isScrollVisible = true
                }
                if let screenWidth = NSScreen.main?.frame.width, windowSize.width > screenWidth {
                    windowSize.width = screenWidth
                }
                
                self?.window?.setContentSize(windowSize)
                self?.body.setFrameSize(NSSize(
                    width: windowSize.width - (Constants.Popup.margins*2) + (isScrollVisible ? 20 : 0),
                    height: windowSize.height - Constants.Popup.headerHeight - (Constants.Popup.margins*2)
                ))
                self?.header.setFrameOrigin(NSPoint(
                    x: self?.header.frame.origin.x ?? 0,
                    y: (self?.body.frame.height ?? 0) + (Constants.Popup.margins*2)
                ))
                
                if let documentView = self?.body.documentView {
                    documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
                }
            }
        }
    }
    
    public func setTitle(_ newTitle: String) {
        self.title = newTitle
        self.header.setTitle(newTitle)
    }
    
    internal func appear() {
        self.display()
        self.body.subviews.first?.display()
    }
    internal func disappear() {}
}

internal class HeaderView: NSView {
    private var titleView: NSTextField? = nil
    private var activityButton: NSButton?
    private var settingsButton: NSButton?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        
        let activity = NSButtonWithPadding()
        activity.frame = CGRect(x: 2, y: 2, width: 30, height: 30)
        activity.verticalPadding = 14
        activity.horizontalPadding = 14
        activity.bezelStyle = .regularSquare
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.imageScaling = .scaleNone
        activity.image = Bundle(for: type(of: self)).image(forResource: "chart")!
        activity.contentTintColor = .lightGray
        activity.isBordered = false
        activity.action = #selector(openActivityMonitor)
        activity.target = self
        activity.toolTip = LocalizedString("Open Activity Monitor")
        activity.focusRingType = .none
        
        let title = NSTextField(frame: NSMakeRect(frame.width/4, (frame.height - 18)/2, frame.width/2, 18))
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .textColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        title.stringValue = ""
        
        let settings = NSButtonWithPadding()
        settings.frame = CGRect(x: frame.width - 38, y: 2, width: 30, height: 30)
        settings.verticalPadding = 14
        settings.horizontalPadding = 14
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleNone
        settings.image = Bundle(for: type(of: self)).image(forResource: "settings")!
        settings.contentTintColor = .lightGray
        settings.isBordered = false
        settings.action = #selector(openMenu)
        settings.target = self
        settings.toolTip = LocalizedString("Open module settings")
        settings.focusRingType = .none
        
        self.addSubview(activity)
        self.addSubview(title)
        self.addSubview(settings)
        
        self.activityButton = activity
        self.titleView = title
        self.settingsButton = settings
        
        self.addTrackingArea(NSTrackingArea(
            rect: activity.frame,
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: ["button": "activity"]
        ))
        self.addTrackingArea(NSTrackingArea(
            rect: settings.frame,
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: ["button": "settings"]
        ))
    }
    
    public func setTitle(_ newTitle: String) {
        self.titleView?.stringValue = newTitle
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
        if let userData = with.trackingArea?.userInfo as? [String : AnyObject] {
            if let button = userData["button"] as? String {
                if button == "activity" {
                    self.activityButton!.contentTintColor = .gray
                } else if button == "settings" {
                    self.settingsButton!.contentTintColor = .gray
                }
            }
        }
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        if let userData = with.trackingArea?.userInfo as? [String : AnyObject] {
            if let button = userData["button"] as? String {
                if button == "activity" {
                    self.activityButton!.contentTintColor = .lightGray
                } else if button == "settings" {
                    self.settingsButton!.contentTintColor = .lightGray
                }
            }
        }
        NSCursor.arrow.set()
    }
    
    @objc func openMenu(_ sender: Any) {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.titleView?.stringValue ?? ""])
    }
    
    @objc func openActivityMonitor(_ sender: Any) {
        self.window?.setIsVisible(false)
        
        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.apple.ActivityMonitor",
            options: [.default],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
    }
}
