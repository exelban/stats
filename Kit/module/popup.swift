//
//  popup.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 11/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Popup_p: NSView {
    var keyboardShortcut: [UInt16] { get }
    var sizeCallback: ((NSSize) -> Void)? { get set }
    
    func settings() -> NSView?
    
    func appear()
    func disappear()
    func setKeyboardShortcut(_ binding: [UInt16])
}

open class PopupWrapper: NSStackView, Popup_p {
    public var title: String
    public var keyboardShortcut: [UInt16] = []
    open var sizeCallback: ((NSSize) -> Void)? = nil
    
    public init(_ typ: ModuleType, frame: NSRect) {
        self.title = typ.stringValue
        self.keyboardShortcut = Store.shared.array(key: "\(typ.stringValue)_popup_keyboardShortcut", defaultValue: []) as? [UInt16] ?? []
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func settings() -> NSView? { return nil }
    open func appear() {}
    open func disappear() {}
    
    open func setKeyboardShortcut(_ binding: [UInt16]) {
        self.keyboardShortcut = binding
        Store.shared.set(key: "\(self.title)_popup_keyboardShortcut", value: binding)
    }
}

public class PopupWindow: NSWindow, NSWindowDelegate {
    private let viewController: PopupViewController
    internal var locked: Bool = false
    internal var openedBy: widget_t? = nil
    public var isPinned: Bool = false
    internal var wasMoved: Bool = false
    internal var isDragging: Bool = false
    internal var explicitClose: Bool = false
    
    public override var isVisible: Bool {
        return super.isVisible
    }
    
    public init(title: String, module: ModuleType, view: Popup_p?, visibilityCallback: @escaping (_ state: Bool) -> Void) {
        self.viewController = PopupViewController(module: module)
        self.viewController.setup(title: title, view: view)
        
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        self.viewController.visibilityCallback = { [weak self] state in
            self?.locked = false
            visibilityCallback(state)
        }
        
        self.title = title
        self.titleVisibility = .hidden
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.backgroundColor = .clear
        self.hasShadow = true
        self.setIsVisible(false)
        self.delegate = self
    }
    
    public func windowWillMove(_ notification: Notification) {
        self.isDragging = true
        self.viewController.setCloseButton(true)
        self.locked = true
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        // Don't close if pinned or being moved
        if self.locked || self.isPinned {
            return
        }
        
        // Special case for application reactivation (clicking dock icon)
        let clickedInDock = NSEvent.pressedMouseButtons > 0 && 
                            NSApp.isActive && 
                            !NSApp.windows.contains(where: { $0.isKeyWindow && $0 != self })
        
        if clickedInDock {
            return
        }
        
        // Don't close if it was manually moved by the user and still visible
        if self.wasMoved && self.isVisible {
            return
        }
        
        self.viewController.setCloseButton(false)
        self.setIsVisible(false)
    }
    
    public func windowDidMove(_ notification: Notification) {
        // After the window is moved and the drag is complete
        self.locked = false
        self.wasMoved = true
        self.isDragging = false
        
        // Show the close button only if the window is being dragged
        if self.isDragging {
            self.viewController.setCloseButton(true)
        }
        
        // Keep the window on its current space only, don't make it join all spaces
        if !self.isPinned {
            self.collectionBehavior = .moveToActiveSpace
        }
    }
    
    public func pinToTop(_ pin: Bool) {
        self.isPinned = pin
        
        if pin {
            self.level = .floating
            self.collectionBehavior = .canJoinAllSpaces
            self.viewController.setCloseButton(true)
        } else {
            self.level = .normal
            self.collectionBehavior = .moveToActiveSpace
            
            // Keep the X icon if the window was moved, otherwise restore activity monitor icon
            if !self.wasMoved {
                self.viewController.setCloseButton(false)
            }
        }
    }
    
