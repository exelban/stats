//
//  widget.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

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
    case label = "label"
    
    public func new(module: String, config: NSDictionary, defaultWidget: widget_t) -> Widget? {
        var preview: widget_p? = nil
        var item: widget_p? = nil
        guard let widgetConfig: NSDictionary = config[self.rawValue] as? NSDictionary else {
            return nil
        }
        
        switch self {
        case .mini:
            preview = Mini(title: module, config: widgetConfig, preview: true)
            item = Mini(title: module, config: widgetConfig, preview: false)
        case .lineChart:
            preview = LineChart(title: module, config: widgetConfig, preview: true)
            item = LineChart(title: module, config: widgetConfig, preview: false)
        case .barChart:
            preview = BarChart(title: module, config: widgetConfig, preview: true)
            item = BarChart(title: module, config: widgetConfig, preview: false)
        case .pieChart:
            preview = PieChart(title: module, config: widgetConfig, preview: true)
            item = PieChart(title: module, config: widgetConfig, preview: false)
        case .networkChart:
            preview = NetworkChart(title: module, config: widgetConfig, preview: true)
            item = NetworkChart(title: module, config: widgetConfig, preview: false)
        case .speed:
            preview = SpeedWidget(title: module, config: widgetConfig, preview: true)
            item = SpeedWidget(title: module, config: widgetConfig, preview: false)
        case .battery:
            preview = BatterykWidget(title: module, config: widgetConfig, preview: true)
            item = BatterykWidget(title: module, config: widgetConfig, preview: false)
        case .sensors:
            preview = SensorsWidget(title: module, config: widgetConfig, preview: true)
            item = SensorsWidget(title: module, config: widgetConfig, preview: false)
        case .memory:
            preview = MemoryWidget(title: module, config: widgetConfig, preview: true)
            item = MemoryWidget(title: module, config: widgetConfig, preview: false)
        case .label:
            preview = Label(title: module, config: widgetConfig, preview: true)
            item = Label(title: module, config: widgetConfig, preview: false)
        default: break
        }
        
        if let preview = preview, let item = item {
            return Widget(self, defaultWidget: defaultWidget, module: module, preview: preview, item: item)
        }
        
        return nil
    }
    
    public func name() -> String {
        switch self {
        case .mini: return localizedString("Mini widget")
        case .lineChart: return localizedString("Line chart widget")
        case .barChart: return localizedString("Bar chart widget")
        case .pieChart: return localizedString("Pie chart widget")
        case .networkChart: return localizedString("Network chart widget")
        case .speed: return localizedString("Speed widget")
        case .battery: return localizedString("Battery widget")
        case .sensors: return localizedString("Text widget")
        case .memory: return localizedString("Memory widget")
        case .label: return localizedString("Label widget")
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
    private var menuBarItem: NSStatusItem? = nil
    public var log: NextLog {
        return NextLog.shared.copy(category: self.module)
    }
    
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
        
        self.item.widthHandler = { [weak self] value in
            if let s = self, let item = s.menuBarItem, item.length != value {
                item.length = value
                if let this = self {
                    debug("widget \(s.type) change width to \(Double(value).rounded(toPlaces: 2))", log: this.log)
                }
            }
        }
    }
    
    // show item in the menu bar
    public func enable() {
        guard self.isActive else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.menuBarItem = NSStatusBar.system.statusItem(withLength: self.item.frame.width)
            self.menuBarItem?.autosaveName = "\(self.module)_\(self.type.name())"
            self.menuBarItem?.button?.addSubview(self.item)
            
            if let item = self.menuBarItem, !item.isVisible {
                self.menuBarItem?.isVisible = true
            }
            
            self.menuBarItem?.button?.target = self
            self.menuBarItem?.button?.action = #selector(self.togglePopup)
            self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        })
        
        debug("widget \(self.type.rawValue) enabled", log: self.log)
    }
    
    // remove item from the menu bar
    public func disable() {
        if let item = self.menuBarItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        self.menuBarItem = nil
        debug("widget \(self.type.rawValue) disabled", log: self.log)
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
        if let item = self.menuBarItem, let window = item.button?.window {
            NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
                "module": self.module,
                "origin": window.frame.origin,
                "center": window.frame.width/2
            ])
        }
    }
}
