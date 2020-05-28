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
    var available: Bool { get }
    var enabled: Bool { get }
    
    var widget: Widget_p? { get }
    var settings: Settings_p? { get }
    
    func load()
    func terminate()
}

public struct module_c {
    public var name: String = ""
    public var icon: NSImage? = nil
    
    var defaultState: Bool = false
    var defaultWidget: widget_t = .unknown
    var availableWidgets: [widget_t] = []
    
    var widgetsConfig: NSDictionary = NSDictionary()
    
    init(in path: String) {
        let dict: NSDictionary = NSDictionary(contentsOfFile: path)!
        
        if let name = dict["Name"] as? String {
            self.name = name
        }
        if let state = dict["State"] as? Bool {
            self.defaultState = state
        }
        
        if let widgetsDict = dict["Widgets"] as? NSDictionary {
            self.widgetsConfig = widgetsDict
            for widgetName in widgetsDict.allKeys {
                if let widget = widget_t(rawValue: widgetName as! String) {
                    self.availableWidgets.append(widget)
                    
                    let widgetDict = widgetsDict[widgetName as! String] as! NSDictionary
                    if widgetDict["Default"] as! Bool {
                        self.defaultWidget = widget
                    }
                }
            }
        }
    }
}

open class Module: Module_p {
    public var config: module_c
    
    public var available: Bool = false
    public var enabled: Bool = false
    
    public var widget: Widget_p? = nil
    public var settings: Settings_p? = nil
    
    private var settingsView: Settings_v? = nil
    private var popup: NSWindow = NSWindow()
    
    private let log: OSLog
    private var store: UnsafePointer<Store>? = nil
    private var readers: [Reader_p] = []
    private var menuBarItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var activeWidget: widget_t {
        get {
            let widgetStr = self.store?.pointee.string(key: "\(self.config.name)_widget", defaultValue: self.config.defaultWidget.rawValue)
            return widget_t.allCases.first{ $0.rawValue == widgetStr } ?? widget_t.unknown
        }
        set {}
    }
    private var ready: Bool = false
    private var widgetLoaded: Bool = false
    
