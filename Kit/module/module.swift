//
//  module.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Module_p {
    var available: Bool { get }
    var enabled: Bool { get }
    
    var settings: Settings_p? { get }
    
    func mount()
    func unmount()
    
    func terminate()
}

public struct module_c {
    public var name: String = ""
    public var icon: NSImage?
    
    public var defaultState: Bool = false
    internal var defaultWidget: widget_t = .unknown
    internal var availableWidgets: [widget_t] = []
    
    internal var widgetsConfig: NSDictionary = NSDictionary()
    internal var settingsConfig: NSDictionary = NSDictionary()
    
    init(in path: String) {
        let dict: NSDictionary = NSDictionary(contentsOfFile: path)!
        
        if let name = dict["Name"] as? String {
            self.name = name
        }
        if let state = dict["State"] as? Bool {
            self.defaultState = state
        }
        if let symbol = dict["Symbol"] as? String, #available(macOS 11.0, *) {
            self.icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        if self.icon == nil, #available(macOS 11.0, *), let symbol = dict["AlternativeSymbol"] as? String {
            self.icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        
        if let widgetsDict = dict["Widgets"] as? NSDictionary {
            var list: [String: Int] = [:]
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
        
        if let settingsDict = dict["Settings"] as? NSDictionary {
            self.settingsConfig = settingsDict
        }
    }
}

open class Module: Module_p {
    public var config: module_c
    
    public var available: Bool = false
    public var enabled: Bool = false
    
    public var menuBar: MenuBar
    public var settings: Settings_p? = nil
    public let portal: Portal_p?
    
    public var name: String {
        config.name
    }
    public var combinedPosition: Int {
        get {
            Store.shared.int(key: "\(self.name)_position", defaultValue: 0)
        }
        set {
            Store.shared.set(key: "\(self.name)_position", value: newValue)
        }
    }
    
    private var settingsView: Settings_v? = nil
    private var popup: PopupWindow? = nil
    private var popupView: Popup_p? = nil
    private var notificationsView: NotificationsWrapper? = nil
    
    private let log: NextLog
    private var readers: [Reader_p] = []
    
    private var pauseState: Bool {
        get {
            Store.shared.bool(key: "pause", defaultValue: false)
        }
        set {
            Store.shared.set(key: "pause", value: newValue)
        }
    }
    
