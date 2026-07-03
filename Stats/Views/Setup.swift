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

private let setupSize: CGSize = CGSize(width: 700, height: 440)

internal class SetupWindow: NSWindow, NSWindowDelegate {
    internal var finishHandler: () -> Void = {}
    internal var onClose: (() -> Void)?
    
    private let view: SetupContainer = SetupContainer()
    private let vc: NSViewController = NSViewController(nibName: nil, bundle: nil)
    
    init() {
        self.vc.view = self.view
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = self.vc
        self.animationBehavior = .default
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = false
        self.delegate = self
        self.title = localizedString("Stats Setup")
        
        self.positionCenter()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    internal func show() {
        self.setIsVisible(true)
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
    }
    
    internal func hide() {
        self.close()
    }
    
    func windowWillClose(_ notification: Notification) {
        self.finishHandler()
        let onClose = self.onClose
        DispatchQueue.main.async {
            onClose?()
        }
    }
    
    private func positionCenter() {
        guard let screen = NSScreen.main else {
            self.center()
            return
        }
        self.setFrameOrigin(NSPoint(
            x: (screen.frame.width - self.view.frame.width)/2,
            y: (screen.frame.height - self.view.frame.height)/1.75
        ))
    }
}

private class SetupContainer: NSStackView {
    private let pages: [NSView] = [SetupView_welcome(), SetupView_preset(), SetupView_startAtLogin(), SetupView_update(), SetupView_end()]
    
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

private class SetupView_welcome: NSStackView {
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

private class SetupView_preset: NSStackView {
    private let presets: [(name: String, items: [(module: ModuleType, widget: widget_t)])] = [
        (name: "Default", items: [
            (.CPU, .mini),
            (.RAM, .mini),
            (.disk, .mini),
            (.network, .speed),
            (.battery, .battery)
        ]),
        (name: "Basic", items: [
            (.CPU, .mini),
            (.RAM, .mini)
        ]),
        (name: "Recommended", items: [
            (.CPU, .mini),
            (.RAM, .barChart),
            (.disk, .barChart),
            (.network, .speed)
        ]),
        (name: "Extended", items: [
            (.CPU, .lineChart),
            (.GPU, .mini),
            (.RAM, .barChart),
            (.disk, .barChart),
            (.sensors, .label),
            (.network, .speed),
            (.battery, .battery)
        ])
    ]
    
    private let allModules: [ModuleType] = [.CPU, .GPU, .RAM, .disk, .sensors, .network, .battery, .bluetooth, .clock]
    private var radios: [NSButton] = []
    private var bars: [NSView] = []
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: setupSize.width, height: setupSize.height - 60))
        
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.stringValue = localizedString("Select preset")
        title.toolTip = localizedString("Select preset")
        title.isSelectable = false
        
        container.addRow(with: [title])
        container.addRow(with: [self.content()])
        
        container.row(at: 0).height = 70
        
        self.addArrangedSubview(container)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func content() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 10
        container.alignment = .leading
        