    public init(store: UnsafePointer<Store>?, popup: NSView?, settings: Settings_v?) {
        self.config = module_c(in: Bundle(for: type(of: self)).path(forResource: "config", ofType: "plist")!)
        
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: self.config.name)
        self.store = store
        self.settingsView = settings
        self.available = self.isAvailable()
        self.enabled = self.store?.pointee.bool(key: "\(self.config.name)_state", defaultValue: self.config.defaultState) ?? false
        self.menuBarItem.isVisible = self.enabled
        self.menuBarItem.autosaveName = self.config.name
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForWidgetSwitch), name: .switchWidget, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForMouseDownInSettings), name: .clickInSettings, object: nil)
        
        if self.config.widgetsConfig.count != 0 {
            self.setWidget()
        } else {
            os_log(.debug, log: log, "Module started without widget")
        }
        
        self.settings = Settings(config: &self.config, enabled: self.enabled, activeWidget: self.widget, moduleSettings: { [weak self] (_ superview: NSView) in
            if self != nil && self?.settingsView != nil {
                self!.settingsView!.load(rect: superview.frame, widget: self!.activeWidget)
                superview.setFrameSize(NSSize(width: superview.frame.width, height: self!.settingsView!.frame.height))
                superview.addSubview(self!.settingsView!)
            }
        })
        self.settings?.toggleCallback = { [weak self] in
            self?.toggleEnabled()
        }
        
        self.popup = PopupWindow(title: self.config.name, view: popup)
    }
    
    // load function which call when app start
    public func load() {
        if self.enabled && self.widget != nil && self.ready {
            DispatchQueue.main.async {
                self.menuBarItem.button?.target = self
                self.menuBarItem.button?.action = #selector(self.togglePopup)
                self.menuBarItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
                
                self.menuBarItem.length = self.widget!.frame.width
                self.menuBarItem.button?.addSubview(self.widget!)
                self.widgetLoaded = true
            }
        }
    }
    
    // terminate function which call before app termination
    public func terminate() {
        self.willTerminate()
        self.readers.forEach{
            $0.stop()
            $0.terminate()
        }
        NSStatusBar.system.removeStatusItem(self.menuBarItem)
        os_log(.debug, log: log, "Module terminated")
    }
    
    // function to call before module terminate
    open func willTerminate() {}
    
    // set module state to enabled
    public func enable() {
        self.enabled = true
        self.store?.pointee.set(key: "\(self.config.name)_state", value: true)
        self.readers.forEach{ $0.start() }
        self.menuBarItem.isVisible = true
        if self.menuBarItem.length < 0 {
            self.load()
        }
        os_log(.debug, log: log, "Module enabled")
    }
    
    // set module state to disabled
    public func disable() {
        self.enabled = false
        self.store?.pointee.set(key: "\(self.config.name)_state", value: false)
        self.readers.forEach{ $0.pause() }
        self.menuBarItem.isVisible = false
        self.popup.setIsVisible(false)
        os_log(.debug, log: log, "Module disabled")
    }
    
    // toggle module state
    private func toggleEnabled() {
        if self.enabled {
            self.disable()
        } else {
            self.enable()
        }
    }
    
    // add reader to module. If module is enabled will fire a read function and start a reader
    public func addReader(_ reader: Reader_p) {
        if self.enabled {
            reader.start()
        }
        self.readers.append(reader)
        
        os_log(.debug, log: log, "Successfully add reader %s", "\(reader.self)")
    }
    
    // handler for reader, calls when main reader is ready, and return first value
    public func readyHandler() {
        os_log(.debug, log: log, "Reader report readiness")
        self.ready = true
        if !self.widgetLoaded {
            self.load()
        }
    }
    
    // change menu item width
    public func widgetWidthHandler(_ width: CGFloat) {
        os_log(.debug, log: log, "Widget %s adjust width to %.2f", "\(type(of: self.widget!))", width)
        self.menuBarItem.length = width
    }
    
    // determine if module is available (can be overrided in module)
    open func isAvailable() -> Bool { return true }
    
    // load and setup widget
    private func setWidget() {
        self.widget = LoadWidget(self.activeWidget, preview: false, title: self.config.name, config: self.config.widgetsConfig, store: self.store)
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
        
        if self.ready {
            self.menuBarItem.length = self.widget!.frame.width
            self.menuBarItem.button?.subviews.forEach{ $0.removeFromSuperview() }
            self.menuBarItem.button?.addSubview(self.widget!)
        }
        
        self.settings?.setActiveWidget(self.widget)
    }
    
    @objc private func togglePopup(_ sender: Any?) {
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }
        
        if self.popup.occlusionState.rawValue == 8192 {
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            let buttonOrigin = self.menuBarItem.button?.window?.frame.origin
            let buttonCenter = (self.menuBarItem.button?.window?.frame.width)! / 2
            let windowCenter = self.popup.frame.width / 2
            
            self.popup.contentView?.invalidateIntrinsicContentSize()
            var x = buttonOrigin!.x - windowCenter + buttonCenter
            let y = buttonOrigin!.y - self.popup.contentView!.intrinsicContentSize.height - 3
            
            if let screen = NSScreen.main {
                let width = screen.frame.size.width
                
                if x + self.popup.frame.width > width {
                    x = width - self.popup.frame.width
                }
            }
            if buttonOrigin!.x - self.popup.frame.width < 0 {
                x = 0
            }
            
            self.popup.setFrameOrigin(NSPoint(x: x, y: y))
            self.popup.setIsVisible(true)
        }
    }
    
    @objc private func listenForWidgetSwitch(_ notification: Notification) {
        if let moduleName = notification.userInfo?["module"] as? String {
            if let widgetName = notification.userInfo?["widget"] as? String {
                if moduleName == self.config.name {
                    if let widgetType = widget_t.allCases.first(where: { $0.rawValue == widgetName }) {
                        self.activeWidget = widgetType
                        self.store?.pointee.set(key: "\(self.config.name)_widget", value: widgetType.rawValue)
                        self.setWidget()
                        os_log(.debug, log: log, "Widget is changed to: %s", "\(widgetName)")
                    }
                }
            }
        }
    }
    
    @objc private func listenForMouseDownInSettings(_ notification: Notification) {
        if self.popup.isVisible {
            self.popup.setIsVisible(false)
        }
    }
}
