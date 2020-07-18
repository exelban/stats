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
import StatsKit
import os.log

class UpdateWindow: NSWindow, NSWindowDelegate {
    private let viewController: UpdateViewController = UpdateViewController()
    
    init() {
        let w = NSScreen.main!.frame.width
        let h = NSScreen.main!.frame.height
        super.init(
            contentRect: NSMakeRect(
                w - self.viewController.view.frame.width,
                h - self.viewController.view.frame.height,
                self.viewController.view.frame.width,
                self.viewController.view.frame.height
            ),
            styleMask: [.closable, .titled],
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
    
    public func open(_ v: version_s) {
        if !self.isVisible {
            self.setIsVisible(true)
            self.makeKeyAndOrderFront(nil)
        }
        self.viewController.open(v)
    }
}

private class UpdateViewController: NSViewController {
    private var update: UpdateView
    
    public init() {
        self.update = UpdateView(frame: NSRect(x: 0, y: 0, width: 280, height: 150))
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func newVersion(_ version: version_s) {
        self.version = version
        let view: NSView = NSView(frame: NSRect(x: 10, y: 10, width: self.frame.width - 20, height: self.frame.height - 20))
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: view.frame.height - 20, width: view.frame.width, height: 18))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.alignment = .center
        title.stringValue = "New version available"
        
        let currentVersionString = "Current version:  \(version.current)"
        let currentVersionWidth = currentVersionString.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light))
        let currentVersion: NSTextField = TextView(frame: NSRect(
            x: (view.frame.width-currentVersionWidth)/2,
            y: title.frame.origin.y - 40,
            width: currentVersionWidth,
            height: 16
        ))
        currentVersion.stringValue = currentVersionString
        
        let latestVersionString = "Latest version:    \(version.latest)"
        let latestVersionWidth = latestVersionString.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light))
        let latestVersion: NSTextField = TextView(frame: NSRect(
        x: (view.frame.width-currentVersionWidth)/2,
            y: currentVersion.frame.origin.y - 22,
            width: latestVersionWidth,
            height: 16
        ))
        latestVersion.stringValue = latestVersionString
        
        let closeButton: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: view.frame.width/2, height: 26))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.action = #selector(self.close)
        closeButton.target = self
        
        let downloadButton: NSButton = NSButton(frame: NSRect(x: view.frame.width/2, y: 0, width: view.frame.width/2, height: 26))
        downloadButton.title = "Download"
        downloadButton.bezelStyle = .rounded
        downloadButton.action = #selector(self.download)
        downloadButton.target = self
        
        view.addSubview(title)
        view.addSubview(currentVersion)
        view.addSubview(latestVersion)
        view.addSubview(closeButton)
        view.addSubview(downloadButton)
        self.addSubview(view)
    }
    
    public func noUpdates() {
        let view: NSView = NSView(frame: NSRect(x: 10, y: 10, width: self.frame.width - 20, height: self.frame.height - 20))
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: ((view.frame.height - 18)/2)+20, width: view.frame.width, height: 18))
        title.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        title.alignment = .center
        title.stringValue = "The latest version of Stats installed"
        
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        button.title = "Close"
        button.bezelStyle = .rounded
        button.action = #selector(self.close)
        button.target = self
        
        view.addSubview(button)
        view.addSubview(title)
        self.addSubview(view)
    }
    
    public func clear() {
        self.subviews.forEach{ $0.removeFromSuperview() }
    }
    
    @objc private func download(_ sender: Any) {
        guard let urlString = self.version?.url, let url = URL(string: urlString) else {
            return
        }
        
        self.clear()
        
        let view: NSView = NSView(frame: NSRect(x: 10, y: 10, width: self.frame.width - 20, height: self.frame.height - 20))
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: view.frame.height - 28, width: view.frame.width, height: 18))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.alignment = .center
        title.stringValue = "Downloading..."
        
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
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.action = #selector(self.close)
        closeButton.target = self
        
        let installButton: NSButton = NSButton(frame: NSRect(x: view.frame.width/2, y: 0, width: view.frame.width/2, height: 26))
        installButton.title = "Install"
        installButton.bezelStyle = .rounded
        installButton.action = #selector(self.install)
        installButton.target = self
        installButton.isHidden = true
        
        updater.download(url, progressHandler: { progress in
            DispatchQueue.main.async {
                progressBar.doubleValue = progress.fractionCompleted
                state.stringValue = "\(Int(progress.fractionCompleted*100))%"
            }
        }, doneHandler: { path in
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
    
    @objc private func install(_ sender: Any) {
        updater.install(path: self.path)
    }
}