    // Reset the moved state when the window is closed
    public override func setIsVisible(_ isVisible: Bool) {
        // Always allow closing if explicitClose flag is set (from X button)
        if self.explicitClose && !isVisible {
            // Allow window to close even if pinned
            super.setIsVisible(false)
            return
        }
        
        // For pinned windows, never hide them except with explicit close
        if self.isPinned && !isVisible {
            // Don't hide pinned windows unless explicitly closed with the X button
            return
        }
        
        super.setIsVisible(isVisible)
        
        if !isVisible {
            // Reset the moved state when the window is closed
            self.wasMoved = false
            self.isDragging = false
            
            // Reset collection behavior when window is closed
            if !self.isPinned {
                self.collectionBehavior = .moveToActiveSpace
            }
            
            // Reset to activity monitor icon when window is closed
            self.viewController.setCloseButton(false)
        } else if isVisible {
            // When reopening, always show the activity monitor icon
            // regardless of whether it was moved previously
            self.viewController.setCloseButton(false)
        }
    }
    
    // Add mouse event tracking to detect dragging
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        self.isDragging = true
        self.viewController.setCloseButton(true)
    }
    
    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        self.isDragging = true
        self.viewController.setCloseButton(true)
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        self.isDragging = false
        
        // If the user dragged the window far enough to trigger a windowDidMove, that will
        // have set wasMoved = true. For short drags that don't trigger windowDidMove, we
        // should still show the activity monitor icon.
        if !self.wasMoved {
            self.viewController.setCloseButton(false)
        }
    }
}

internal class PopupViewController: NSViewController {
    fileprivate var visibilityCallback: (_ state: Bool) -> Void = {_ in }
    private var popup: PopupView
    
    public init(module: ModuleType) {
        self.popup = PopupView(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width + (Constants.Popup.margins * 2),
            height: Constants.Popup.height+Constants.Popup.headerHeight
        ), module: module)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self.popup
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
    
    fileprivate func setup(title: String, view: Popup_p?) {
        self.title = title
        self.popup.setTitle(title)
        self.popup.setView(view)
    }
    
    fileprivate func setCloseButton(_ state: Bool) {
        self.popup.setCloseButton(state)
    }
}

internal class PopupView: NSView {
    private var view: Popup_p? = nil
    
    private var foreground: NSVisualEffectView
    private var background: NSView
    
