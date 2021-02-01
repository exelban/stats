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
    
    public func new(module: String, config: NSDictionary?, store: UnsafePointer<Store>?, preview: Bool = false) -> Widget_p? {
        var widget: Widget_p? = nil
        let widgetConfig: NSDictionary? = config?[self.rawValue] as? NSDictionary
        
        switch self {
        case .mini:
            widget = Mini(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .lineChart:
            widget = LineChart(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .barChart:
            widget = BarChart(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .pieChart:
            widget = PieChart(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .networkChart:
            widget = NetworkChart(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .speed:
            widget = SpeedWidget(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .battery:
            widget = BatterykWidget(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .sensors:
            widget = SensorsWidget(preview: preview, title: module, config: widgetConfig, store: store)
            break
        case .memory:
            widget = MemoryWidget(preview: preview, title: module, config: widgetConfig, store: store)
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

public protocol Widget_p: NSView {
    var type: widget_t { get }
    var title: String { get }
    
    var widthHandler: ((CGFloat) -> Void)? { get set }
    
    func setValues(_ values: [value_t])
    func settings(superview: NSView)
}

open class Widget: NSView, Widget_p {
    public var type: widget_t
    public var title: String
    
    public var widthHandler: ((CGFloat) -> Void)? = nil
    private var widthHandlerRetry: Int8 = 0
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    public init(_ type: widget_t, title: String, frame: NSRect, preview: Bool) {
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
    
    open func settings(superview: NSView) {}
    open func setValues(_ values: [value_t]) {}
}
