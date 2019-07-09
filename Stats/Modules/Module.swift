//
//  Module.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 08.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

protocol Module: class {
    var name: String { get }
    var shortName: String { get }
    
    var view: NSView { get set }
    var menu: NSMenuItem { get }
    var widgetType: WidgetType { get }
    
    var active: Observable<Bool> { get }
    var available: Observable<Bool> { get }
    var color: Observable<Bool> { get set }
    
    var reader: Reader { get }
    
    func start()
    func stop()
}

extension Module {
    func initWidget(color: Bool = false) {
        var widget: Widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        
        switch self.widgetType {
        case Widgets.Mini:
            widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        case Widgets.Chart:
            widget = Chart(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
        case Widgets.ChartWithValue:
            widget = ChartWithValue(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
        case Widgets.NetworkDots:
            widget = NetworkDotsView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        case Widgets.NetworkArrows:
            widget = NetworkArrowsView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        case Widgets.NetworkText:
            widget = NetworkTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        case Widgets.NetworkDotsWithText:
            widget = NetworkDotsTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        case Widgets.NetworkArrowsWithText:
            widget = NetworkArrowsTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        default:
            widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
        }
        
        widget.label = self.shortName
        widget.color(state: self.color.value)
        self.view = widget as! NSView
    }
    
    func start() {
        if !self.reader.value.value.isNaN {
            guard let widget = self.view as? Widget else {
                return
            }
            widget.value(value: self.reader.value.value)
        }
        
        self.reader.start()
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                guard let widget = self.view as? Widget else {
                    return
                }
                widget.value(value: value)
            }
        }
        
        self.color.subscribe(observer: self) { (value, _) in
            guard let widget = self.view as? Widget else {
                return
            }
            widget.color(state: value)
            widget.redraw()
        }
    }
    
    func stop() {
        self.reader.stop()
        self.reader.value.unsubscribe(observer: self)
        self.color.unsubscribe(observer: self)
    }
}
