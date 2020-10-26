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

internal class PopupWindow: NSPanel {
    private let viewController: PopupViewController = PopupViewController()
    
    init(title: String, view: NSView?, visibilityCallback: @escaping (_ state: Bool) -> Void) {
        self.viewController.setup(title: title, view: view)
        self.viewController.visibilityCallback = visibilityCallback
        
        super.init(
            contentRect: NSMakeRect(0, 0, self.viewController.view.frame.width, self.viewController.view.frame.height),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = self.viewController
        self.backingType = .buffered
        self.isFloatingPanel = true
        self.worksWhenModal = true
        self.becomesKeyOnlyIfNeeded = true
        self.styleMask = .borderless
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.backgroundColor = .clear
        self.hasShadow = true
        self.setIsVisible(false)
    }
}

internal class PopupViewController: NSViewController {
    public var visibilityCallback: (_ state: Bool) -> Void = {_ in }
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
        super.viewWillAppear()
        
        self.popup.appear()
        self.visibilityCallback(true)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        self.popup.disappear()
        self.visibilityCallback(false)
    }
    
    public func setup(title: String, view: NSView?) {
        self.title = title
        self.popup.title = title
        self.popup.headerView?.titleView?.stringValue = title
        self.popup.setView(view)
    }
}

internal class PopupView: NSView {
    public var headerView: HeaderView? = nil
    public var title: String? = nil
    private var mainView: NSView? = nil
    
    override var intrinsicContentSize: CGSize {
        var h: CGFloat = self.mainView?.subviews.first?.frame.height ?? 0
        if h != 0 {
            h += Constants.Popup.margins*2
        }
        return CGSize(width: self.frame.size.width, height: h + Constants.Popup.headerHeight)
    }
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        self.canDrawConcurrently = true
        self.layer!.cornerRadius = 3
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenChangingPopupSize), name: .updatePopupSize, object: nil)
        self.headerView = HeaderView(frame: NSRect(x: 0, y: frame.height - Constants.Popup.headerHeight, width: frame.width, height: Constants.Popup.headerHeight))
        
        let mainView: NSView = NSView(frame: NSRect(x: Constants.Popup.margins, y: Constants.Popup.margins, width: frame.width - (Constants.Popup.margins*2), height: 0))
        
        self.addSubview(self.headerView!)
        self.addSubview(mainView)
        
        self.mainView = mainView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        if self.mainView!.subviews.count != 0 {
            if self.mainView?.frame.height != self.mainView!.subviews.first!.frame.size.height {
                self.setHeight(self.mainView!.subviews.first!.frame.size)
            }
        }
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
        DispatchQueue.main.async(execute: {
            self.mainView?.setFrameSize(NSSize(width: self.mainView!.frame.width, height: size.height))
            self.setFrameSize(NSSize(width: size.width + (Constants.Popup.margins*2), height: size.height + Constants.Popup.headerHeight + Constants.Popup.margins*2))
            self.headerView?.setFrameOrigin(NSPoint(x: 0, y: self.frame.height - Constants.Popup.headerHeight))
            
            var frame = self.window?.frame
            frame?.size = self.frame.size
            self.window?.setFrame(frame!, display: true)
        })
    }
    
    internal func appear() {
        self.display()
        self.mainView?.subviews.first{ !($0 is HeaderView) }?.display()
    }
    internal func disappear() {}
    
    @objc private func listenChangingPopupSize(_ notification: Notification) {
        if let moduleName = notification.userInfo?["module"] as? String, moduleName == self.title {
            self.updateLayer()
        }
    }
}

internal class HeaderView: NSView {
    public var titleView: NSTextField? = nil
    
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

public class ProcessView: NSView {
    public var width: CGFloat {
        get { return 0 }
        set {
            self.setFrameSize(NSSize(width: newValue, height: self.frame.height))
        }
    }
    
    public var icon: NSImage? {
        get { return NSImage() }
        set {
            self.imageView?.image = newValue
        }
    }
    public var label: String {
        get { return "" }
        set {
            self.labelView?.stringValue = newValue
        }
    }
    public var value: String {
        get { return "" }
        set {
            self.valueView?.stringValue = newValue
        }
    }
    
    private var imageView: NSImageView? = nil
    private var labelView: LabelField? = nil
    private var valueView: ValueField? = nil
    
    public init(_ n: CGFloat) {
        super.init(frame: NSRect(x: 0, y: n*22, width: Constants.Popup.width, height: 16))
        
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 16))
        
        let imageView: NSImageView = NSImageView(frame: NSRect(x: 2, y: 2, width: 12, height: 12))
        let labelView: LabelField = LabelField(frame: NSRect(x: 18, y: 0.5, width: rowView.frame.width - 70 - 18, height: 15), "")
        let valueView: ValueField = ValueField(frame: NSRect(x: 18 + labelView.frame.width, y: 0, width: 70, height: 16), "")
        
        rowView.addSubview(imageView)
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        
        self.imageView = imageView
        self.labelView = labelView
        self.valueView = valueView
        
        self.addSubview(rowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
