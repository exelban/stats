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
    
    public func setModules(_ list: UnsafeMutablePointer<[Module]>) {
        self.viewController.setModules(list)
        if list.pointee.filter({ $0.enabled != false}).count == 0 {
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
        
        let navigationView: NSScrollView = NSScrollView(frame: NSRect(x: 0, y: buttonHeight, width: navigationWidth, height: frame.height - buttonHeight))
        navigationView.wantsLayer = true
        navigationView.drawsBackground = false
        
        navigationView.addSubview(MenuView(n: 0, icon: NSImage(named: NSImage.Name("apps"))!, title: "Stats", callback: self.menuCallback(_:)))
        
        let buttonsView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: navigationWidth, height: buttonHeight))
        buttonsView.wantsLayer = true
        
        buttonsView.addSubview(self.makeButton(4, title: "Open Activity Monitor", image: "chart", action: #selector(openActivityMonitor)))
        buttonsView.addSubview(self.makeButton(3, title: "Report a bug", image: "bug", action: #selector(reportBug)))
        buttonsView.addSubview(self.makeButton(1, title: "Close application", image: "power", action: #selector(closeApp)))
        
        let mainView: NSView = NSView(frame: NSRect(x: navigationWidth, y: 0, width: frame.width - navigationWidth, height: frame.height))
        mainView.wantsLayer = true
        
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
            let menu: NSView = MenuView(n: n, icon: m.icon, title: m.name, callback: self.menuCallback(_:))
            self.navigationView?.addSubview(menu)
        }
        self.modules = list
//        self.openMenu("CPU")
    }
    
    private func menuCallback(_ title: String) {
        var view: NSView = self.applicationSettings
        
        let detectedModule = self.modules?.pointee.first{ $0.name == title }
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
        self.callback(self.title)
        
        self.titleView?.textColor = .labelColor
        self.imageView?.contentTintColor = .labelColor
        self.layer?.backgroundColor = .init(gray: 0.1, alpha: 0.5)
        self.active = true
    }
}

class ApplicationSettings: NSView {
    private let width: CGFloat = 540
    private let height: CGFloat = 480
    private let deviceInfoHeight: CGFloat = 300
    
    private let systemKit: SystemKit = SystemKit()
    private let store: Store = Store()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        self.wantsLayer = true
        self.layer?.backgroundColor = .clear
        
        self.addDeviceInfo()
        self.addSettings()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSettings() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 1, width: self.width-1, height: self.height - self.deviceInfoHeight))
        let rowHeight: CGFloat = 40
        let rowHorizontalPadding: CGFloat = 16
        
        let leftPanel: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width/2, height: view.frame.height))
        leftPanel.wantsLayer = true
        
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*3, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Processor",
            value: "\(self.systemKit.device.info?.cpu?.physicalCores ?? 0) cores (\(self.systemKit.device.info?.cpu?.logicalCores ?? 0) threads)"
        ))
        
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useGB]
        sizeFormatter.countStyle = .memory
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*2, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Memory",
            value: "\(sizeFormatter.string(fromByteCount: Int64(self.systemKit.device.info?.ram?.total ?? 0)))"
        ))
        
        let gpus = self.systemKit.device.info?.gpu
        var gpu: String = "Unknown"
        if gpus != nil {
            if gpus?.count == 1 {
                gpu = gpus![0].name
            } else {
                gpu = ""
                gpus!.forEach{ gpu += "\($0.name)\n" }
            }
        }
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: rowHeight*1, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "GPU",
            value: gpu
        ))
        
        leftPanel.addSubview(makeInfoRow(
            frame: NSRect(x: rowHorizontalPadding, y: 0, width: leftPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Disk",
            value: "\(self.systemKit.device.info?.disk?.model ?? self.systemKit.device.info?.disk?.name ?? "Unknown")"
        ))
        
        let rightPanel: NSView = NSView(frame: NSRect(x: self.width/2, y: 0, width: view.frame.width/2, height: view.frame.height))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*3, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Reserved",
            action: #selector(self.toggleSomething),
            state: true
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*2, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Check for updates on start",
            action: #selector(self.toggleUpdates),
            state: store.bool(key: "checkUpdatesOnLogin", defaultValue: true)
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: rowHeight*1, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Show icon in dock",
            action: #selector(self.toggleDock),
            state: store.bool(key: "dockIcon", defaultValue: false)
        ))
        
        rightPanel.addSubview(makeSettingRow(
            frame: NSRect(x: rowHorizontalPadding*0.5, y: 0, width: rightPanel.frame.width - (rowHorizontalPadding*1.5), height: rowHeight),
            title: "Start at login",
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled
        ))
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        self.addSubview(view)
    }
    
    private func makeInfoRow(frame: NSRect, title: String, value: String) -> NSView {
        let row: NSView = NSView(frame: frame)
        let titleWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 10
        
        let rowTitle: NSTextField = TextView(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: titleWidth, height: 17))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .secondaryLabelColor
        rowTitle.stringValue = title
        
        let rowValue: NSTextField = TextView(frame: NSRect(x: titleWidth, y: (row.frame.height - 16)/2, width: row.frame.width - titleWidth, height: 17))
        rowValue.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowValue.alignment = .right
        rowValue.stringValue = value
        
        if value.contains("\n") {
            rowValue.frame = NSRect(x: 80, y: 0, width: rowValue.frame.width, height: row.frame.height)
        }
        
        row.addSubview(rowTitle)
        row.addSubview(rowValue)
        
        return row
    }
    
    private func makeSettingRow(frame: NSRect, title: String, action: Selector, state: Bool) -> NSView {
        let row: NSView = NSView(frame: frame)
        let state: NSControl.StateValue = state ? .on : .off
        
        let rowTitle: NSTextField = TextView(frame: NSRect(x: 0, y: (row.frame.height - 16)/2, width: row.frame.width - 52, height: 17))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .secondaryLabelColor
        rowTitle.stringValue = title
        
        var toggle: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: row.frame.width - 50, y: 0, width: 50, height: row.frame.height))
            switchButton.state = state
            switchButton.action = action
            switchButton.target = self

            toggle = switchButton
        } else {
            let button: NSButton = NSButton(frame: NSRect(x: row.frame.width - 30, y: 0, width: 30, height: row.frame.height))
            button.setButtonType(.switch)
            button.state = state
            button.title = ""
            button.action = action
            button.isBordered = false
            button.isTransparent = true
            
            toggle = button
        }

        row.addSubview(toggle)
        row.addSubview(rowTitle)
        
        return row
    }
    
    private func addDeviceInfo() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.height - self.deviceInfoHeight, width: self.width, height: self.deviceInfoHeight))
        view.wantsLayer = true
        
        let leftPanel: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.width/2, height: self.deviceInfoHeight))
        leftPanel.wantsLayer = true
        
        let deviceImageView: NSImageView = NSImageView(image: (self.systemKit.device.model?.icon)!)
        deviceImageView.frame = NSRect(x: (leftPanel.frame.width - 160)/2, y: ((self.deviceInfoHeight - 120)/2) + 22, width: 160, height: 120)
        
        let deviceNameField: NSTextField = TextView(frame: NSRect(x: 0, y: 72, width: leftPanel.frame.width, height: 20))
        deviceNameField.alignment = .center
        deviceNameField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        deviceNameField.stringValue = (self.systemKit.device.model?.name)!

        let osField: NSTextField = TextView(frame: NSRect(x: 0, y: 52, width: leftPanel.frame.width, height: 18))
        osField.alignment = .center
        osField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        osField.stringValue = "macOS \(self.systemKit.device.os!.name) (\(self.systemKit.device.os!.version.getFullVersion()))"
        
        leftPanel.addSubview(deviceImageView)
        leftPanel.addSubview(deviceNameField)
        leftPanel.addSubview(osField)
        
        let rightPanel: NSView = NSView(frame: NSRect(x: self.width/2, y: 0, width: self.width/2, height: self.deviceInfoHeight))
        rightPanel.wantsLayer = true
        
        let iconView: NSImageView = NSImageView(frame: NSRect(x: (leftPanel.frame.width - 100)/2, y: ((self.deviceInfoHeight - 100)/2) + 32, width: 100, height: 100))
        iconView.image = NSImage(named: NSImage.Name("AppIcon"))!
        
        let infoView: NSView = NSView(frame: NSRect(x: 0, y: 54, width: self.width/2, height: 42))
        infoView.wantsLayer = true
        
        let statsName: NSTextField = TextView(frame: NSRect(x: 0, y: 20, width: leftPanel.frame.width, height: 22))
        statsName.alignment = .center
        statsName.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        statsName.stringValue = "Stats"
        
        let statsVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: leftPanel.frame.width, height: 16))
        statsVersion.alignment = .center
        statsVersion.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        statsVersion.stringValue = "Version \(versionNumber)"
        
        infoView.addSubview(statsName)
        infoView.addSubview(statsVersion)
        
        rightPanel.addSubview(iconView)
        rightPanel.addSubview(infoView)
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        
        self.addSubview(view)
    }
    
    @objc func toggleSomething(_ sender: NSObject) {
        
    }
    
    @objc func toggleUpdates(_ sender: NSObject) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        if state != nil {
            self.store.set(key: "checkUpdatesOnLogin", value: state! == NSControl.StateValue.on)
        }
    }
    
    @objc func toggleDock(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
  
        if state != nil {
            self.store.set(key: "dockIcon", value: state! == NSControl.StateValue.on)
        }
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        LaunchAtLogin.isEnabled = state! == NSControl.StateValue.on
        if !self.store.exist(key: "runAtLoginInitialized") {
            self.store.set(key: "runAtLoginInitialized", value: true)
        }
    }
}
