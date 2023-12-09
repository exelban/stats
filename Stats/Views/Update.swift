//
//  Update.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 21/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class UpdateWindow: NSWindow, NSWindowDelegate {
    private let viewController: UpdateViewController = UpdateViewController()
    
    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.viewController.view.frame.width,
                y: NSScreen.main!.frame.height - self.viewController.view.frame.height,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: true
        )
        
        self.title = "Stats"
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.positionCenter()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    public func open(_ v: version_s, settingButton: Bool = false) {
        if !self.isVisible || settingButton {
            self.setIsVisible(true)
            self.makeKeyAndOrderFront(nil)
        }
        self.viewController.open(v)
    }
    
    private func positionCenter() {
        self.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - self.viewController.view.frame.width)/2,
            y: (NSScreen.main!.frame.height - self.viewController.view.frame.height)/1.75
        ))
    }
}

private class UpdateViewController: NSViewController {
    private var update: UpdateView
    
    public init() {
        self.update = UpdateView(frame: NSRect(x: 0, y: 0, width: 280, height: 176))
        super.init(nibName: nil, bundle: nil)
        self.view = self.update
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func open(_ v: version_s) {
        self.update.clear()
        
        if v.newest {
            self.update.newVersion(v)
            return
        }
        self.update.noUpdates()
    }
}

private class UpdateView: NSView {
    private var version: version_s? = nil
    private var path: String = ""
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        let sidebar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        
        self.addSubview(sidebar)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func newVersion(_ version: version_s) {
        self.version = version
        let view: NSStackView = NSStackView(frame: NSRect(
            x: Constants.Settings.margin,
            y: 0,
            width: self.frame.width-(Constants.Settings.margin*2),
            height: self.frame.height
        ))
        view.orientation = .vertical
        view.alignment = .centerX
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin*2,
            left: 0,
            bottom: Constants.Settings.margin,
            right: 0
        )
        
        let header: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 0, height: 44))
        header.heightAnchor.constraint(equalToConstant: header.frame.height).isActive = true
        header.orientation = .horizontal
        header.spacing = 10
        header.distribution = .equalCentering
        
        let icon: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        icon.setFrameSize(NSSize(width: 44, height: 44))
        icon.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let title: NSTextField = TextView()
        title.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        title.stringValue = localizedString("New version available")
        
        header.addArrangedSubview(icon)
        header.addArrangedSubview(title)
        
        let versions: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 32))
        versions.heightAnchor.constraint(equalToConstant: versions.frame.height).isActive = true
        versions.rowSpacing = 0
        versions.yPlacement = .fill
        versions.xPlacement = .fill
        
        let currentVersionTitle: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 16))
        currentVersionTitle.stringValue = localizedString("Current version: ")
        let currentVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        currentVersion.stringValue = version.current
        
        let latestVersionTitle: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 16))
        latestVersionTitle.stringValue = localizedString("Latest version: ")
        let latestVersion: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        latestVersion.stringValue = version.latest
        
        versions.addRow(with: [currentVersionTitle, currentVersion])
        versions.addRow(with: [latestVersionTitle, latestVersion])
        
        let buttons: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        buttons.heightAnchor.constraint(equalToConstant: buttons.frame.height).isActive = true
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually
        
        let closeButton: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: view.frame.width/2, height: 26))
        closeButton.title = localizedString("Close")
        closeButton.bezelStyle = .rounded
        closeButton.action = #selector(self.close)
        closeButton.target = self
        
        let changelogButton: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 0, height: 26))
        changelogButton.title = localizedString("Changelog")
        changelogButton.bezelStyle = .rounded
        changelogButton.action = #selector(self.changelog)
        changelogButton.target = self
        
        let downloadButton: NSButton = NSButton(frame: NSRect(x: view.frame.width/2, y: 0, width: view.frame.width/2, height: 26))
        downloadButton.title = localizedString("Download")
        downloadButton.bezelStyle = .rounded
        downloadButton.action = #selector(self.download)
        downloadButton.target = self
        
        buttons.addArrangedSubview(closeButton)
        buttons.addArrangedSubview(changelogButton)
        buttons.addArrangedSubview(downloadButton)
        
        view.addArrangedSubview(header)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(versions)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(buttons)
        
        self.addSubview(view)
    }
    
    public func noUpdates() {
        let view: NSView = NSView(frame: NSRect(x: 10, y: 10, width: self.frame.width - 20, height: self.frame.height - 20))
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: ((view.frame.height - 18)/2), width: view.frame.width, height: 34))
        title.font = NSFont.systemFont(ofSize: 14, weight: .light)
        title.alignment = .center
        title.stringValue = localizedString("The latest version of Stats installed")
        
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        button.title = localizedString("Close")
        button.bezelStyle = .rounded
        button.action = #selector(self.close)
        button.target = self
        
        view.addSubview(button)
        view.addSubview(title)
        self.addSubview(view)
    }
    
    public func clear() {
        self.subviews.filter{ !($0 is NSVisualEffectView) }.forEach{ $0.removeFromSuperview() }
    }
    
    @objc private func download(_ sender: Any) {
        guard let urlString = self.version?.url, let url = URL(string: urlString) else {
            return
        }
        
        self.clear()
        
        let view: NSView = NSView(frame: NSRect(x: 10, y: 10, width: self.frame.width - 20, height: self.frame.height - 20 - 26))
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: view.frame.height - 28, width: view.frame.width, height: 18))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.alignment = .center
        title.stringValue = localizedString("Downloading...")
        
        let progressBar: NSProgressIndicator = NSProgressIndicator()
        progressBar.frame = NSRect(x: 20, y: 64, width: view.frame.width - 40, height: 22)
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.isIndeterminate = false
        
        let state: NSTextField = TextView(frame: NSRect(x: 0, y: 48, width: view.frame.width, height: 18))
        state.font = NSFont.systemFont(ofSize: 12, weight: .light)
        state.alignment = .center
        state.textColor = .secondaryLabelColor
        state.stringValue = "0%"
        
        let closeButton: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        closeButton.title = localizedString("Cancel")
        closeButton.bezelStyle = .rounded
        closeButton.action = #selector(self.close)
        closeButton.target = self
        
        let installButton: NSButton = NSButton(frame: NSRect(x: view.frame.width/2, y: 0, width: view.frame.width/2, height: 26))
        installButton.title = localizedString("Install")
        installButton.bezelStyle = .rounded
        installButton.action = #selector(self.install)
        installButton.target = self
        installButton.isHidden = true
        
        updater.download(url, progress: { progress in
            DispatchQueue.main.async {
                progressBar.doubleValue = progress.fractionCompleted
                state.stringValue = "\(Int(progress.fractionCompleted*100))%"
            }
        }, completion: { path in
            self.path = path
            DispatchQueue.main.async {
                closeButton.setFrameSize(NSSize(width: view.frame.width/2, height: closeButton.frame.height))
                installButton.isHidden = false
            }
        })
        
        view.addSubview(title)
        view.addSubview(progressBar)
        view.addSubview(state)
        view.addSubview(closeButton)
        view.addSubview(installButton)
        self.addSubview(view)
    }
    
    @objc private func close(_ sender: Any) {
        self.window?.close()
    }
    
    @objc private func changelog(_ sender: Any) {
        if let version = self.version {
            NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats/releases/tag/\(version.latest)")!)
        }
    }
    
    @objc private func install(_ sender: Any) {
        updater.install(path: self.path) { error in
            if let error {
                showAlert("Error update Stats", error, .critical)
            }
        }
    }
}