    private let header: HeaderView
    private let body: NSScrollView
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.width, height: self.frame.height)
    }
    private var windowHeight: CGFloat?
    private var containerHeight: CGFloat?
    
    init(frame: NSRect, module: ModuleType) {
        self.header = HeaderView(frame: NSRect(
            x: 0,
            y: frame.height - Constants.Popup.headerHeight,
            width: frame.width,
            height: Constants.Popup.headerHeight
        ), module: module)
        self.body = NSScrollView(frame: NSRect(
            x: Constants.Popup.margins,
            y: Constants.Popup.margins,
            width: frame.width - Constants.Popup.margins*2,
            height: frame.height - self.header.frame.height - Constants.Popup.margins*2
        ))
        self.windowHeight = NSScreen.main?.visibleFrame.height
        self.containerHeight = self.body.documentView?.frame.height
        
        self.foreground = NSVisualEffectView(frame: frame)
        self.foreground.material = .titlebar
        self.foreground.blendingMode = .behindWindow
        self.foreground.state = .active
        self.foreground.wantsLayer = true
        self.foreground.layer?.backgroundColor = NSColor.red.cgColor
        self.foreground.layer?.cornerRadius = 6
        
        self.background = NSView(frame: frame)
        self.background.wantsLayer = true
        self.foreground.addSubview(self.background)
        
        super.init(frame: frame)
        
        self.body.drawsBackground = false
        self.body.translatesAutoresizingMaskIntoConstraints = true
        self.body.borderType = .noBorder
        self.body.hasVerticalScroller = true
        self.body.hasHorizontalScroller = false
        self.body.autohidesScrollers = true
        self.body.horizontalScrollElasticity = .none
        
        self.addSubview(self.foreground, positioned: .below, relativeTo: .none)
        self.addSubview(self.header)
        self.addSubview(self.body)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.background.layer?.backgroundColor = self.isDarkMode ? .clear : NSColor.white.cgColor
    }
    
    fileprivate func setView(_ view: Popup_p?) {
        self.view = view
        
        var isScrollVisible: Bool = false
        var size: NSSize = NSSize(
            width: (view?.frame.width ?? Constants.Popup.width) + (Constants.Popup.margins*2),
            height: (view?.frame.height ?? 0) + Constants.Popup.headerHeight + (Constants.Popup.margins*2)
        )
        
        self.windowHeight = NSScreen.main?.visibleFrame.height
        self.containerHeight = self.body.documentView?.frame.height
        if let screenHeight = NSScreen.main?.visibleFrame.height, size.height > screenHeight {
            size.height = screenHeight - Constants.Widget.height
            isScrollVisible = true
        }
        if let screenWidth = NSScreen.main?.visibleFrame.width, size.width > screenWidth {
            size.width = screenWidth
        }
        
        self.setFrameSize(size)
        self.foreground.setFrameSize(size)
        self.background.setFrameSize(size)
        self.body.setFrameSize(NSSize(
            width: size.width - (Constants.Popup.margins*2) + (isScrollVisible ? 20 : 0),
            height: size.height - Constants.Popup.headerHeight - (Constants.Popup.margins*2)
        ))
        self.header.setFrameOrigin(NSPoint(x: 0, y: size.height - Constants.Popup.headerHeight))
        
        if let view = view {
            self.body.documentView = view
            view.sizeCallback = { [weak self] size in
                self?.recalculateHeight(size)
            }
        }
    }
    
    fileprivate func setTitle(_ newTitle: String) {
        self.header.setTitle(newTitle)
    }
    
    fileprivate func setCloseButton(_ state: Bool) {
        self.header.setCloseButton(state)
    }
    
    internal func appear() {
        self.display()
        self.body.subviews.first?.display()
        
        if let screenHeight = NSScreen.main?.visibleFrame.height, let size = self.body.documentView?.frame.size {
            if screenHeight != self.windowHeight {
                self.recalculateHeight(size)
            }
        }
        
        if let documentView = self.body.documentView {
            documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
        }
        
        // Ensure we start with the activity monitor button
        self.header.setCloseButton(false)
        
        self.view?.appear()
    }
    internal func disappear() {
        self.header.setCloseButton(false)
        self.view?.disappear()
    }
    
    private func recalculateHeight(_ size: NSSize) {
        var isScrollVisible: Bool = false
        var windowSize: NSSize = NSSize(
            width: size.width + (Constants.Popup.margins*2),
            height: size.height + Constants.Popup.headerHeight + (Constants.Popup.margins*2)
        )
        let h0 = self.containerHeight ?? 0
        
        self.windowHeight = NSScreen.main?.visibleFrame.height
        self.containerHeight = self.body.documentView?.frame.height
        if let screenHeight = NSScreen.main?.visibleFrame.height, windowSize.height > screenHeight {
            windowSize.height = screenHeight - Constants.Widget.height
            isScrollVisible = true
        }
        if let screenWidth = NSScreen.main?.visibleFrame.width, windowSize.width > screenWidth {
            windowSize.width = screenWidth
        }
        
        self.window?.setContentSize(windowSize)
        self.foreground.setFrameSize(windowSize)
        self.background.setFrameSize(windowSize)
        self.body.setFrameSize(NSSize(
            width: windowSize.width - (Constants.Popup.margins*2) + (isScrollVisible ? 20 : 0),
            height: windowSize.height - Constants.Popup.headerHeight - (Constants.Popup.margins*2)
        ))
        self.header.setFrameOrigin(NSPoint(
            x: self.header.frame.origin.x,
            y: self.body.frame.height + (Constants.Popup.margins*2)
        ))
        
        if let documentView = self.body.documentView {
            let diff = h0 - (self.body.documentView?.frame.height ?? 0)
            documentView.scroll(NSPoint(
                x: 0,
                y: self.body.documentVisibleRect.origin.y - (diff < 0 ? diff : 0)
            ))
        }
    }
}

internal class HeaderView: NSStackView {
    private var titleView: NSTextField? = nil
    private var activityButton: NSButton?
    private var pinButton: NSButton?
    private var leftContainer: NSView?
    private var rightContainer: NSStackView?
    
    private var title: String = ""
    private var isCloseAction: Bool = false
    private let activityMonitor: URL?
    private let calendar: URL?
    private var isPinned: Bool = false
    private var showPinButton: Bool = false
    
