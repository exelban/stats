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
    case batteryDetails = "battery_details"
    case stack = "sensors" // to replace
    case memory = "memory"
    case label = "label"
    case tachometer = "tachometer"
    case state = "state"
    case text = "text"
    
    public func new(module: String, config: NSDictionary, defaultWidget: widget_t) -> SWidget? {
        guard let widgetConfig: NSDictionary = config[self.rawValue] as? NSDictionary else { return nil }
        
        var image: NSImage? = nil
        var preview: widget_p? = nil
        var item: widget_p? = nil
        
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
            preview = BatteryWidget(title: module, preview: true)
            item = BatteryWidget(title: module, preview: false)
        case .batteryDetails:
            preview = BatteryDetailsWidget(title: module, preview: true)
            item = BatteryDetailsWidget(title: module, preview: false)
        case .stack:
            preview = StackWidget(title: module, config: widgetConfig, preview: true)
            item = StackWidget(title: module, config: widgetConfig, preview: false)
        case .memory:
            preview = MemoryWidget(title: module, config: widgetConfig, preview: true)
            item = MemoryWidget(title: module, config: widgetConfig, preview: false)
        case .label:
            preview = Label(title: module, config: widgetConfig)
            item = Label(title: module, config: widgetConfig)
        case .tachometer:
            preview = Tachometer(title: module, preview: true)
            item = Tachometer(title: module, preview: false)
        case .state:
            preview = StateWidget(title: module, config: widgetConfig, preview: true)
            item = StateWidget(title: module, config: widgetConfig, preview: false)
        case .text:
            preview = TextWidget(title: module, config: widgetConfig, preview: true)
            item = TextWidget(title: module, config: widgetConfig, preview: false)
        default: break
        }
        
        if let view = preview {
            var width: CGFloat = view.bounds.width
            
            switch preview {
            case is Mini:
                if module == "Battery" {
                    width = view.bounds.width + 3
                }
            case is BarChart:
                if module == "GPU" || module == "RAM" || module == "Disk" || module == "Battery" {
                    width = 11 + (Constants.Widget.margin.x*2)
                } else if module == "Sensors" {
                    width = 22 + (Constants.Widget.margin.x*2)
                } else if module == "CPU" {
                    width = 30 + (Constants.Widget.margin.x*2)
                }
            case is StackWidget:
                if module == "Sensors" {
                    width = 25
                } else if module == "Clock" {
                    width = 114
                }
            case is MemoryWidget:
                width = view.bounds.width + 8 + Constants.Widget.spacing*2
            case is BatteryWidget:
                width = view.bounds.width - 3
            default: width = view.bounds.width
            }
            
            let r = NSRect(
                x: -view.frame.origin.x/2,
                y: 0,
                width: width - view.frame.origin.x,
                height: view.bounds.height
            )
            image = NSImage(data: view.dataWithPDF(inside: r))
        }
        
        if let item = item, let image = image {
            return SWidget(self, defaultWidget: defaultWidget, module: module, item: item, image: image)
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
        case .batteryDetails: return localizedString("Battery details widget")
        case .stack: return localizedString("Stack widget")
        case .memory: return localizedString("Memory widget")
        case .label: return localizedString("Label widget")
        case .tachometer: return localizedString("Tachometer widget")
        case .state: return localizedString("State widget")
        case .text: return localizedString("Text widget")
        default: return ""
        }
    }
}
extension widget_t: CaseIterable {}

public protocol widget_p: NSView {
    var widthHandler: (() -> Void)? { get set }
    var onClick: (() -> Void)? { get set }
    
    func settings() -> NSView
}

open class WidgetWrapper: NSView, widget_p {
    public var type: widget_t
    public var title: String
    public var widthHandler: (() -> Void)? = nil
    public var onClick: (() -> Void)? = nil
    public var shadowSize: CGSize
    internal var queue: DispatchQueue
    
