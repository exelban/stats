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
        get { Store.shared.string(key: "temperature_units", defaultValue: "system") }
        set { Store.shared.set(key: "temperature_units", value: newValue) }
    }
    
    private var combinedModulesState: Bool {
        get { Store.shared.bool(key: "CombinedModules", defaultValue: false) }
        set { Store.shared.set(key: "CombinedModules", value: newValue) }
    }
    private var combinedModulesSpacing: String {
        get { Store.shared.string(key: "CombinedModules_spacing", defaultValue: "none") }
        set { Store.shared.set(key: "CombinedModules_spacing", value: newValue) }
    }
    private var combinedModulesSeparator: Bool {
        get { Store.shared.bool(key: "CombinedModules_separator", defaultValue: false) }
        set { Store.shared.set(key: "CombinedModules_separator", value: newValue) }
    }
    private var combinedModulesPopup: Bool {
        get { Store.shared.bool(key: "CombinedModules_popup", defaultValue: true) }
        set { Store.shared.set(key: "CombinedModules_popup", value: newValue) }
    }
    
    private var updateSelector: NSPopUpButton?
    private var startAtLoginBtn: NSSwitch?
    private var telemetryBtn: NSSwitch?
    
    private var combinedModulesView: PreferencesSection?
    private var fanHelperView: PreferencesSection?
    
    private let updateWindow: UpdateWindow = UpdateWindow()
    private let moduleSelector: ModuleSelectorView = ModuleSelectorView()
    
    private var CPUeButton: NSButton?
    private var CPUpButton: NSButton?
    private var GPUButton: NSButton?
    
    private var CPUeTest: CPUeStressTest = CPUeStressTest()
    private var CPUpTest: CPUpStressTest = CPUpStressTest()
    private var GPUTest: GPUStressTest? = GPUStressTest()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = ScrollableStackView(orientation: .vertical)
        scrollView.stackView.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        scrollView.stackView.spacing = Constants.Settings.margin
        
        scrollView.stackView.addArrangedSubview(self.informationView())
        
        self.updateSelector = selectView(
            action: #selector(self.toggleUpdateInterval),
            items: AppUpdateIntervals,
            selected: self.updateIntervalValue
        )
        self.startAtLoginBtn = switchView(
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled
        )
        self.telemetryBtn = switchView(
            action: #selector(self.toggleTelemetry),
            state: telemetry.isEnabled
        )
        
        scrollView.stackView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Check for updates"), component: self.updateSelector!),
            PreferencesRow(localizedString("Temperature"), component: selectView(
                action: #selector(self.toggleTemperatureUnits),
                items: TemperatureUnits,
                selected: self.temperatureUnitsValue
            )),
            PreferencesRow(localizedString("Show icon in dock"), component: switchView(
                action: #selector(self.toggleDock),
                state: Store.shared.bool(key: "dockIcon", defaultValue: false)
            )),
            PreferencesRow(localizedString("Start at login"), component: self.startAtLoginBtn!),
            PreferencesRow(localizedString("Share anonymous telemetry"), component: self.telemetryBtn!)
        ]))
        
        self.combinedModulesView = PreferencesSection([
            PreferencesRow(localizedString("Combined modules"), component: switchView(
                action: #selector(self.toggleCombinedModules),
                state: self.combinedModulesState
            )),
            PreferencesRow(component: self.moduleSelector),
            PreferencesRow(localizedString("Spacing"), component: selectView(
                action: #selector(self.toggleCombinedModulesSpacing),
                items: CombinedModulesSpacings,
                selected: self.combinedModulesSpacing
            )),
            PreferencesRow(localizedString("Separator"), component: switchView(
                action: #selector(self.toggleCombinedModulesSeparator),
                state: self.combinedModulesSeparator
            )),
            PreferencesRow(localizedString("Combined details"), component: switchView(
                action: #selector(self.toggleCombinedModulesPopup),
                state: self.combinedModulesPopup
            ))
        ])
        scrollView.stackView.addArrangedSubview(self.combinedModulesView!)
        self.combinedModulesView?.setRowVisibility(1, newState: self.combinedModulesState)
        self.combinedModulesView?.setRowVisibility(2, newState: self.combinedModulesState)
        self.combinedModulesView?.setRowVisibility(3, newState: self.combinedModulesState)
        self.combinedModulesView?.setRowVisibility(4, newState: self.combinedModulesState)
        
        scrollView.stackView.addArrangedSubview(PreferencesSection(label: localizedString("Settings"), [
            PreferencesRow(
                localizedString("Export settings"),
                component: buttonView(#selector(self.exportSettings), text: localizedString("Save"))
            ),
            PreferencesRow(
                localizedString("Import settings"),
                component: buttonView(#selector(self.importSettings), text: localizedString("Browse"))
            ),
            PreferencesRow(
                localizedString("Reset settings"),
                component: buttonView(#selector(self.resetSettings), text: localizedString("Reset"))
            )
        ]))
        
        self.fanHelperView = PreferencesSection([
            PreferencesRow(
                localizedString("Uninstall fan helper"),
                component: buttonView(#selector(self.uninstallHelper), text: localizedString("Uninstall"))
            )
        ])
        scrollView.stackView.addArrangedSubview(self.fanHelperView!)
        
        self.addArrangedSubview(scrollView)
        
        let CPUeButton = buttonView(#selector(self.toggleCPUeStressTest), text: localizedString("Run"))
        let CPUpButton = buttonView(#selector(self.toggleCPUpStressTest), text: localizedString("Run"))
        let GPUButton = buttonView(#selector(self.toggleGPUStressTest), text: localizedString("Run"))
        
        self.CPUeButton = CPUeButton
        self.CPUpButton = CPUpButton
        self.GPUButton = GPUButton
        
        var tests = [
            PreferencesRow(localizedString("Efficiency cores"), component: CPUeButton),
            PreferencesRow(localizedString("Performance cores"), component: CPUpButton)
        ]
        if self.GPUTest != nil {
            tests.append(PreferencesRow(localizedString("GPU"), component: GPUButton))
        }
        scrollView.stackView.addArrangedSubview(PreferencesSection(label: localizedString("Stress tests"), tests))
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.toggleUninstallHelperButton), name: .fanHelperState, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .fanHelperState, object: nil)
    }
    
    internal func viewWillAppear() {
        self.startAtLoginBtn?.state = LaunchAtLogin.isEnabled ? .on : .off
        self.telemetryBtn?.state = telemetry.isEnabled ? .on : .off
        
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
        view.heightAnchor.constraint(equalToConstant: 220).isActive = true
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
    
    // MARK: - actions
    
    @objc private func updateAction() {
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
    
    @objc private func toggleTelemetry(_ sender: NSButton) {
        telemetry.isEnabled = sender.state == NSControl.StateValue.on
    }
    
    @objc private func toggleCombinedModules(_ sender: NSButton) {
        self.combinedModulesState = sender.state == NSControl.StateValue.on
        self.combinedModulesView?.setRowVisibility(1, newState: self.combinedModulesState)
        self.combinedModulesView?.setRowVisibility(2, newState: self.combinedModulesState)
        self.combinedModulesView?.setRowVisibility(3, newState: self.combinedModulesState)
        self.combinedModulesView?.setRowVisibility(4, newState: self.combinedModulesState)
        NotificationCenter.default.post(name: .toggleOneView, object: nil, userInfo: nil)
    }
    
    @objc private func toggleCombinedModulesSpacing(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.combinedModulesSpacing = key
        NotificationCenter.default.post(name: .moduleRearrange, object: nil, userInfo: nil)
    }
    
    @objc private func toggleCombinedModulesSeparator(_ sender: NSButton) {
        self.combinedModulesSeparator = sender.state == NSControl.StateValue.on
        NotificationCenter.default.post(name: .moduleRearrange, object: nil, userInfo: nil)
    }
    
    @objc private func toggleCombinedModulesPopup(_ sender: NSButton) {
        self.combinedModulesPopup = sender.state == NSControl.StateValue.on
        NotificationCenter.default.post(name: .combinedModulesPopup, object: nil, userInfo: nil)
    }
    
    @objc private func importSettings() {
        let panel = NSOpenPanel()
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        panel.begin { (result) in
            guard result.rawValue == NSApplication.ModalResponse.OK.rawValue else { return }
            if let url = panel.url {
                Store.shared.import(from: url)
            }
        }
    }
    
    @objc private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Stats.plist"
        panel.showsTagField = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        panel.begin { (result) in
            guard result.rawValue == NSApplication.ModalResponse.OK.rawValue else { return }
            if let url = panel.url {
                Store.shared.export(to: url)
            }
        }
    }
    
    @objc private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = localizedString("Reset settings")
        alert.informativeText = localizedString("Reset settings text")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedString("Yes"))
        alert.addButton(withTitle: localizedString("No"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            Store.shared.reset()
            restartApp(self)
        }
    }
    
    @objc private func toggleUninstallHelperButton(_ notification: Notification) {
        guard let state = notification.userInfo?["state"] as? Bool, let v = self.fanHelperView else {
            return
        }
        v.isHidden = !state
    }
    
    @objc private func uninstallHelper() {
        SMCHelper.shared.uninstall()
    }
    
    @objc private func toggleCPUeStressTest() {
        if self.CPUeTest.isRunning {
            self.CPUeTest.stop()
            self.CPUeButton?.title = localizedString("Run")
        } else {
            self.CPUeTest.start()
            self.CPUeButton?.title = localizedString("Stop")
        }
    }
    
    @objc private func toggleCPUpStressTest() {
        if self.CPUpTest.isRunning {
            self.CPUpTest.stop()
            self.CPUpButton?.title = localizedString("Run")
        } else {
            self.CPUpTest.start()
            self.CPUpButton?.title = localizedString("Stop")
        }
    }
    
    @objc private func toggleGPUStressTest() {
        guard let test = self.GPUTest else { return }
        
        if test.isRunning {
            test.stop()
            self.GPUButton?.title = localizedString("Run")
        } else {
            test.start()
            self.GPUButton?.title = localizedString("Stop")
        }
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
        
        if w < 20 {
            w = 20
        }
        
        self.addSubview(background, positioned: .below, relativeTo: .none)
        
        self.setFrameSize(NSSize(width: w, height: self.frame.height))
        background.setFrameSize(NSSize(width: w, height: self.frame.height))
        
        self.widthAnchor.constraint(equalToConstant: w).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
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

private class ModulePreview: NSStackView {
    private let imageView: NSImageView
    
    fileprivate init(id: String, icon: NSImage?) {
        self.imageView = NSImageView(frame: NSRect(origin: .zero, size: NSSize(width: Constants.Widget.height, height: Constants.Widget.height)))
        
        let size: CGSize = CGSize(width: Constants.Widget.height + (Constants.Widget.spacing * 2), height: Constants.Widget.height)
        super.init(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.borderColor = NSColor(red: 221/255, green: 221/255, blue: 221/255, alpha: 1).cgColor
        self.layer?.borderWidth = 1
        self.layer?.backgroundColor = NSColor.white.cgColor
        
        self.identifier = NSUserInterfaceItemIdentifier(rawValue: id)
        self.setAccessibilityElement(true)
        self.toolTip = id
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .centerY
        self.spacing = 0
        
        self.imageView.image = icon
        self.imageView.contentTintColor = self.isDarkMode ? .textBackgroundColor : .textColor
        
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
    
    override func updateLayer() {
        self.imageView.contentTintColor = self.isDarkMode ? .textBackgroundColor : .textColor
    }
    
    override func mouseEntered(with: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
    }
}
