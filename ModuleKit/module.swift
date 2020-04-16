//
//  module.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import os.log
import StatsKit

public protocol Module_p {
    var name: String { get set }
    var icon: NSImage? { get set }

    var available: Bool { get }
    var enabled: Bool { get }

    var widget: Widget_p? { get }

    func readyCallback()
    func willTerminate()
}

open class Module: Module_p {
    public let log: OSLog
    public var name: String
    public var icon: NSImage? = nil
    public var widget: Widget_p?
    public var settings: Settings_p? = nil

    public var available: Bool = false
    public var enabled: Bool
    
    private let store: Store = Store()
    private let menuBarItem: NSStatusItem
    private var readers: [Reader_p] = []
    private var defaultWidget: String
    private var activeWidget: String {
        get {
            return self.store.string(key: "\(self.name)_widget", defaultValue: self.defaultWidget)
        }
    }
    private let window: NSWindow
    
    public init(name: String, icon: NSImage?, menuBarItem: NSStatusItem, defaultWidget: String, popup: NSView?) {
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: name)
        self.enabled = self.store.bool(key: "\(name)_state", defaultValue: true)
        self.name = name
        self.icon = icon
        self.defaultWidget = defaultWidget
        self.menuBarItem = menuBarItem
        self.menuBarItem.isVisible = false
        self.menuBarItem.autosaveName = name
        
        self.window = PopupWindow(title: name, view: popup)
        self.settings = Settings(delegate: self, title: name, enabled: self.enabled, enableCallback: self.toggleEnable)
        
        self.menuBarItem.button?.target = self
        self.menuBarItem.button?.action = #selector(toggleMenu)
        self.menuBarItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }
    
    public init(fake: Bool) {
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "fake")
        self.enabled = false
        self.name = "fake"
        self.defaultWidget = "fake"
        self.menuBarItem = NSStatusItem()
        self.window = NSWindow()
    }
    
    public func terminate() {
        self.willTerminate()
        self.readers.forEach{ $0.stop() }
        NSStatusBar.system.removeStatusItem(self.menuBarItem)
        os_log(.debug, log: log, "Module terminated")
    }
    
    public func enable() {
        self.enabled = true
        self.store.set(key: "\(name)_state", value: true)
        self.readers.forEach{ $0.start() }
        self.menuBarItem.isVisible = true
        os_log(.debug, log: log, "Module enabled")
    }
    
    public func disable() {
        self.enabled = false
        self.store.set(key: "\(name)_state", value: false)
        self.readers.forEach{ $0.pause() }
        self.menuBarItem.isVisible = false
        self.window.setIsVisible(false)
        os_log(.debug, log: log, "Module disabled")
    }
    
    private func toggleEnable() {
        if self.enabled {
            self.disable()
        } else {
            self.enable()
        }
    }
    
    public func load() throws {
        self.available = self.isAvailable()
        
        if !self.available {
            self.terminate()
            return
        }
        
        guard let widget = LoadWidget(type: self.activeWidget) else {
            throw "widget with type \(self.activeWidget) not found"
        }
        os_log(.debug, log: log, "Successfully load widget: %s", "\(type(of: widget))")
        
        widget.setTitle(self.name)
        widget.widthHandler = self.setWidgetWidth
        self.widget = widget
        
        os_log(.debug, log: log, "Successfully load module")
    }
    
    public func addReader(_ reader: Reader_p) {
        if self.enabled {
            reader.start()
        }
        self.readers.append(reader)
        
        os_log(.debug, log: log, "Successfully add reader %s", "\(type(of: reader))")
    }
    
    public func readyCallback() {
        if self.widget != nil {
            self.menuBarItem.length = self.widget!.frame.width
            self.menuBarItem.button?.addSubview(self.widget!)
            os_log(.debug, log: log, "Reader report readiness")
        }
        
        if self.enabled {
            self.menuBarItem.isVisible = true
        }
    }
    
    public func setWidgetWidth(_ width: CGFloat) {
        os_log(.debug, log: log, "Widget %s adjust width to %.2f", "\(type(of: self.widget!))", width)
        self.menuBarItem.length = width
    }
    
    open func isAvailable() -> Bool { return true }
    open func willTerminate() {}
    
    @objc private func toggleMenu(_ sender: Any?) {
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }
        
        if self.window.occlusionState.rawValue == 8192 {
            NSApplication.shared.activate(ignoringOtherApps: true)

            let buttonOrigin = self.menuBarItem.button?.window?.frame.origin
            let buttonCenter = (self.menuBarItem.button?.window?.frame.width)! / 2
            let windowCenter = self.window.frame.width / 2
            
            var x = buttonOrigin!.x - windowCenter + buttonCenter
            let y = buttonOrigin!.y - self.window.frame.height - 3
            
            if let screen = NSScreen.main {
                let width = screen.frame.size.width
                
                if x + self.window.frame.width > width {
                    x = width - self.window.frame.width
                }
            }
            if buttonOrigin!.x - self.window.frame.width < 0 {
                x = 0
            }
            
            self.window.setFrameOrigin(NSPoint(x: x, y: y))
            self.window.setIsVisible(true)
        }
    }
}