    public init(_ type: widget_t, title: String, frame: NSRect) {
        self.type = type
        self.title = title
        self.shadowSize = frame.size
        self.queue = DispatchQueue(label: "eu.exelban.Stats.WidgetWrapper.\(type.rawValue).\(title)")
        
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setWidth(_ width: CGFloat) {
        var newWidth = width
        if width == 0 || width == 1 {
            newWidth = self.emptyView()
        }
        
        guard self.shadowSize.width != newWidth else { return }
        self.shadowSize.width = newWidth
        
        DispatchQueue.main.async {
            self.setFrameSize(NSSize(width: newWidth, height: self.frame.size.height))
            self.widthHandler?()
        }
    }
    
    public func emptyView() -> CGFloat {
        let size: CGFloat = 15
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let offset = lineWidth / 2
        let width: CGFloat = (Constants.Widget.margin.x*2) + size + (lineWidth*2)
        
        NSColor.textColor.set()
        
        var circle = NSBezierPath()
        circle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin.x+offset, y: 1+offset, width: size, height: size))
        circle.stroke()
        circle.lineWidth = lineWidth
        
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 3, y: 3.5))
        line.line(to: NSPoint(x: 13.5, y: 14))
        line.lineWidth = lineWidth
        line.stroke()
        
        return width
    }
    
    open func settings() -> NSView { return NSView() }
    
    open override func mouseDown(with event: NSEvent) {
        if let f = self.onClick {
            f()
            return
        }
        super.mouseDown(with: event)
    }
}

public class SWidget {
    public let type: widget_t
    public let defaultWidget: widget_t
    public let module: String
    public let image: NSImage
    public var item: widget_p
    
    public var isActive: Bool {
        get {
            self.list.contains{ $0 == self.type }
        }
        set {
            if newValue {
                self.list.append(self.type)
            } else {
                self.list.removeAll{ $0 == self.type }
            }
        }
    }
    
    public var toggleCallback: ((widget_t, Bool) -> Void)? = nil
    public var sizeCallback: (() -> Void)? = nil
    
    public var log: NextLog {
        NextLog.shared.copy(category: self.module)
    }
    public var position: Int {
        get {
            Store.shared.int(key: "\(self.module)_\(self.type)_position", defaultValue: 0)
        }
        set {
            Store.shared.set(key: "\(self.module)_\(self.type)_position", value: newValue)
        }
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
    
    private var menuBarItem: NSStatusItem? = nil
    private var originX: CGFloat
    
    public init(_ type: widget_t, defaultWidget: widget_t, module: String, item: widget_p, image: NSImage) {
        self.type = type
        self.module = module
        self.item = item
        self.defaultWidget = defaultWidget
        self.image = image
        self.originX = item.frame.origin.x
        
        self.item.widthHandler = { [weak self] in
            self?.sizeCallback?()
            if let s = self, let item = s.menuBarItem, let width: CGFloat = self?.item.frame.width, item.length != width {
                item.length = width
            }
        }
        self.item.identifier = NSUserInterfaceItemIdentifier(self.type.rawValue)
    }
    
    // show item in the menu bar
    public func enable() {
        guard self.isActive else { return }
        self.toggleCallback?(self.type, true)
        debug("widget \(self.type.rawValue) enabled", log: self.log)
    }
    
    // remove item from the menu bar
    public func disable() {
        self.toggleCallback?(self.type, false)
        debug("widget \(self.type.rawValue) disabled", log: self.log)
    }
    
    // toggle the widget
    public func toggle(_ state: Bool? = nil) {
        var newState: Bool = !self.isActive
        if let state = state {
            newState = state
        }
        
        if self.isActive == newState {
            return
        }
        
        self.isActive = newState
        
        if !self.isActive {
            self.disable()
        } else {
            self.enable()
        }
        
        NotificationCenter.default.post(name: .toggleWidget, object: nil, userInfo: ["module": self.module])
    }
    
    public func setMenuBarItem(state: Bool) {
        if state {
            let prevTag = "NSStatusItem Preferred Position \(self.module)_\(self.type.name())"
            let prevPosition = Store.shared.int(key: prevTag, defaultValue: -1)
            if prevPosition != -1 {
                Store.shared.set(key: "NSStatusItem Preferred Position \(self.module)_\(self.type.rawValue)", value: prevPosition)
                Store.shared.remove(prevTag)
            }
            
            restoreNSStatusItemPosition(id: "\(self.module)_\(self.type.rawValue)")
            
            DispatchQueue.main.async(execute: {
                self.menuBarItem = NSStatusBar.system.statusItem(withLength: self.item.frame.width)
                self.menuBarItem?.autosaveName = "\(self.module)_\(self.type.rawValue)"
                if self.item.frame.origin.x != self.originX {
                    self.item.setFrameOrigin(NSPoint(x: self.originX, y: self.item.frame.origin.y))
                }
                self.menuBarItem?.button?.addSubview(self.item)
                
                if let item = self.menuBarItem, !item.isVisible {
                    self.menuBarItem?.isVisible = true
                }
                
                self.menuBarItem?.button?.target = self
                self.menuBarItem?.button?.action = #selector(self.togglePopup)
                self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
            })
        } else if let item = self.menuBarItem {
            saveNSStatusItemPosition(id: "\(self.module)_\(self.type.rawValue)")
            NSStatusBar.system.removeStatusItem(item)
            self.menuBarItem = nil
        }
    }
    
    @objc private func togglePopup() {
        if let item = self.menuBarItem, let window = item.button?.window {
            NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
                "module": self.module,
                "widget": self.type,
                "origin": window.frame.origin,
                "center": window.frame.width/2
            ])
        }
    }
}

