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
    
    func mount()
    func unmount()
    
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
            var list: [String : Int] = [:]
            self.widgetsConfig = widgetsDict
            
            for widgetName in widgetsDict.allKeys {
                if let widget = widget_t(rawValue: widgetName as! String) {
                    let widgetDict = widgetsDict[widgetName as! String] as! NSDictionary
                    if widgetDict["Default"] as! Bool {
                        self.defaultWidget = widget
                    }
                    var order = 0
                    if let o = widgetDict["Order"] as? Int {
                        order = o
                    }
                    
                    list[widgetName as! String] = order
                }
            }
            
            self.availableWidgets = list.sorted(by: { $0.1 < $1.1 }).map{ (widget_t(rawValue: $0.key) ?? .unknown) }
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
    private var popup: PopupWindow? = nil
    private var popupView: Popup_p? = nil
    
    private let log: OSLog
    private var store: UnsafePointer<Store>
    private var readers: [Reader_p] = []
    private var menuBarItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var activeWidget: widget_t {
        get {
            let widgetStr = self.store.pointee.string(key: "\(self.config.name)_widget", defaultValue: self.config.defaultWidget.rawValue)
            return widget_t.allCases.first{ $0.rawValue == widgetStr } ?? widget_t.unknown
        }
        set {}
    }
    private var ready: Bool = false
    private var widgetLoaded: Bool = false
    
    public init(store: UnsafePointer<Store>, popup: Popup_p?, settings: Settings_v?) {
        self.config = module_c(in: Bundle(for: type(of: self)).path(forResource: "config", ofType: "plist")!)
        
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: self.config.name)
        self.store = store
        self.settingsView = settings
        self.popupView = popup
        self.available = self.isAvailable()
        self.enabled = self.store.pointee.bool(key: "\(self.config.name)_state", defaultValue: self.config.defaultState)
        self.menuBarItem.autosaveName = self.config.name
        self.menuBarItem.isVisible = self.enabled
        
        if !self.available {
            os_log(.debug, log: log, "Module is not available")
            
            self.menuBarItem.length = 0
            self.menuBarItem.isVisible = false
            if self.enabled {
                self.enabled = false
                self.store.pointee.set(key: "\(self.config.name)_state", value: false)
            }
            
            return
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForWidgetSwitch), name: .switchWidget, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForMouseDownInSettings), name: .clickInSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleToggle), name: .toggleModule, object: nil)
        
        if self.config.widgetsConfig.count != 0 {
            self.initWidget()
        } else {
            os_log(.debug, log: log, "Module started without widget")
        }
        
        self.settings = Settings(config: &self.config, enabled: self.enabled, activeWidget: self.widget, moduleSettings: self.settingsView)
        self.settings?.toggleCallback = { [weak self] in
            self?.toggleEnabled()
        }
        
        self.popup = PopupWindow(title: self.config.name, view: self.popupView, visibilityCallback: self.visibilityCallback)
        
        self.menuBarItem.button?.target = self
        self.menuBarItem.button?.action = #selector(self.togglePopup)
        self.menuBarItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // load function which call when app start
    public func mount() {
        guard self.enabled else {
            return
        }
        
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name, store: self.store)
            reader.start()
        }
    }
    
    // disable module
    public func unmount() {
        self.enabled = false
        self.available = false
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
        guard self.available else { return }
        
        self.enabled = true
        self.store.pointee.set(key: "\(self.config.name)_state", value: true)
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name, store: self.store)
            reader.start()
        }
        self.menuBarItem.isVisible = true
        if self.widget != nil {
            self.loadWidget()
        } else {
            self.initWidget()
        }
        os_log(.debug, log: log, "Module enabled")
    }
    
    // set module state to disabled
    public func disable() {
        guard self.available else { return }
        
        self.enabled = false
        self.store.pointee.set(key: "\(self.config.name)_state", value: false)
        self.readers.forEach{ $0.pause() }
        self.menuBarItem.isVisible = false
        self.popup?.setIsVisible(false)
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
        self.readers.append(reader)
        os_log(.debug, log: log, "Reader %s was added", "\(reader.self)")
    }
    
    // handler for reader, calls when main reader is ready, and return first value
    public func readyHandler() {
        os_log(.debug, log: log, "Reader report readiness")
        self.ready = true
        
        if !self.widgetLoaded {
            self.loadWidget()
        }
    }
    
    // change menu item width
    public func widgetWidthHandler(_ width: CGFloat) {
        os_log(.debug, log: log, "Widget %s change width to %.2f", "\(type(of: self.widget!))", width)
        self.menuBarItem.length = width
    }
    
    // replace a popup view
    public func replacePopup(_ view: Popup_p) {
        self.popup?.setIsVisible(false)
        self.popupView = view
        self.popup = PopupWindow(title: self.config.name, view: self.popupView, visibilityCallback: self.visibilityCallback)
    }
    
    // determine if module is available (can be overrided in module)
    open func isAvailable() -> Bool { return true }
    
    // setup menu ber item
    private func loadWidget() {
        guard self.available && self.enabled && self.ready && self.widget != nil else { return }
        
        DispatchQueue.main.async {
            self.menuBarItem.length = self.widget!.frame.width
            self.menuBarItem.button?.subviews.forEach{ $0.removeFromSuperview() }
            self.menuBarItem.button?.addSubview(self.widget!)
            self.widgetLoaded = true
            self.widgetDidSet(self.widget?.type ?? .unknown)
        }
    }
    
    // load the widget and set up. Calls when module init or widget change
    private func initWidget() {
        guard self.available else { return }
        
        self.widget = self.activeWidget.new(module: self.config.name, config: self.config.widgetsConfig, store: self.store)
        if self.widget == nil {
            self.enabled = false
            os_log(.error, log: log, "widget with type %s not found", "\(self.activeWidget)")
            return
        }
        os_log(.debug, log: log, "Successfully initialize widget: %s", "\(String(describing: self.widget!))")
        
        self.widget?.widthHandler = { [weak self] value in
            self?.widgetWidthHandler(value)
        }
        
        DispatchQueue.global(qos: .background).async {
            self.readers.forEach{ $0.read() }
        }
        
        if let mainReader = self.readers.first(where: { !$0.optional }) {
            self.widget?.setValues(mainReader.getHistory())
        }
        
        if self.ready && self.enabled {
            self.menuBarItem.length = self.widget!.frame.width
            self.menuBarItem.button?.subviews.forEach{ $0.removeFromSuperview() }
            self.menuBarItem.button?.addSubview(self.widget!)
            self.widgetLoaded = true
        }
        
        self.settings?.setActiveWidget(self.widget)
    }
    
    // call after widget set up
    open func widgetDidSet(_ type: widget_t) {}
    
    // call when popup appear/disappear
    private func visibilityCallback(_ state: Bool) {
        self.readers.filter{ $0.popup }.forEach { (reader: Reader_p) in
            if state {
                reader.unlock()
                reader.start()
            } else {
                reader.pause()
                reader.lock()
            }
        }
    }
    
    @objc private func togglePopup(_ sender: Any) {
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }
        
        guard let popup = self.popup else {
            return
        }
        
        if popup.occlusionState.rawValue == 8192 {
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            popup.contentView?.invalidateIntrinsicContentSize()
            
            let buttonOrigin = self.menuBarItem.button?.window?.frame.origin
            let buttonCenter = (self.menuBarItem.button?.window?.frame.width)! / 2
            
            let windowCenter = popup.contentView!.intrinsicContentSize.width / 2
            var x = buttonOrigin!.x - windowCenter + buttonCenter
            let y = buttonOrigin!.y - popup.contentView!.intrinsicContentSize.height - 3
            
            let maxWidth = NSScreen.screens.map{ $0.frame.width }.reduce(0, +)
            if x + popup.contentView!.intrinsicContentSize.width > maxWidth {
                x = maxWidth - popup.contentView!.intrinsicContentSize.width - 3
            }
            
            popup.setFrameOrigin(NSPoint(x: x, y: y))
            popup.setIsVisible(true)
        } else {
            popup.locked = false
            popup.setIsVisible(false)
        }
    }
    
    @objc private func listenForModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String {
            if name == self.config.name {
                if let state = notification.userInfo?["state"] as? Bool {
                    if state && !self.enabled {
                        self.enable()
                    } else if !state && self.enabled {
                        self.disable()
                    }
                }
            }
        }
    }
    
    @objc private func listenForWidgetSwitch(_ notification: Notification) {
        if let moduleName = notification.userInfo?["module"] as? String {
            if let widgetName = notification.userInfo?["widget"] as? String {
                if moduleName == self.config.name {
                    if let widgetType = widget_t.allCases.first(where: { $0.rawValue == widgetName }) {
                        self.activeWidget = widgetType
                        self.store.pointee.set(key: "\(self.config.name)_widget", value: widgetType.rawValue)
                        self.initWidget()
                        self.widgetDidSet(widgetType)
                        os_log(.debug, log: log, "Widget is changed to: %s", "\(widgetName)")
                    }
                }
            }
        }
    }
    
    @objc private func listenForMouseDownInSettings(_ notification: Notification) {
        if let popup = self.popup, popup.isVisible {
            self.popup?.setIsVisible(false)
        }
    }
}
