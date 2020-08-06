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

public enum widget_c: String {
    case utilization = "Based on utilization"
    case pressure = "Based on pressure"
    
    case separator_1 = "separator_1"
    
    case systemAccent = "System accent"
    case monochrome = "Monochrome accent"
    
    case separator_2 = "separator_2"
    
    case clear = "Clear"
    case white = "White"
    case black = "Black"
    case gray = "Gray"
    case secondGray = "Second gray"
    case darkGray = "Dark gray"
    case lightGray = "Light gray"
    case red = "Red"
    case secondRed = "Second red"
    case green = "Green"
    case secondGreen = "Second green"
    case blue = "Blue"
    case secondBlue = "Second blue"
    case yellow = "Yellow"
    case secondYellow = "Second yellow"
    case orange = "Orange"
    case secondOrange = "Second orange"
    case purple = "Purple"
    case secondPurple = "Second purple"
    case brown = "Brown"
    case secondBrown = "Second brown"
    case cyan = "Cyan"
    case magenta = "Magenta"
    case pink = "Pink"
    case teal = "Teal"
    case indigo = "Indigo"
}
extension widget_c: CaseIterable {}

public enum widget_t: String {
    case unknown = ""
    case mini = "mini"
    case lineChart = "line_chart"
    case barChart = "bar_chart"
    case speed = "speed"
    case battery = "battery"
    case sensors = "sensors"
    case disk = "disk"
}
extension widget_t: CaseIterable {}

public protocol Widget_p: NSView {
    var name: String { get }
    var title: String { get }
    var preview: Bool { get }
    var type: widget_t { get }
    var widthHandler: ((CGFloat) -> Void)? { get set }
    
    func setValues(_ values: [value_t])
    func settings(superview: NSView)
}

open class Widget: NSView, Widget_p {
    public var widthHandler: ((CGFloat) -> Void)? = nil
    public var name: String {
        get {
            switch self.type {
            case .mini: return "Mini"
            case .lineChart: return "Line chart"
            case .barChart: return "Bar chart"
            case .speed: return "Speed"
            case .battery: return "Battery"
            case .sensors: return "Text"
            case .disk: return "Text"
            default: return ""
            }
        }
    }
    public var title: String = ""
    public var preview: Bool = false
    public var type: widget_t = .unknown
    
    private var widthHandlerRetry: Int8 = 0
    
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
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
        
        self.widthHandler!(width)
    }
    
    open func settings(superview: NSView) {}
    open func setValues(_ values: [value_t]) {}
}

func LoadWidget(_ type: widget_t, preview: Bool, name: String, config: NSDictionary?, store: UnsafePointer<Store>?) -> Widget_p? {
    var widget: Widget_p? = nil
    let widgetConfig: NSDictionary? = config?[type.rawValue] as? NSDictionary
    
    switch type {
    case .mini:
        widget = Mini(preview: preview, title: name, config: widgetConfig, store: store)
        break
    case .lineChart:
        widget = LineChart(preview: preview, title: name, config: widgetConfig, store: store)
        break
    case .barChart:
        widget = BarChart(preview: preview, title: name, config: widgetConfig, store: store)
        break
    case .speed:
        widget = SpeedWidget(preview: preview, title: name, config: widgetConfig, store: store)
        break
    case .battery:
        widget = BatterykWidget(preview: preview, title: name, config: widgetConfig, store: store)
        break
    case .sensors:
        widget = SensorsWidget(preview: preview, title: name, config: widgetConfig, store: store)
        break
    case .disk:
        widget = DiskWidget(preview: preview, title: name, config: widgetConfig, store: store)
        break
    default: break
    }
    
    return widget
}
