//
//  Setup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 21/07/2022.
//  Using Swift 5.0.
//  Running on macOS 12.4.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

private let setupSize: CGSize = CGSize(width: 600, height: 400)

internal class SetupWindow: NSWindow, NSWindowDelegate {
    private let view: SetupContainer = SetupContainer()
    private let vc: NSViewController = NSViewController(nibName: nil, bundle: nil)
    
    public var finishHandler: () -> Void = {}
    
    init() {
        self.vc.view = self.view
        
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.view.frame.width,
                y: NSScreen.main!.frame.height - self.view.frame.height,
                width: self.view.frame.width,
                height: self.view.frame.height
            ),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = self.vc
        self.animationBehavior = .default
        self.titlebarAppearsTransparent = true
        self.delegate = self
        self.title = localizedString("Stats Setup")
        
        self.positionCenter()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    public func show() {
        self.setIsVisible(true)
        self.orderFrontRegardless()
    }
    
    public func hide() {
        self.close()
    }
    
    func windowWillClose(_ notification: Notification) {
        self.finishHandler()
    }
    
    private func positionCenter() {
        self.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - self.view.frame.width)/2,
            y: (NSScreen.main!.frame.height - self.view.frame.height)/2
        ))
    }
}

private class SetupContainer: NSStackView {
    private let pages: [NSView] = [SetupView_1(), SetupView_2(), SetupView_3(), SetupView_4(), SetupView_end()]
    
    private var main: NSView = NSView()
    private var prevBtn: NSButton = NSButton()
    private var nextBtn: NSButton = NSButton()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height))
        self.orientation = .vertical
        self.spacing = 0
        
        self.addArrangedSubview(self.main)
        self.addArrangedSubview(self.footerView())
        
        self.setView(i: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.tertiaryLabelColor.set()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 59))
        line.line(to: NSPoint(x: self.frame.width, y: 59))
        line.lineWidth = 0.25
        line.stroke()
    }
    
    private func footerView() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        
        let prev = NSButton()
        prev.bezelStyle = .regularSquare
        prev.isEnabled = false
        prev.title = localizedString("Previous")
        prev.toolTip = localizedString("Previous page")
        prev.action = #selector(self.prev)
        prev.target = self
        self.prevBtn = prev
        
        let next = NSButton()
        next.bezelStyle = .regularSquare
        next.title = localizedString("Next")
        next.toolTip = localizedString("Next page")
        next.action = #selector(self.next)
        next.target = self
        self.nextBtn = next
        
        container.addArrangedSubview(prev)
        container.addArrangedSubview(next)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            prev.heightAnchor.constraint(equalToConstant: 28),
            next.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return container
    }
    
    @objc private func prev() {
        if let current = self.main.subviews.first, let idx = self.pages.firstIndex(where: { $0 == current }) {
            self.setView(i: idx-1)
        }
    }
    
    @objc private func next() {
        if let current = self.main.subviews.first, let idx = self.pages.firstIndex(where: { $0 == current }) {
            if idx+1 >= self.pages.count, let window = self.window as? SetupWindow {
                window.hide()
                return
            }
            self.setView(i: idx+1)
        }
    }
    
    private func setView(i: Int) {
        guard self.pages.indices.contains(i) else { return }
        
        if i == 0 {
            self.prevBtn.isEnabled = false
            self.nextBtn.isEnabled = true
        } else if i == self.pages.count-1 {
            self.nextBtn.title = localizedString("Finish")
            self.nextBtn.toolTip = localizedString("Finish setup")
        } else {
            self.prevBtn.isEnabled = true
            self.nextBtn.isEnabled = true
            self.nextBtn.title = localizedString("Next")
            self.nextBtn.toolTip = localizedString("Next page")
        }
        
        self.main.subviews.forEach({ $0.removeFromSuperview() })
        self.main.addSubview(self.pages[i])
    }
}

private class SetupView_1: NSStackView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let title: NSTextField = TextView()
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.stringValue = localizedString("Welcome to Stats")
        title.toolTip = localizedString("Welcome to Stats")
        title.isSelectable = false
        
        let icon: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        icon.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let message: NSTextField = TextView()
        message.alignment = .center
        message.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        message.stringValue = localizedString("welcome_message")
        message.toolTip = localizedString("welcome_message")
        message.isSelectable = false
        
        container.addRow(with: [title])
        container.addRow(with: [icon])
        container.addRow(with: [message])
        
        container.row(at: 0).height = 100
        container.row(at: 1).height = 120
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class SetupView_2: NSStackView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.stringValue = localizedString("Start at login")
        title.toolTip = localizedString("Start at login")
        title.isSelectable = false
        
        container.addRow(with: [title])
        container.addRow(with: [self.content()])
        
        container.row(at: 0).height = 100
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func content() -> NSView {
        let container: NSGridView = NSGridView()
        
        container.addRow(with: [self.option(
            tag: 1,
            state: LaunchAtLogin.isEnabled,
            text: localizedString("Start the application automatically when starting your Mac")
        )])
        container.addRow(with: [self.option(
            tag: 2,
            state: !LaunchAtLogin.isEnabled,
            text: localizedString("Do not start the application automatically when starting your Mac")
        )])
        
        return container
    }
    
    private func option(tag: Int, state: Bool, text: String) -> NSView {
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
        button.setButtonType(.radio)
        button.state = state ? .on : .off
        button.title = text
        button.action = #selector(self.toggle)
        button.isBordered = false
        button.isTransparent = false
        button.target = self
        button.tag = tag
        
        return button
    }
    
    @objc private func toggle(_ sender: NSButton) {
        LaunchAtLogin.isEnabled = sender.tag == 1
        if !Store.shared.exist(key: "runAtLoginInitialized") {
            Store.shared.set(key: "runAtLoginInitialized", value: true)
        }
    }
}