public class MenuBar {
    public var callback: (() -> Void)? = nil
    public var widgets: [SWidget] = []
    
    private var moduleName: String
    private var menuBarItem: NSStatusItem? = nil
    private var queue: DispatchQueue
    
    private var combinedModules: Bool {
        Store.shared.bool(key: "CombinedModules", defaultValue: false)
    }
    
    public var view: MenuBarView = MenuBarView()
    public var oneView: Bool = false
    public var activeWidgets: [SWidget] {
        self.widgets.filter({ $0.isActive })
    }
    public var sortedWidgets: [widget_t] {
        get {
            var list: [widget_t: Int] = [:]
            self.activeWidgets.forEach { (w: SWidget) in
                list[w.type] = w.position
            }
            return list.sorted { $0.1 < $1.1 }.map{ $0.key }
        }
    }
    
    private var _active: Bool = false
    public var active: Bool {
        get {
            self.queue.sync { self._active }
        }
        set {
            self.queue.sync { self._active = newValue }
        }
    }
    
    init(moduleName: String) {
        self.moduleName = moduleName
        self.queue = DispatchQueue(label: "eu.exelban.Stats.MenuBar.\(moduleName)")
        self.oneView = Store.shared.bool(key: "\(self.moduleName)_oneView", defaultValue: self.oneView)
        self.view.identifier = NSUserInterfaceItemIdentifier(rawValue: moduleName)
        
        if self.combinedModules {
            self.oneView = true
        } else {
            self.setupMenuBarItem(self.oneView)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForOneView), name: .toggleOneView, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(listenForWidgetRearrange), name: .widgetRearrange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .toggleOneView, object: nil)
        NotificationCenter.default.removeObserver(self, name: .widgetRearrange, object: nil)
    }
    
    public func append(_ widget: SWidget) {
        widget.toggleCallback = { [weak self] (type, state) in
            if let s = self, s.oneView {
                if state, let w = s.activeWidgets.first(where: { $0.type == type }) {
                    DispatchQueue.main.async(execute: {
                        s.recalculateWidth()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            s.view.addWidget(w.item)
                            s.view.recalculate(s.sortedWidgets)
                        }
                    })
                } else {
                    DispatchQueue.main.async(execute: {
                        s.view.removeWidget(type: type)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            s.recalculateWidth()
                            s.view.recalculate(s.sortedWidgets)
                        }
                    })
                }
            } else {
                widget.setMenuBarItem(state: state)
            }
        }
        widget.sizeCallback = { [weak self] in
            self?.recalculateWidth()
        }
        self.widgets.append(widget)
    }
    
    public func enable() {
        if self.oneView && !self.combinedModules {
            self.setupMenuBarItem(true)
        }
        self.active = true
        self.widgets.forEach{ $0.enable() }
        self.callback?()
    }
    
    public func disable() {
        self.widgets.forEach{ $0.disable() }
        self.active = false
        if self.oneView {
            self.setupMenuBarItem(false)
        }
        self.callback?()
    }
    
    private func setupMenuBarItem(_ state: Bool) {
        DispatchQueue.main.async(execute: {
            if state && self.active {
                restoreNSStatusItemPosition(id: self.moduleName)
                self.menuBarItem = NSStatusBar.system.statusItem(withLength: 0)
                self.menuBarItem?.autosaveName = self.moduleName
                self.menuBarItem?.isVisible = true
                
                self.menuBarItem?.button?.addSubview(self.view)
                self.menuBarItem?.button?.target = self
                self.menuBarItem?.button?.action = #selector(self.togglePopup)
                self.menuBarItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
                
                self.recalculateWidth()
            } else if let item = self.menuBarItem {
                saveNSStatusItemPosition(id: self.moduleName)
                NSStatusBar.system.removeStatusItem(item)
                self.menuBarItem = nil
            }
        })
    }
    
    private func recalculateWidth() {
        guard self.oneView, self.active else { return }
        
        let w = self.activeWidgets.map({ $0.item.frame.width }).reduce(0, +) +
            (CGFloat(self.activeWidgets.count - 1) * Constants.Widget.spacing) +
            Constants.Widget.spacing * 2
        self.menuBarItem?.length = w
        self.view.setFrameOrigin(NSPoint(x: 0, y: 0))
        self.view.setFrameSize(NSSize(width: w, height: Constants.Widget.height))
        
        self.view.recalculate(self.sortedWidgets)
        self.callback?()
    }
    
    @objc private func togglePopup() {
        if let item = self.menuBarItem, let window = item.button?.window {
            NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
                "module": self.moduleName,
                "origin": window.frame.origin,
                "center": window.frame.width/2
            ])
        }
    }
    
    @objc private func listenForOneView(_ notification: Notification) {
        if notification.userInfo?["module"] as? String == nil {
            self.toggleOneView()
        } else if let name = notification.userInfo?["module"] as? String, name == self.moduleName, self.active {
            self.toggleOneView()
        }
    }
    
    private func toggleOneView() {
        self.activeWidgets.forEach { (w: SWidget) in
            w.disable()
        }
        
        if self.combinedModules {
            self.oneView = true
            self.setupMenuBarItem(false)
        } else if self.active {
            self.oneView = Store.shared.bool(key: "\(self.moduleName)_oneView", defaultValue: self.oneView)
            self.setupMenuBarItem(self.oneView)
        }
        
        self.activeWidgets.forEach { (w: SWidget) in
            w.enable()
        }
    }
    
    @objc private func listenForWidgetRearrange(_ notification: Notification) {
        guard let name = notification.userInfo?["module"] as? String, name == self.moduleName else {
            return
        }
        self.view.recalculate(self.sortedWidgets)
    }
}

public class MenuBarView: NSView {
    init() {
        super.init(frame: NSRect.zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func addWidget(_ view: NSView) {
        self.addSubview(view)
    }
    
    public func removeWidget(type: widget_t) {
        if let view = self.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier(type.rawValue) }) {
            view.removeFromSuperview()
        } else {
            error("\(type) could not be removed from the one view because not found!")
        }
    }
    
    public func recalculate(_ list: [widget_t] = []) {
        var x: CGFloat = Constants.Widget.spacing
        list.forEach { (type: widget_t) in
            if let view = self.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier(type.rawValue) }) {
                view.setFrameOrigin(NSPoint(x: x, y: view.frame.origin.y))
                x = view.frame.origin.x + view.frame.width + Constants.Widget.spacing
            }
        }
    }
}
