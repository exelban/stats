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
    var submenu: NSMenu { get }
    var active: Observable<Bool> { get }
    var available: Observable<Bool> { get }
    var reader: Reader { get }
    var widgetType: WidgetType { get }
    
    func start()
    func stop()
}

extension Module {
    func initWidget() {
        switch self.widgetType {
        case Widgets.Mini:
            let widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
            break
        case Widgets.Chart:
            let widget = Chart(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
            break
        case Widgets.ChartWithValue:
            let widget = ChartWithValue(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
            break
        case Widgets.Dots:
            self.view = NetworkDotsView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.Arrows:
            self.view = NetworkArrowsView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.Text:
            self.view = NetworkTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.DotsWithText:
            self.view = NetworkDotsTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.ArrowsWithText:
            self.view = NetworkArrowsTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        default:
            let widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
        }
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
    var usage: Observable<Double>! { get }
    var available: Bool { get }
    var updateTimer: Timer! { get set }
    func start()
    func stop()
    func read()
}

protocol Widget {
    func value(value: Double)
    func redraw()
}

typealias WidgetType = Float

struct Widgets {
    static let Mini: WidgetType = 0.0
    static let Chart: WidgetType = 1.0
    static let ChartWithValue: WidgetType = 1.1
    
    static let Dots: WidgetType = 2.0
    static let Arrows: WidgetType = 2.1
    static let Text: WidgetType = 2.2
    static let DotsWithText: WidgetType = 2.3
    static let ArrowsWithText: WidgetType = 2.4
}