private class SetupView_3: NSStackView {
    private var value: AppUpdateInterval {
        get {
            let value = Store.shared.string(key: "update-interval", defaultValue: AppUpdateInterval.silent.rawValue)
            return AppUpdateInterval(rawValue: value) ?? AppUpdateInterval.silent
        }
    }
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.stringValue = localizedString("Check for updates")
        title.toolTip = localizedString("Check for updates")
        title.isSelectable = false
        
        container.addRow(with: [title])
        container.addRow(with: [self.content()])
        
        container.row(at: 0).height = 100
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func content() -> NSView {
        let container: NSGridView = NSGridView()
        
        container.addRow(with: [self.option(
            value: AppUpdateInterval.silent,
            text: localizedString("Do everything silently in the background (recommended)")
        )])
        container.addRow(with: [self.option(
            value: AppUpdateInterval.atStart,
            text: localizedString("Check for a new version on startup")
        )])
        container.addRow(with: [NSView()])
        container.addRow(with: [self.option(
            value: AppUpdateInterval.oncePerDay,
            text: localizedString("Check for a new version every day (once a day)")
        )])
        container.addRow(with: [self.option(
            value: AppUpdateInterval.oncePerWeek,
            text: localizedString("Check for a new version every week (once a week)")
        )])
        container.addRow(with: [self.option(
            value: AppUpdateInterval.oncePerMonth,
            text: localizedString("Check for a new version every month (once a month)")
        )])
        container.addRow(with: [NSView()])
        container.addRow(with: [self.option(
            value: AppUpdateInterval.never,
            text: localizedString("Never check for updates (not recommended)")
        )])
        
        container.row(at: 2).height = 1
        container.row(at: container.numberOfRows-2).height = 1
        
        return container
    }
    
    private func option(value: AppUpdateInterval, text: String) -> NSView {
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
        button.setButtonType(.radio)
        button.state = self.value == value ? .on : .off
        button.title = text
        button.action = #selector(self.toggle)
        button.isBordered = false
        button.isTransparent = false
        button.target = self
        button.identifier = NSUserInterfaceItemIdentifier(rawValue: value.rawValue)
        
        return button
    }
    
    @objc private func toggle(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue, !key.isEmpty else { return }
        Store.shared.set(key: "update-interval", value: key)
    }
}

private class SetupView_4: NSStackView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.stringValue = localizedString("Share anonymous telemetry for better development decisions")
        title.toolTip = localizedString("Share anonymous telemetry for better development decisions")
        title.isSelectable = false
        
        container.addRow(with: [title])
        container.addRow(with: [self.content()])
        
        container.row(at: 0).height = 100
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func content() -> NSView {
        let container: NSGridView = NSGridView()
        
        container.addRow(with: [self.option(
            tag: 1,
            state: telemetry.isEnabled,
            text: localizedString("Share anonymous telemetry data")
        )])
        container.addRow(with: [self.option(
            tag: 2,
            state: !telemetry.isEnabled,
            text: localizedString("Do not share anonymous telemetry data")
        )])
        
        return container
    }
    
    private func option(tag: Int, state: Bool, text: String) -> NSView {
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
        button.setButtonType(.radio)
        button.state = state ? .on : .off
        button.title = text
        button.action = #selector(self.toggle)
        button.isBordered = false
        button.isTransparent = false
        button.target = self
        button.tag = tag
        
        return button
    }
    
    @objc private func toggle(_ sender: NSButton) {
        telemetry.isEnabled = sender.tag == 1
    }
}

private class SetupView_end: NSStackView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.stringValue = localizedString("The configuration is completed")
        title.toolTip = localizedString("The configuration is completed")
        title.isSelectable = false
        
        let content = NSStackView()
        content.orientation = .vertical
        
        let message: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 16))
        message.alignment = .center
        message.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        message.stringValue = localizedString("finish_setup_message")
        message.toolTip = localizedString("finish_setup_message")
        message.isSelectable = false
        
        let support: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 160, height: 50))
        support.spacing = 0
        support.orientation = .horizontal
        
        support.addArrangedSubview(supportButton(name: "GitHub Sponsors", image: "github", action: #selector(self.openGithub)))
        support.addArrangedSubview(supportButton(name: "PayPal", image: "paypal", action: #selector(self.openPaypal)))
        support.addArrangedSubview(supportButton(name: "Ko-fi", image: "ko-fi", action: #selector(self.openKofi)))
        support.addArrangedSubview(supportButton(name: "Patreon", image: "patreon", action: #selector(self.openPatreon)))
        
        content.addArrangedSubview(message)
        content.addArrangedSubview(support)
        
        container.addRow(with: [title])
        container.addRow(with: [content])
        
        container.row(at: 0).height = 100
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
}
