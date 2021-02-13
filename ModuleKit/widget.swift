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
    
    public func new(module: String, config: NSDictionary?, store: UnsafePointer<Store>?) -> Widget? {
        var widget: Widget? = nil
        let widgetConfig: NSDictionary? = config?[self.rawValue] as? NSDictionary
        
        switch self {
        case .mini:
            widget = Widget(self, module: module,
                preview: Mini(title: module, config: widgetConfig, store: store, preview: true),
                item: Mini(title: module, config: widgetConfig, store: store)
            )
            break
        case .lineChart:
            widget = Widget(self, module: module,
                preview: LineChart(title: module, config: widgetConfig, store: store, preview: true),
                item: LineChart(title: module, config: widgetConfig, store: store)
            )
            break
        case .barChart:
            widget = Widget(self, module: module,
                preview: BarChart(title: module, config: widgetConfig, store: store, preview: true),
                item: BarChart(title: module, config: widgetConfig, store: store)
            )
            break
        case .pieChart:
            widget = Widget(self, module: module,
                preview: PieChart(title: module, config: widgetConfig, store: store, preview: true),
                item: PieChart(title: module, config: widgetConfig, store: store)
            )
            break
        case .networkChart:
            widget = Widget(self, module: module,
                preview: NetworkChart(title: module, config: widgetConfig, store: store, preview: true),
                item: NetworkChart(title: module, config: widgetConfig, store: store)
            )
            break
        case .speed:
            widget = Widget(self, module: module,
                preview: SpeedWidget(title: module, config: widgetConfig, store: store, preview: true),
                item: SpeedWidget(title: module, config: widgetConfig, store: store)
            )
            break
        case .battery:
            widget = Widget(self, module: module,
                preview: BatterykWidget(title: module, config: widgetConfig, store: store, preview: true),
                item: BatterykWidget(title: module, config: widgetConfig, store: store)
            )
            break
        case .sensors:
            widget = Widget(self, module: module,
                preview: SensorsWidget(title: module, config: widgetConfig, store: store, preview: true),
                item: SensorsWidget(title: module, config: widgetConfig, store: store)
            )
            break
        case .memory:
            widget = Widget(self, module: module,
                preview: MemoryWidget(title: module, config: widgetConfig, store: store, preview: true),
                item: MemoryWidget(title: module, config: widgetConfig, store: store)
            )
            break
        default: break
        }
        
        return widget
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
    
    private var widthHandlerRetry: Int8 = 0
    
    public init(_ type: widget_t, title: String, frame: NSRect) {
        self.type = type
        self.title = title
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setWidth(_ width: CGFloat) {
        if self.frame.width == width || self.widthHandlerRetry >= 3 {
            return
        }
        
        if self.widthHandler == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + .microseconds(10)) {
                self.setWidth(width)
                self.widthHandlerRetry += 1
            }
            return
        }
        
        DispatchQueue.main.async {
            self.setFrameSize(NSSize(width: width, height: self.frame.size.height))
            self.invalidateIntrinsicContentSize()
            self.display()
        }
        
        self.widthHandler?(width)
    }
    
    // MARK: - stubs
    
    open func settings(width: CGFloat) -> NSView { return NSView() }
    open func setValues(_ values: [value_t]) {}
}

public class Widget {
    public let type: widget_t
    public let module: String
    public let preview: widget_p
    public let item: widget_p
    
    public var isActive: Bool {
        get {
            let arr = Store.shared.string(key: "\(self.module)_widget", defaultValue: "").split(separator: ",")
            return arr.contains{ $0 == self.type.rawValue }
        }
        set {
            var arr = Store.shared.string(key: "\(self.module)_widget", defaultValue: "").split(separator: ",").map{ String($0) }
            
            if newValue {
                arr.append(self.type.rawValue)
            } else {
                arr.removeAll{ $0 == self.type.rawValue }
            }
            
            Store.shared.set(key: "\(self.module)_widget", value: arr.joined(separator: ","))
        }
    }
    
    private var menuBarItem: NSStatusItem? = nil
    private let log: OSLog
    
    public init(_ type: widget_t, module: String, preview: widget_p, item: widget_p) {
        self.type = type
        self.module = module
        self.preview = preview
        self.item = item
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: self.module)
        
        self.item.widthHandler = { [weak self] value in
            if let s = self {
                s.menuBarItem?.length = value
                os_log(.debug, log: s.log, "Widget %s change width to %.2f", "\(s.type)", value)
            }
        }
    }
    
    // show item in the menu bar
    public func enable() {
        guard self.isActive else {
            return
        }
        
        let item = NSStatusBar.system.statusItem(withLength: self.item.frame.width)
        item.autosaveName = "\(self.module)_\(self.type.name())"
        item.isVisible = true
        item.button?.target = self
        item.button?.action = #selector(self.togglePopup)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        item.button?.addSubview(self.item)
        
        self.menuBarItem = item
        
        os_log(.debug, log: log, "Widget %s enabled", self.type.rawValue)
    }
    
    // remove item from the menu bar
    public func disable() {
        if let item = self.menuBarItem {
            item.length = 0
            item.isVisible = false
            
            os_log(.debug, log: log, "Widget %s disabled", self.type.rawValue)
        }
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
        if let window = self.menuBarItem?.button?.window {
            NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
                "module": self.module,
                "origin": window.frame.origin,
                "center": window.frame.width/2,
            ])
        }
    }
}