    init(frame: NSRect, module: ModuleType) {
        self.activityMonitor = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor")
        self.calendar = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        self.showPinButton = Store.shared.bool(key: "showPinButton", defaultValue: false)
        
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        
        // Use a custom layout to ensure perfect centering
        self.wantsLayer = true
        
        // Add increased margins on both sides
        let margin: CGFloat = 8
        
        // Left button (activity/calendar)
        let activity = NSButtonWithPadding()
        activity.frame = CGRect(x: margin, y: 0, width: 28, height: self.frame.height)
        activity.horizontalPadding = activity.frame.height - 22
        activity.bezelStyle = .regularSquare
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.imageScaling = .scaleNone
        activity.contentTintColor = .lightGray
        activity.isBordered = false
        activity.target = self
        if module == .clock {
            activity.action = #selector(self.openCalendar)
            activity.image = Bundle(for: type(of: self)).image(forResource: "calendar")!
            activity.toolTip = localizedString("Open Calendar")
        } else {
            activity.action = #selector(self.openActivityMonitor)
            activity.image = Bundle(for: type(of: self)).image(forResource: "chart")!
            activity.toolTip = localizedString("Open Activity Monitor")
        }
        activity.focusRingType = .none
        self.activityButton = activity
        
        // Left container
        let leftContainer = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: self.frame.height))
        leftContainer.addSubview(activity)
        self.leftContainer = leftContainer
        
        // Pin button
        let pin = NSButtonWithPadding()
        pin.frame = CGRect(x: 0, y: 0, width: 28, height: self.frame.height)
        pin.horizontalPadding = pin.frame.height - 22
        pin.bezelStyle = .regularSquare
        pin.translatesAutoresizingMaskIntoConstraints = false
        pin.imageScaling = .scaleNone
        pin.image = Bundle(for: type(of: self)).image(forResource: "pin")!
        pin.contentTintColor = .lightGray
        pin.isBordered = false
        pin.action = #selector(self.togglePin)
        pin.target = self
        pin.toolTip = localizedString("Pin popup on top")
        pin.focusRingType = .none
        pin.alphaValue = self.showPinButton ? 1.0 : 0.0
        pin.isEnabled = self.showPinButton
        self.pinButton = pin
        
        // Settings button
        let settings = NSButtonWithPadding()
        settings.frame = CGRect(x: 0, y: 0, width: 28, height: self.frame.height)
        settings.horizontalPadding = activity.frame.height - 22
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleNone
        settings.image = Bundle(for: type(of: self)).image(forResource: "settings")!
        settings.contentTintColor = .lightGray
        settings.isBordered = false
        settings.action = #selector(self.openSettings)
        settings.target = self
        settings.toolTip = localizedString("Open module settings")
        settings.focusRingType = .none
        
        // Right container
        let rightContainer = NSStackView(frame: NSRect(x: 0, y: 0, width: 64, height: self.frame.height))
        rightContainer.orientation = .horizontal
        rightContainer.distribution = .fillEqually
        rightContainer.spacing = 8
        rightContainer.addArrangedSubview(pin)
        rightContainer.addArrangedSubview(settings)
        self.rightContainer = rightContainer
        
        // Title
        let title = NSTextField(frame: NSRect(x: 0, y: 0, width: frame.width/2, height: 18))
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .textColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 16, weight: .medium) // Slightly bolder
        title.stringValue = ""
        title.lineBreakMode = .byTruncatingTail
        self.titleView = title
        
        // Add all views to the header
        self.addSubview(leftContainer)
        self.addSubview(title)
        self.addSubview(rightContainer)
        
        // Position the activity button
        NSLayoutConstraint.activate([
            activity.centerXAnchor.constraint(equalTo: leftContainer.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: leftContainer.centerYAnchor)
        ])
        
        // Set up constraints for perfect centering
        self.updateLayout()
        
        // Add observer for pin button toggle setting
        NotificationCenter.default.addObserver(self, selector: #selector(self.handlePinButtonToggle), name: .togglePinButton, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .togglePinButton, object: nil)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout()
    }
    
    private func updateLayout() {
        guard let leftContainer = self.leftContainer,
              let rightContainer = self.rightContainer,
              let titleView = self.titleView else {
            return
        }
        
        let margin: CGFloat = 8
        let leftWidth: CGFloat = 28
        let rightWidth: CGFloat = 64
        
        // Position left container
        leftContainer.frame = NSRect(
            x: margin,
            y: 0,
            width: leftWidth,
            height: self.frame.height
        )
        
        // Position right container
        rightContainer.frame = NSRect(
            x: self.frame.width - rightWidth - margin,
            y: 0,
            width: rightWidth,
            height: self.frame.height
        )
        
        // Calculate the title width and position to be perfectly centered in the entire header
        let titleWidth = min(200, self.frame.width * 0.6) // Limit width but allow it to be proportional
        
        titleView.frame = NSRect(
            x: (self.frame.width - titleWidth) / 2, // Center horizontally in the entire header
            y: (self.frame.height - 18) / 2, // Center vertically
            width: titleWidth,
            height: 18
        )
    }
    
    fileprivate func setTitle(_ newTitle: String) {
        self.title = newTitle
        self.titleView?.stringValue = localizedString(newTitle)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.gridColor.set()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 0))
        line.line(to: NSPoint(x: self.frame.width, y: 0))
        line.lineWidth = 1
        line.stroke()
    }
    
    @objc func openActivityMonitor() {
        guard let app = self.activityMonitor else { return }
        NSWorkspace.shared.open([], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
    
    @objc func openCalendar() {
        guard let app = self.calendar else { return }
        NSWorkspace.shared.open([], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
    
    @objc func openSettings() {
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.title])
    }
    
    @objc func togglePin() {
        self.isPinned = !self.isPinned
        if let window = self.window as? PopupWindow {
            window.pinToTop(self.isPinned)
        }
        
        self.pinButton?.contentTintColor = self.isPinned ? NSColor.systemBlue : NSColor.lightGray
        self.pinButton?.toolTip = self.isPinned ? localizedString("Unpin popup") : localizedString("Pin popup on top")
    }
    
    @objc private func closePopup() {
        // Force close even if pinned
        if let popupWindow = self.window as? PopupWindow {
            // Temporarily unpin if needed to allow closing
            let wasPinned = popupWindow.isPinned
            if wasPinned {
                popupWindow.pinToTop(false)
                // Reset the pin button appearance
                self.isPinned = false
                self.pinButton?.contentTintColor = NSColor.lightGray
                self.pinButton?.toolTip = localizedString("Pin popup on top")
            }
            
            // Set explicit close flag to ensure window closes
            popupWindow.explicitClose = true
            popupWindow.setIsVisible(false)
            popupWindow.explicitClose = false
        } else {
            self.window?.setIsVisible(false)
        }
        self.setCloseButton(false)
        return
    }
    
    fileprivate func setCloseButton(_ state: Bool) {
        if state && !self.isCloseAction {
            self.activityButton?.image = Bundle(for: type(of: self)).image(forResource: "close")!
            self.activityButton?.toolTip = localizedString("Close")
            self.activityButton?.action = #selector(self.closePopup)
            self.isCloseAction = true
        } else if !state && self.isCloseAction {
            self.activityButton?.image = Bundle(for: type(of: self)).image(forResource: "chart")!
            self.activityButton?.toolTip = localizedString("Open Activity Monitor")
            self.activityButton?.action = #selector(self.openActivityMonitor)
            self.isCloseAction = false
        }
    }
    
    @objc private func handlePinButtonToggle() {
        self.showPinButton = Store.shared.bool(key: "showPinButton", defaultValue: false)
        
        // Only change visibility, not actual layout
        self.pinButton?.alphaValue = self.showPinButton ? 1.0 : 0.0
        self.pinButton?.isEnabled = self.showPinButton
        
        // Unpin if necessary when pin button is disabled
        if !self.showPinButton && self.isPinned {
            self.isPinned = false
            if let window = self.window as? PopupWindow {
                window.pinToTop(false)
            }
            self.pinButton?.contentTintColor = NSColor.lightGray
        }
    }
}
