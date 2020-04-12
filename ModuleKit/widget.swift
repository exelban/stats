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

public protocol Widget_p: NSView {
    var title: String { get }
    var widthHandler: ((CGFloat) -> Void)? { get set }
    
    func setTitle(_ title: String)
    func setValue(_ value: AnyObject)
}

open class Widget: NSView, Widget_p {
    public var widthHandler: ((CGFloat) -> Void)? = nil
    public var title: String = ""
    
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
    
    public func setTitle(_ title: String) {}
    @objc dynamic open func setValue(_ value: AnyObject) {}
}

func LoadWidget(type: String) -> Widget_p? {
    var widget: Widget_p?
    
    switch type {
    case "Mini":
        widget = Mini()
        break
    default: break
    }
    
    return widget
}

struct WidgetSize {
    let x: CGFloat = 2
    let y: CGFloat = 2
    
    let width: CGFloat = 32
    var height: CGFloat {
        get {
            let systemHeight = NSApplication.shared.mainMenu?.menuBarHeight
            return (systemHeight == 0 ? 22 : systemHeight) ?? 22
        }
    }
}
let widgetConst = WidgetSize()
