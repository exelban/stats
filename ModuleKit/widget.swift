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

public enum widget_t: String {
    case unknown = ""
    case mini = "mini"
    case chart = "chart"
}
extension widget_t: CaseIterable {}

public protocol Widget_p: NSView {
    var title: String { get }
    var type: widget_t { get }
    var widthHandler: ((CGFloat) -> Void)? { get set }
    
    func setTitle(_ title: String)
    func setValue(_ value: AnyObject)
}

open class Widget: NSView, Widget_p {
    public var widthHandler: ((CGFloat) -> Void)? = nil
    public var title: String = ""
    public var type: widget_t = .unknown
    
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    public func setWidth(_ width: CGFloat) {
        if self.widthHandler == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + .microseconds(10)) {
                self.setWidth(width)
            }
            return
        }
        
        self.display()
        self.setFrameSize(NSSize(width: width, height: self.frame.size.height))
        self.invalidateIntrinsicContentSize()
        
        self.widthHandler!(width)
    }
    
    public func setTitle(_ title: String) {
        self.title = title
    }
    @objc dynamic open func setValue(_ value: AnyObject) {}
}

func LoadWidget(_ type: widget_t, preview: Bool) -> Widget_p? {
    var widget: Widget_p? = nil
    
    switch type {
    case .mini:
        widget = Mini(preview: preview)
        break
    case .chart:
        widget = ChartWidget(preview: preview)
        break
    default: break
    }
    
    return widget
}
