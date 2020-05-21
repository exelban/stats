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
            contentRect: NSMakeRect(w - self.viewController.view.frame.width, h - self.viewController.view.frame.height, self.viewController.view.frame.width, self.viewController.view.frame.height),
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
    
    public func open(_ v: version) {
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
    
    public func open(_ v: version) {
        self.update.setVersions(v)
    }
}

private class UpdateView: NSView {
    private let progressBar: NSProgressIndicator = NSProgressIndicator()
    private var version: version? = nil
    private var informationView: NSView? = nil
    private var noNew: NSView? = nil
    private var currentVersion: NSTextField? = nil
    private var latestVersion: NSTextField? = nil
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        self.addProgressBar()
        self.addInformation()
        self.addNoNew()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addProgressBar() {
        self.progressBar.isDisplayedWhenStopped = false
        self.progressBar.frame = NSRect(x: (self.frame.width - 22)/2, y: (self.frame.height - 22)/2, width: 22, height: 22)
        self.progressBar.style = .spinning
        
        self.addSubview(self.progressBar)
    }
    
    private func addInformation() {
        let view: NSView = NSView(frame: NSRect(x: 10, y: 10, width: self.frame.width - 20, height: self.frame.height - 20))
        
        let title: NSTextField = TextView(frame: NSRect(x: 0, y: view.frame.height - 18, width: view.frame.width, height: 18))
        title.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        title.alignment = .center
        title.stringValue = "New version available"
        
        let currentVersion: NSTextField = TextView(frame: NSRect(x: 0, y: title.frame.origin.y - 40, width: view.frame.width, height: 16))
        currentVersion.stringValue = "Current version:  0.0.0"
        
        let latestVersion: NSTextField = TextView(frame: NSRect(x: 0, y: currentVersion.frame.origin.y - 22, width: view.frame.width, height: 16))
        latestVersion.stringValue = "Latest version:    0.0.0"
        
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        button.title = "Download"
        button.bezelStyle = .rounded
        button.action = #selector(self.download)
        button.target = self
        
        view.addSubview(title)
        view.addSubview(currentVersion)
        view.addSubview(latestVersion)
        view.addSubview(button)
        view.isHidden = true
        self.addSubview(view)
        self.informationView = view
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
    }
    
    private func addNoNew() {
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
        self.noNew = view
    }
    
    public func setVersions(_ v: version) {
        self.progressBar.stopAnimation(self)
        self.noNew?.isHidden = true
        self.informationView?.isHidden = true
        
        if v.newest {
            self.informationView?.isHidden = false
            self.version = v
            
            currentVersion?.stringValue = "Current version:  \(v.current)"
            latestVersion?.stringValue =  "Latest version:    \(v.latest)"
            return
        }
        
        self.noNew?.isHidden = false
    }
    
    @objc func close(_ sender: Any) {
        self.window?.setIsVisible(false)
    }
    
    @objc func download(_ sender: Any) {
        guard let urlString = self.version?.url, let url = URL(string: urlString) else {
            return
        }
        os_log(.debug, log: log, "start downloading new version of app from: %s", "\(url.absoluteString)")
        updater.download(url)
        self.progressBar.startAnimation(self)
        self.informationView?.isHidden = true
    }
}
