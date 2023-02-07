//
//  AppSettings.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class ApplicationSettings: NSStackView {
    private var updateIntervalValue: String {
        Store.shared.string(key: "update-interval", defaultValue: AppUpdateInterval.silent.rawValue)
    }
    
    private var temperatureUnitsValue: String {
        get {
            Store.shared.string(key: "temperature_units", defaultValue: "system")
        }
        set {
            Store.shared.set(key: "temperature_units", value: newValue)
        }
    }
    
    private var combinedModulesState: Bool {
        get {
            Store.shared.bool(key: "CombinedModules", defaultValue: false)
        }
        set {
            Store.shared.set(key: "CombinedModules", value: newValue)
        }
    }
    private var combinedModulesSpacing: String {
        get {
            Store.shared.string(key: "CombinedModules_spacing", defaultValue: "none")
        }
        set {
            Store.shared.set(key: "CombinedModules_spacing", value: newValue)
        }
    }
    
    private let updateWindow: UpdateWindow = UpdateWindow()
    private let moduleSelector: ModuleSelectorView = ModuleSelectorView()
    private var updateSelector: NSPopUpButton?
    private var startAtLoginBtn: NSButton?
    private var uninstallHelperButton: NSButton?
    private var buttonsContainer: NSStackView?
    
    private var combinedModules: NSView?
    private var combinedModulesSeparator: NSView?
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = ScrollableStackView()
        scrollView.stackView.spacing = 0
        
        scrollView.stackView.addArrangedSubview(self.informationView())
        scrollView.stackView.addArrangedSubview(self.separatorView())
        scrollView.stackView.addArrangedSubview(self.settingsView())
        scrollView.stackView.addArrangedSubview(self.separatorView())
        scrollView.stackView.addArrangedSubview(self.combinedModulesView())
        let separator = self.separatorView()
        self.combinedModulesSeparator = separator
        scrollView.stackView.addArrangedSubview(separator)
        scrollView.stackView.addArrangedSubview(self.buttonsView())
        
        self.toggleCombinedModulesView()
        
        self.addArrangedSubview(scrollView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(toggleUninstallHelperButton), name: .fanHelperState, object: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .fanHelperState, object: nil)
    }
    
    public func viewWillAppear() {
        self.startAtLoginBtn?.state = LaunchAtLogin.isEnabled ? .on : .off
        
        var idx = self.updateSelector?.indexOfSelectedItem ?? 0
        if let items = self.updateSelector?.menu?.items {
            for (i, item) in items.enumerated() {
                if let obj = item.representedObject as? String, obj == self.updateIntervalValue {
                    idx = i
                }
            }
        }
        self.updateSelector?.selectItem(at: idx)
    }
    
    private func informationView() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: 240).isActive = true
        view.orientation = .vertical
        view.distribution = .fill
        view.alignment = .centerY
        view.spacing = 0
        
        let container: NSGridView = NSGridView()
        container.heightAnchor.constraint(equalToConstant: 180).isActive = true
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let iconView: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        
        let statsName: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 22))
        statsName.alignment = .center
        statsName.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        statsName.stringValue = "Stats"
        statsName.isSelectable = true
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let statsVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 16))
        statsVersion.alignment = .center
        statsVersion.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statsVersion.stringValue = "\(localizedString("Version")) \(versionNumber)"
        statsVersion.isSelectable = true
        statsVersion.toolTip = "\(localizedString("Build number")) \(buildNumber)"
        
        let updateButton: NSButton = NSButton()
        updateButton.title = localizedString("Check for update")
        updateButton.bezelStyle = .rounded
        updateButton.target = self
        updateButton.action = #selector(self.updateAction)
        
        container.addRow(with: [iconView])
        container.addRow(with: [statsName])
        container.addRow(with: [statsVersion])
        container.addRow(with: [updateButton])
        
        container.row(at: 1).height = 22
        container.row(at: 2).height = 20
        container.row(at: 3).height = 30
        
        view.addArrangedSubview(container)
        
        return view
    }
    
    private func settingsView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: self.frame.width - 15).isActive = true
        
        let grid: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        grid.rowSpacing = 10
        grid.columnSpacing = 20
        grid.xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        grid.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        self.updateSelector = selectView(
            action: #selector(self.toggleUpdateInterval),
            items: AppUpdateIntervals,
            selected: self.updateIntervalValue
        )
        grid.addRow(with: [
            self.titleView(localizedString("Check for updates")),
            self.updateSelector!
        ])
        grid.addRow(with: [
            self.titleView(localizedString("Temperature")),
            selectView(
                action: #selector(self.toggleTemperatureUnits),
                items: TemperatureUnits,
                selected: self.temperatureUnitsValue
            )
        ])
        grid.addRow(with: [NSGridCell.emptyContentView, self.toggleView(
            action: #selector(self.toggleDock),
            state: Store.shared.bool(key: "dockIcon", defaultValue: false),
            text: localizedString("Show icon in dock")
        )])
        self.startAtLoginBtn = self.toggleView(
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled,
            text: localizedString("Start at login")
        )
        grid.addRow(with: [NSGridCell.emptyContentView, self.startAtLoginBtn!])
        grid.addRow(with: [NSGridCell.emptyContentView, self.toggleView(
            action: #selector(self.toggleCombinedModules),
            state: self.combinedModulesState,
            text: localizedString("Combined modules")
        )])
        
        view.addArrangedSubview(grid)
        
        return view
    }
    
    private func combinedModulesView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: self.frame.width - 15).isActive = true
        
        let grid: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        grid.rowSpacing = 10
        grid.columnSpacing = 20
        grid.xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        grid.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        grid.addRow(with: [
            self.titleView(localizedString("Spacing")),
            selectView(
                action: #selector(self.toggleCombinedModulesSpacing),
                items: CombinedModulesSpacings,
                selected: self.combinedModulesSpacing
            )
        ])
        
        view.addArrangedSubview(self.moduleSelector)
        view.addArrangedSubview(grid)
        
        self.combinedModules = view
        return view
    }
    
    private func buttonsView() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 60))
        view.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .vertical
        row.alignment = .centerY
        row.distribution = .fill
        self.buttonsContainer = row
        
        let reset: NSButton = NSButton()
        reset.title = localizedString("Reset settings")
        reset.bezelStyle = .rounded
        reset.target = self
        reset.action = #selector(self.resetSettings)
        
        let uninstall: NSButton = NSButton()
        uninstall.title = localizedString("Uninstall fan helper")
        uninstall.bezelStyle = .rounded
        uninstall.target = self
        uninstall.action = #selector(self.uninstallHelper)
        self.uninstallHelperButton = uninstall
        
        row.addArrangedSubview(reset)
        if SMCHelper.shared.isInstalled {
            row.addArrangedSubview(uninstall)
        }
        
        view.addSubview(row)
        
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }
    
    // MARK: - helpers
    
    private func separatorView() -> NSBox {
        let view = NSBox()
        view.boxType = .separator
        return view
    }
    
    private func titleView(_ value: String) -> NSTextField {
        let field: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 120, height: 17))
        field.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        field.textColor = .secondaryLabelColor
        field.stringValue = value
        
        return field
    }
    
    private func toggleView(action: Selector, state: Bool, text: String) -> NSButton {
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
        button.setButtonType(.switch)
        button.state = state ? .on : .off
        button.title = text
        button.action = action
        button.isBordered = false
        button.isTransparent = false
        button.target = self
        
        return button
    }
    
    private func toggleCombinedModulesView() {
        self.combinedModules?.isHidden = !self.combinedModulesState
        self.combinedModulesSeparator?.isHidden = !self.combinedModulesState
    }
    
    // MARK: - actions
    
    @objc private func updateAction(_ sender: NSObject) {
        updater.check(force: true, completion: { result, error in
            if error != nil {
                debug("error updater.check(): \(error!.localizedDescription)")
                return
            }
            
            guard error == nil, let version: version_s = result else {
                debug("download error(): \(error!.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async(execute: {
                self.updateWindow.open(version, settingButton: true)
                return
            })
        })
    }
    
    @objc private func toggleUpdateInterval(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        Store.shared.set(key: "update-interval", value: key)
    }
    
    @objc private func toggleTemperatureUnits(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.temperatureUnitsValue = key
    }
    
    @objc private func toggleDock(_ sender: NSButton) {
        let state = sender.state
        
        Store.shared.set(key: "dockIcon", value: state == NSControl.StateValue.on)
        let dockIconStatus = state == NSControl.StateValue.on ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
        NSApp.setActivationPolicy(dockIconStatus)
        if state == .off {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        LaunchAtLogin.isEnabled = sender.state == NSControl.StateValue.on
        if !Store.shared.exist(key: "runAtLoginInitialized") {
            Store.shared.set(key: "runAtLoginInitialized", value: true)
        }
    }
    
    @objc private func resetSettings(_ sender: NSObject) {
        let alert = NSAlert()
        alert.messageText = localizedString("Reset settings")
        alert.informativeText = localizedString("Reset settings text")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedString("Yes"))
        alert.addButton(withTitle: localizedString("No"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            Store.shared.reset()
            if let path = Bundle.main.resourceURL?.deletingLastPathComponent().deletingLastPathComponent().absoluteString {
                asyncShell("/usr/bin/open \(path)")
                NSApp.terminate(self)
            }
        }
    }
    
    @objc private func toggleUninstallHelperButton(_ notification: Notification) {
        guard let state = notification.userInfo?["state"] as? Bool, let v = self.uninstallHelperButton else {
            return
        }
        if state && v.superview == nil {
            self.buttonsContainer?.addArrangedSubview(v)
        } else if !state && v.superview != nil {
            v.removeFromSuperview()
        }
    }
    
    @objc private func uninstallHelper() {
        SMCHelper.shared.uninstall()
    }
    
    @objc private func toggleCombinedModules(_ sender: NSButton) {
        self.combinedModulesState = sender.state == NSControl.StateValue.on
        self.toggleCombinedModulesView()
        NotificationCenter.default.post(name: .toggleOneView, object: nil, userInfo: nil)
    }
    
    @objc private func toggleCombinedModulesSpacing(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.combinedModulesSpacing = key
        NotificationCenter.default.post(name: .moduleRearrange, object: nil, userInfo: nil)
    }
}

