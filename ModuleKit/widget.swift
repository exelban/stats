//
//  widget.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import os.log
import StatsKit

public enum widget_t: String {
    case unknown = ""
    case mini = "mini"
    case lineChart = "line_chart"
    case barChart = "bar_chart"
    case pieChart = "pie_chart"
    case networkChart = "network_chart"
    case speed = "speed"
    case battery = "battery"
    case sensors = "sensors"
    case memory = "memory"
    
    public func new(store: UnsafePointer<Store>, module: String, config: NSDictionary, defaultWidget: widget_t) -> Widget? {
        var preview: widget_p? = nil
        var item: widget_p? = nil
        guard let widgetConfig: NSDictionary = config[self.rawValue] as? NSDictionary else {
            return nil
        }
        
        switch self {
        case .mini:
            preview = Mini(title: module, config: widgetConfig, store: store, preview: true)
            item = Mini(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .lineChart:
            preview = LineChart(title: module, config: widgetConfig, store: store, preview: true)
            item = LineChart(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .barChart:
            preview = BarChart(title: module, config: widgetConfig, store: store, preview: true)
            item = BarChart(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .pieChart:
            preview = PieChart(title: module, config: widgetConfig, store: store, preview: true)
            item = PieChart(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .networkChart:
            preview = NetworkChart(title: module, config: widgetConfig, store: store, preview: true)
            item = NetworkChart(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .speed:
            preview = SpeedWidget(title: module, config: widgetConfig, store: store, preview: true)
            item = SpeedWidget(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .battery:
            preview = BatterykWidget(title: module, config: widgetConfig, store: store, preview: true)
            item = BatterykWidget(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .sensors:
            preview = SensorsWidget(title: module, config: widgetConfig, store: store, preview: true)
            item = SensorsWidget(title: module, config: widgetConfig, store: store, preview: false)
            break
        case .memory:
            preview = MemoryWidget(title: module, config: widgetConfig, store: store, preview: true)
            item = MemoryWidget(title: module, config: widgetConfig, store: store, preview: false)
            break
        default: break
        }
        
        if let preview = preview, let item = item {
            return Widget(self, defaultWidget: defaultWidget, module: module, preview: preview, item: item)
        }
        
        return nil
    }
    
    public func name() -> String {
        switch self {
            case .mini: return LocalizedString("Mini widget")
            case .lineChart: return LocalizedString("Line chart widget")
            case .barChart: return LocalizedString("Bar chart widget")
            case .pieChart: return LocalizedString("Pie chart widget")
            case .networkChart: return LocalizedString("Network chart widget")
            case .speed: return LocalizedString("Speed widget")
            case .battery: return LocalizedString("Battery widget")
            case .sensors: return LocalizedString("Text widget")
            case .memory: return LocalizedString("Memory widget")
            default: return ""
        }
    }
}
extension widget_t: CaseIterable {}

public protocol widget_p: NSView {
    var type: widget_t { get }
    var title: String { get }
    
    var widthHandler: ((CGFloat) -> Void)? { get set }
    
    func setValues(_ values: [value_t])
    func settings(width: CGFloat) -> NSView
}

open class WidgetWrapper: NSView, widget_p {
    public var type: widget_t
    public var title: String
    
    public var widthHandler: ((CGFloat) -> Void)? = nil
    
    public init(_ type: widget_t, title: String, frame: NSRect) {
        self.type = type
        self.title = title
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setWidth(_ width: CGFloat) {
        if self.frame.width == width {
            return
        }
        
        DispatchQueue.main.async {
            self.setFrameSize(NSSize(width: width, height: self.frame.size.height))
        }
        
        self.widthHandler?(width)
    }
    
    // MARK: - stubs
    
    open func settings(width: CGFloat) -> NSView { return NSView() }
    open func setValues(_ values: [value_t]) {}
}

public class Widget {
    public let type: widget_t
    public let defaultWidget: widget_t
    public let module: String
    public let preview: widget_p
    public let item: widget_p
    
    public var isActive: Bool {
        get {
            return self.list.contains{ $0 == self.type }
        }
        set {
            if newValue {
                self.list.append(self.type)
            } else {
                self.list.removeAll{ $0 == self.type }
            }
        }
    }
    
    private var config: NSDictionary = NSDictionary()
    private var menuBarItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: 0)
    private var removed: Bool = false
    private let log: OSLog
    
    private var list: [widget_t] {
        get {
            let string = Store.shared.string(key: "\(self.module)_widget", defaultValue: self.defaultWidget.rawValue)
            return string.split(separator: ",").map{ (widget_t(rawValue: String($0)) ?? .unknown)}
        }
        set {
            Store.shared.set(key: "\(self.module)_widget", value: newValue.map{ $0.rawValue }.joined(separator: ","))
        }
    }
    
    public init(_ type: widget_t, defaultWidget: widget_t, module: String, preview: widget_p, item: widget_p) {
        self.type = type
        self.module = module
        self.preview = preview
        self.item = item
        self.defaultWidget = defaultWidget
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: self.module)
        
        self.item.widthHandler = { [weak self] value in
            if let s = self, s.menuBarItem.length != value {
                s.menuBarItem.length = value
                os_log(.debug, log: s.log, "widget %s change width to %.2f", "\(s.type)", value)
            }
        }
    }
    
    // show item in the menu bar
    public func enable() {
        guard self.isActive else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            if self.removed {
                self.menuBarItem = NSStatusBar.system.statusItem(withLength: self.item.frame.width)
                self.removed = false
            } else {
                self.menuBarItem.length = self.item.frame.width
            }
            self.menuBarItem.autosaveName = "\(self.module)_\(self.type.name())"
            self.menuBarItem.button?.addSubview(self.item)
            
            if !self.menuBarItem.isVisible {
                self.menuBarItem.isVisible = true
            }
            
            self.menuBarItem.button?.target = self
            self.menuBarItem.button?.action = #selector(self.togglePopup)
            self.menuBarItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        })
        
        os_log(.debug, log: log, "widget %s enabled", self.type.rawValue)
    }
    
    // remove item from the menu bar
    public func disable() {
        NSStatusBar.system.removeStatusItem(self.menuBarItem)
        self.removed = true
        os_log(.debug, log: log, "widget %s disabled", self.type.rawValue)
    }
    
    // toggle the widget
    public func toggle() {
        self.isActive = !self.isActive
        
        if !self.isActive {
            self.disable()
        } else {
            self.enable()
        }
        
        NotificationCenter.default.post(name: .toggleWidget, object: nil, userInfo: ["module": self.module])
    }
    
    @objc private func togglePopup(_ sender: Any) {
        if let window = self.menuBarItem.button?.window {
            NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
                "module": self.module,
                "origin": window.frame.origin,
                "center": window.frame.width/2,
            ])
        }
    }
}
