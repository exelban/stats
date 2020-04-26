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
    var name: String { get }
    var icon: NSImage? { get }
    var available: Bool { get }
    var enabled: Bool { get }
    var defaultWidget: widget_t { get }
    var availableWidgets: [widget_t] { get set }
    
    var widget: Widget_p? { get }
    var settings: Settings_p? { get }
    
    func load()
    func terminate()
}

open class Module: Module_p {
    public var name: String = ""
    public var icon: NSImage? = nil
    public var defaultWidget: widget_t = .unknown
    public var available: Bool = false
    public var enabled: Bool = false
    public var availableWidgets: [widget_t] = []
    
    public var widget: Widget_p? = nil
    public var settings: Settings_p? = nil
    
    private let log: OSLog
    private var store: UnsafePointer<Store>? = nil
    private var readers: [Reader_p] = []
    private var menuBarItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var activeWidget: widget_t {
        get {
            let widgetStr = self.store?.pointee.string(key: "\(self.name)_widget", defaultValue: self.defaultWidget.rawValue)
            return widget_t.allCases.first{ $0.rawValue == widgetStr } ?? widget_t.unknown
        }
        set {}
    }
    private var ready: Bool = false
    private var window: NSWindow = NSWindow()
    
    public init(store: UnsafePointer<Store>?, name: String, icon: NSImage?, popup: NSView?, defaultWidget: widget_t, widgets: UnsafePointer<[widget_t]>?, defaultState: Bool) {
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: name)
        self.name = name
        self.icon = icon
        self.store = store
        self.defaultWidget = defaultWidget
        self.available = self.isAvailable()
        self.enabled = self.store?.pointee.bool(key: "\(name)_state", defaultValue: defaultState) ?? false
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForWidgetSwitch), name: .switchWidget, object: nil)
        
        self.setWidget()
        self.settings = Settings(title: name, enabled: self.enabled, activeWidget: self.widget, widgets: widgets)
        self.settings?.toggleCallback = { [weak self] in
            self?.toggleEnabled()
        }
        
        self.menuBarItem.isVisible = self.enabled
        self.menuBarItem.autosaveName = self.name
        self.menuBarItem.button?.target = self
        self.menuBarItem.button?.action = #selector(toggleMenu)
        self.menuBarItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        
        self.window = PopupWindow(title: name, view: popup)
    }
    
    open func load() {
        if self.enabled && self.widget != nil {
            self.menuBarItem.length = self.widget!.frame.width
            self.menuBarItem.button?.addSubview(self.widget!)
        }
    }
    
    open func terminate() {
        self.readers.forEach{
            $0.stop()
            $0.terminate()
        }
        NSStatusBar.system.removeStatusItem(self.menuBarItem)
        os_log(.debug, log: log, "Module terminated")
    }
    
    public func enable() {
        self.enabled = true
        self.store?.pointee.set(key: "\(name)_state", value: true)
        self.readers.forEach{ $0.start() }
        self.menuBarItem.isVisible = true
        os_log(.debug, log: log, "Module enabled")
    }
    
    public func disable() {
        self.enabled = false
        self.store?.pointee.set(key: "\(name)_state", value: false)
        self.readers.forEach{ $0.pause() }
        self.menuBarItem.isVisible = false
        self.window.setIsVisible(false)
        os_log(.debug, log: log, "Module disabled")
    }
    
    private func toggleEnabled() {
        if self.enabled {
            self.disable()
        } else {
            self.enable()
        }
    }
    
    public func addReader(_ reader: Reader_p) {
        if self.enabled {
            reader.read()
            reader.start()
        }
        self.readers.append(reader)
        
        os_log(.debug, log: log, "Successfully add reader %s", "\(reader.self)")
    }
    
    public func readyHandler() {
        os_log(.debug, log: log, "Reader report readiness")
        self.ready = true
    }
    
    public func widgetWidthHandler(_ width: CGFloat) {
        os_log(.debug, log: log, "Widget %s adjust width to %.2f", "\(type(of: self.widget!))", width)
        self.menuBarItem.length = width
    }
    
    open func isAvailable() -> Bool { return true }
    
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
    
    @objc private func listenForWidgetSwitch(_ notification: Notification) {
        if let moduleName = notification.userInfo?["module"] as? String {
            if let widgetName = notification.userInfo?["widget"] as? String {
                if moduleName == self.name {
                    if let widgetType = widget_t.allCases.first(where: { $0.rawValue == widgetName }) {
                        self.activeWidget = widgetType
                        self.store?.pointee.set(key: "\(self.name)_widget", value: widgetType.rawValue)
                        self.setWidget()
                        os_log(.debug, log: log, "Widget is changed to: %s", "\(widgetName)")
                    }
                }
            }
        }
    }
    
    private func setWidget() {
        self.widget = LoadWidget(self.activeWidget, preview: false, title: self.name, store: self.store)
        if self.widget == nil {
            self.enabled = false
            os_log(.error, log: log, "widget with type %s not found", "\(self.activeWidget)")
            return
        }
        os_log(.debug, log: log, "Successfully initialize widget: %s", "\(String(describing: self.widget!))")
        
        self.widget?.widthHandler = { [weak self] value in
            self?.widgetWidthHandler(value)
        }
        
        self.readers.forEach{ $0.read() }
        if let mainReader = self.readers.first(where: { !$0.optional }) {
            self.widget?.setValues(mainReader.getHistory())
        }
        
        self.menuBarItem.length = self.widget!.frame.width
        self.menuBarItem.button?.subviews.forEach{ $0.removeFromSuperview() }
        self.menuBarItem.button?.addSubview(self.widget!)
        
        self.settings?.setActiveWidget(self.widget)
    }
}