private class ModuleSelectorView: NSStackView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Constants.Widget.height + (Constants.Settings.margin*2)))
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
        
        let background: NSVisualEffectView = {
            let view = NSVisualEffectView(frame: NSRect.zero)
            view.blendingMode = .withinWindow
            view.material = .contentBackground
            view.state = .active
            view.wantsLayer = true
            view.layer?.cornerRadius = 5
            return view
        }()
        
        var w = self.spacing
        modules.filter({ $0.available }).sorted(by: { $0.combinedPosition < $1.combinedPosition }).forEach { (m: Module) in
            let v = ModulePreview(id: m.name, icon: m.config.icon)
            self.addArrangedSubview(v)
            w += v.frame.width + self.spacing
        }
        
        self.addSubview(background, positioned: .below, relativeTo: .none)
        
        self.setFrameSize(NSSize(width: w, height: self.frame.height))
        background.setFrameSize(NSSize(width: w, height: self.frame.height))
        
        self.widthAnchor.constraint(equalToConstant: w).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let targetIdx = self.views.firstIndex(where: { $0.hitTest(location) != nil }),
              let window = self.window, self.views[targetIdx].identifier != nil else {
            super.mouseDragged(with: event)
            return
        }
        
        let view = self.views[targetIdx]
        let copy = ViewCopy(view)
        copy.zPosition = 2
        copy.transform = CATransform3DMakeScale(0.9, 0.9, 1)
        
        // hide the original view, show the copy
        view.subviews.forEach({ $0.isHidden = true })
        self.layer?.addSublayer(copy)
        
        // hide the copy view, show the original
        defer {
            copy.removeFromSuperlayer()
            view.subviews.forEach({ $0.isHidden = false })
        }
        
        var newIdx = -1
        let originCenter = view.frame.midX
        let originX = view.frame.origin.x
        let p0 = convert(event.locationInWindow, from: nil).x
        
        window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: 1e6, mode: .eventTracking) { event, stop in
            guard let event = event else {
                stop.pointee = true
                return
            }
            
            if event.type == .leftMouseDragged {
                let p1 = self.convert(event.locationInWindow, from: nil).x
                let diff = p1 - p0
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                copy.frame.origin.x = originX + diff
                CATransaction.commit()
                
                let reordered = self.views.map{
                    (view: $0, x: $0 !== view ? $0.frame.midX : originCenter + diff)
                }.sorted{ $0.x < $1.x }.map { $0.view }
                
                guard let nextIndex = reordered.firstIndex(of: view),
                      let prevIndex = self.views.firstIndex(of: view) else {
                    stop.pointee = true
                    return
                }
                
                if nextIndex != prevIndex {
                    newIdx = nextIndex
                    view.removeFromSuperviewWithoutNeedingDisplay()
                    self.insertArrangedSubview(view, at: newIdx)
                    self.layoutSubtreeIfNeeded()
                    
                    for (i, v) in self.views(in: .leading).compactMap({$0 as? ModulePreview}).enumerated() {
                        if let m = modules.first(where: { $0.name == v.identifier?.rawValue }) {
                            m.combinedPosition = i
                        }
                    }
                }
            } else {
                if newIdx != -1, let view = self.views[newIdx] as? ModulePreview, let id = view.identifier?.rawValue {
                    NotificationCenter.default.post(name: .moduleRearrange, object: nil, userInfo: ["id": id])
                }
                view.mouseUp(with: event)
                stop.pointee = true
            }
        }
    }
}

internal class ModulePreview: NSStackView {
    private let id: String
    private let imageView: NSImageView
    
    public init(id: String, icon: NSImage?) {
        self.id = id
        self.imageView = NSImageView(frame: NSRect(origin: .zero, size: NSSize(width: Constants.Widget.height, height: Constants.Widget.height)))
        
        let size: CGSize = CGSize(width: Constants.Widget.height + (Constants.Widget.spacing * 2), height: Constants.Widget.height)
        super.init(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = NSColor(hexString: "#dddddd").cgColor
        self.layer?.borderWidth = 1
        self.layer?.backgroundColor = NSColor.white.cgColor
        
        self.identifier = NSUserInterfaceItemIdentifier(rawValue: id)
        self.toolTip = localizedString("Move module", id)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .centerY
        self.spacing = 0
        
        self.imageView.image = icon
        
        self.addArrangedSubview(self.imageView)
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: size.width),
            self.heightAnchor.constraint(equalToConstant: size.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
    }
}