        let message: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: setupSize.width - 80, height: 16))
        message.alignment = .left
        message.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        message.textColor = .secondaryLabelColor
        message.stringValue = localizedString("select_preset_message")
        message.isSelectable = false
        container.addArrangedSubview(message)
        
        for (i, preset) in self.presets.enumerated() {
            container.addArrangedSubview(self.option(index: i, state: preset.name == "Default", preset: preset))
        }
        
        return container
    }
    
    private func option(index: Int, state: Bool, preset: (name: String, items: [(module: ModuleType, widget: widget_t)])) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        
        let button: NSButton = NSButton()
        button.setButtonType(.radio)
        button.state = state ? .on : .off
        button.title = localizedString(preset.name)
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.action = #selector(self.toggle)
        button.isBordered = false
        button.isTransparent = false
        button.target = self
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 120).isActive = true
        self.radios.append(button)
        
        let images = preset.items.compactMap { self.widgetImage(module: $0.module, type: $0.widget) }
        let bar = self.menuBarPreview(images)
        bar.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(self.boxClicked)))
        self.bars.append(bar)
        self.setSelected(bar, state)
        
        row.addArrangedSubview(button)
        row.addArrangedSubview(bar)
        row.addArrangedSubview(NSView())
        
        return row
    }
    
    private func setSelected(_ bar: NSView, _ selected: Bool) {
        bar.layer?.backgroundColor = (selected ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor(white: 0.5, alpha: 0.14)).cgColor
        bar.layer?.borderWidth = selected ? 1.5 : 0
        bar.layer?.borderColor = NSColor.controlAccentColor.cgColor
    }
    
    private func widgetImage(module: ModuleType, type: widget_t) -> NSImage? {
        guard let m = modules.first(where: { $0.config.name == module.stringValue }) else { return nil }
        return m.menuBar.widgets.first(where: { $0.type == type })?.image
    }
    
    private func menuBarPreview(_ images: [NSImage]) -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 6
        bar.layer?.cornerCurve = .continuous
        bar.layer?.masksToBounds = true
        bar.layer?.backgroundColor = NSColor(white: 0.5, alpha: 0.14).cgColor
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.setContentHuggingPriority(.required, for: .horizontal)
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = Constants.Widget.spacing * 2
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        images.forEach { (image: NSImage) in
            let imageView = NSImageView()
            imageView.image = image
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: image.size.width).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: image.size.height).isActive = true
            stack.addArrangedSubview(imageView)
        }
        
        bar.addSubview(stack)
        
        NSLayoutConstraint.activate([
            bar.heightAnchor.constraint(equalToConstant: Constants.Widget.height + 10),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
        
        return bar
    }
    
    @objc private func toggle(_ sender: NSButton) {
        self.select(sender.tag)
    }
    
    @objc private func boxClicked(_ gesture: NSClickGestureRecognizer) {
        guard let bar = gesture.view, let index = self.bars.firstIndex(where: { $0 === bar }) else { return }
        self.select(index)
    }
    
    private func select(_ index: Int) {
        guard self.presets.indices.contains(index) else { return }
        
        self.radios.enumerated().forEach { $1.state = $0 == index ? .on : .off }
        self.bars.enumerated().forEach { self.setSelected($1, $0 == index) }
        
        var widgets: [ModuleType: widget_t] = [:]
        self.presets[index].items.forEach { widgets[$0.module] = $0.widget }
        
        for module in self.allModules {
            let name = module.stringValue
            if let widget = widgets[module] {
                Store.shared.set(key: "\(name)_state", value: true)
                Store.shared.set(key: "\(name)_widget", value: widget.rawValue)
            } else {
                Store.shared.set(key: "\(name)_state", value: false)
            }
        }
        
        let mounted = (NSApp.delegate as? AppDelegate)?.modulesMounted ?? false
        let names = self.allModules.map { $0.stringValue }
        
        modules.forEach { module in
            let name = module.config.name
            guard let index = names.firstIndex(of: name) else { return }
            let widget = widgets[self.allModules[index]]
            
            if !mounted {
                module.enabled = widget != nil && module.available
                return
            }
            
            if let widget = widget {
                module.menuBar.widgets.forEach { $0.toggle($0.type == widget) }
                NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": name, "state": true])
            } else {
                NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": name, "state": false])
            }
        }
    }
}

private class SetupView_startAtLogin: NSStackView {
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

private class SetupView_update: NSStackView {
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
        support.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        support.spacing = 12
        support.orientation = .horizontal
        
        let github = SupportButtonView(name: "GitHub Sponsors", image: "github", action: {
            NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/exelban")!)
        })
        let paypal = SupportButtonView(name: "PayPal", image: "paypal", action: {
            NSWorkspace.shared.open(URL(string: "https://www.paypal.com/donate?hosted_button_id=3DS5JHDBATMTC")!)
        })
        let koFi = SupportButtonView(name: "Ko-fi", image: "ko-fi", action: {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/exelban")!)
        })
        let patreon = SupportButtonView(name: "Patreon", image: "patreon", action: {
            NSWorkspace.shared.open(URL(string: "https://patreon.com/exelban")!)
        })
        
        support.addArrangedSubview(github)
        support.addArrangedSubview(paypal)
        support.addArrangedSubview(koFi)
        support.addArrangedSubview(patreon)
        
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
}

internal class SupportButtonView: NSButton {
    internal var callback: (() -> Void) = {}
    
    init(name: String, image: String, action: @escaping () -> Void) {
        self.callback = action
        
        super.init(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        
        self.title = name
        self.toolTip = name
        self.bezelStyle = .regularSquare
        self.translatesAutoresizingMaskIntoConstraints = false
        self.imageScaling = .scaleProportionallyDown
        self.image = Bundle(for: type(of: self)).image(forResource: image)!
        self.isBordered = false
        self.target = self
        self.focusRingType = .none
        self.action = #selector(self.click)
        self.wantsLayer = true
        self.alphaValue = 0.9
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: self.bounds.width),
            self.heightAnchor.constraint(equalToConstant: self.bounds.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func mouseEntered(with: NSEvent) {
        self.alphaValue = 1
        NSCursor.pointingHand.set()
    }
    
    public override func mouseExited(with: NSEvent) {
        self.alphaValue = 0.9
        NSCursor.arrow.set()
    }
    
    @objc private func click() {
        self.callback()
    }
}
