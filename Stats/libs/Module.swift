//
//  Module.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

protocol Module: class {
    var name: String { get }
    var shortName: String { get }
    var view: NSView { get set }
    var menu: NSMenuItem { get }
    var active: Observable<Bool> { get }
    var available: Observable<Bool> { get }
    var reader: Reader { get }
    var widgetType: WidgetType { get }
    
    func start()
    func stop()
}

extension Module {
    func initWidget() {
        self.active << false
        switch self.widgetType {
        case Widgets.Mini:
            let widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
            break
        case Widgets.Chart:
            self.view = Chart(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
            break
        case Widgets.ChartWithValue:
            self.view = ChartWithValue(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
            break
        default:
            let widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
        }
        self.active << true
    }
    
    func start() {
        if !self.reader.usage.value.isNaN {
            guard let widget = self.view as? Widget else {
                return
            }
            widget.value(value: self.reader.usage.value)
        }
        
        self.reader.start()
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                guard let widget = self.view as? Widget else {
                    return
                }
                widget.value(value: value)
            }
        }
        
        colors.subscribe(observer: self) { (value, _) in
            guard let widget = self.view as? Widget else {
                return
            }
            widget.redraw()
        }
    }
    
    func stop() {
        self.reader.stop()
        self.reader.usage.unsubscribe(observer: self)
        colors.unsubscribe(observer: self)
    }
}

protocol Reader {
    var usage: Observable<Float>! { get }
    var available: Bool { get }
    var updateTimer: Timer! { get set }
    func start()
    func stop()
    func read()
}

protocol Widget {
    func value(value: Float)
    func redraw()
}

typealias WidgetType = Float

struct Widgets {
    static let Mini: WidgetType = 0.0
    static let Chart: WidgetType = 1.0
    static let ChartWithValue: WidgetType = 1.1
}