    public init(popup: Popup_p? = nil, settings: Settings_v? = nil, portal: Portal_p? = nil, notifications: NotificationsWrapper? = nil) {
        self.portal = portal
        self.config = module_c(in: Bundle(for: type(of: self)).path(forResource: "config", ofType: "plist")!)
        
        self.log = NextLog.shared.copy(category: self.config.name)
        self.settingsView = settings
        self.popupView = popup
        self.notificationsView = notifications
        self.menuBar = MenuBar(moduleName: self.config.name)
        self.available = self.isAvailable()
        self.enabled = Store.shared.bool(key: "\(self.config.name)_state", defaultValue: self.config.defaultState)
        
        if !self.available {
            debug("Module is not available", log: self.log)
            
            if self.enabled {
                self.enabled = false
                Store.shared.set(key: "\(self.config.name)_state", value: false)
            }
            
            return
        } else if self.pauseState {
            self.disable()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForMouseDownInSettings), name: .clickInSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleToggle), name: .toggleModule, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForPopupToggle), name: .togglePopup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForToggleWidget), name: .toggleWidget, object: nil)
        
        // swiftlint:disable empty_count
        if self.config.widgetsConfig.count != 0 {
            // swiftlint:enable empty_count
            self.initWidgets()
        } else {
            debug("Module started without widget", log: self.log)
        }
        
        self.settings = Settings(
            config: &self.config,
            widgets: &self.menuBar.widgets,
            enabled: self.enabled,
            moduleSettings: self.settingsView,
            popupSettings: self.popupView,
            notificationsSettings: self.notificationsView
        )
        
        self.popup = PopupWindow(title: self.config.name, view: self.popupView, visibilityCallback: self.visibilityCallback)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // load function which call when app start
    public func mount() {
        guard self.enabled else { return }
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name)
            reader.start()
        }
        self.menuBar.enable()
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
        self.menuBar.disable()
        debug("Module terminated", log: self.log)
    }
    
    // function to call before module terminate
    open func willTerminate() {}
    
    // set module state to enabled
    public func enable() {
        guard self.available else { return }
        
        self.enabled = true
        Store.shared.set(key: "\(self.config.name)_state", value: true)
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name)
            reader.start()
        }
        self.menuBar.enable()
        self.settings?.setState(self.enabled)
        debug("Module enabled", log: self.log)
    }
    
    // set module state to disabled
    public func disable() {
        guard self.available else { return }
        
        self.enabled = false
        if !self.pauseState { // omit saving the disable state when toggle by pause, need for resume state restoration
            Store.shared.set(key: "\(self.config.name)_state", value: false)
        }
        self.readers.forEach{ $0.stop() }
        self.menuBar.disable()
        self.settings?.setState(self.enabled)
        self.popup?.setIsVisible(false)
        debug("Module disabled", log: self.log)
    }
    
    public func setReaders(_ list: [Reader_p?]) {
        self.readers = list.filter({ $0 != nil }).map({ $0! as Reader_p })
    }
    
    // replace a popup view
    public func replacePopup(_ view: Popup_p) {
        self.popup?.setIsVisible(false)
        self.popupView = view
        self.popup = PopupWindow(title: self.config.name, view: self.popupView, visibilityCallback: self.visibilityCallback)
    }
    
    // determine if module is available (can be overrided in module)
    open func isAvailable() -> Bool { return true }
    
    // load the widget and set up. Calls when module init
    private func initWidgets() {
        guard self.available else { return }
        
        self.config.availableWidgets.forEach { (widgetType: widget_t) in
            if let widget = widgetType.new(
                module: self.config.name,
                config: self.config.widgetsConfig,
                defaultWidget: self.config.defaultWidget
            ) {
                self.menuBar.append(widget)
            }
        }
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
    
    @objc private func listenForPopupToggle(_ notification: Notification) {
        guard let popup = self.popup,
              let name = notification.userInfo?["module"] as? String,
              let buttonOrigin = notification.userInfo?["origin"] as? CGPoint,
              let buttonCenter = notification.userInfo?["center"] as? CGFloat,
              self.config.name == name else {
            return
        }
        
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }
        
        var reopen: Bool = false
        if let widget = notification.userInfo?["widget"] as? widget_t {
            reopen = popup.openedBy != nil && popup.openedBy != widget
            popup.openedBy = widget
        }
        
        if popup.occlusionState.rawValue == 8192 || reopen {
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            popup.contentView?.invalidateIntrinsicContentSize()
            
            let windowCenter = popup.contentView!.intrinsicContentSize.width / 2
            var x = buttonOrigin.x - windowCenter + buttonCenter
            let y = buttonOrigin.y - popup.contentView!.intrinsicContentSize.height - 3
            
            let maxWidth = NSScreen.screens.map{ $0.frame.width }.reduce(0, +)
            if x + popup.contentView!.intrinsicContentSize.width > maxWidth {
                x = maxWidth - popup.contentView!.intrinsicContentSize.width - 3
            }
            
            popup.setFrameOrigin(NSPoint(x: x, y: y))
            popup.setIsVisible(true)
        } else {
            popup.locked = false
            popup.openedBy = nil
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
                } else {
                    if self.enabled {
                        self.disable()
                    } else {
                        self.enable()
                    }
                }
            }
            
            if self.pauseState == true {
                self.pauseState = false
                NotificationCenter.default.post(name: .pause, object: nil, userInfo: ["state": false])
            }
        }
    }
    
    @objc private func listenForMouseDownInSettings(_ notification: Notification) {
        if let popup = self.popup, popup.isVisible && !popup.locked {
            self.popup?.setIsVisible(false)
        }
    }
    
    @objc private func listenForToggleWidget(_ notification: Notification) {
        guard let name = notification.userInfo?["module"] as? String, name == self.config.name else {
            return
        }
        let isEmpty = self.menuBar.widgets.filter({ $0.isActive }).isEmpty
        var state = self.enabled
        
        if isEmpty && self.enabled {
            state = false
        } else if !isEmpty && !self.enabled {
            state = true
        }
        
        NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.config.name, "state": state])
    }
}
