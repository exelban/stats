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
    case chart = "chart"
}
extension widget_t: CaseIterable {}

public protocol Widget_p: NSView {
    var title: String { get }
    var preview: Bool { get }
    var type: widget_t { get }
    var widthHandler: ((CGFloat) -> Void)? { get set }
    
    func setValue(_ value: AnyObject)
    func settings(superview: NSView)
}

open class Widget: NSView, Widget_p {
    public var widthHandler: ((CGFloat) -> Void)? = nil
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

        self.display()
        self.setFrameSize(NSSize(width: width, height: self.frame.size.height))
        self.invalidateIntrinsicContentSize()

        self.widthHandler!(width)
    }
    
    open func settings(superview: NSView) {}
    
    @objc dynamic open func setValue(_ value: AnyObject) {}
}

func LoadWidget(_ type: widget_t, preview: Bool, title: String, store: UnsafePointer<Store>?) -> Widget_p? {
    var widget: Widget_p? = nil
    
    switch type {
    case .mini:
        widget = Mini(preview: preview, title: title, store: store)
        break
    case .chart:
        widget = ChartWidget(preview: preview, title: title)
        break
    default: break
    }
    
    return widget
}
