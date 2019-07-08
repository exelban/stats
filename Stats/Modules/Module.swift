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
    var reader: Reader { get }
    
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
        case Widgets.NetworkDots:
            self.view = NetworkDotsView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.NetworkArrows:
            self.view = NetworkArrowsView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.NetworkText:
            self.view = NetworkTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.NetworkDotsWithText:
            self.view = NetworkDotsTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        case Widgets.NetworkArrowsWithText:
            self.view = NetworkArrowsTextView(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            break
        default:
            let widget = Mini(frame: NSMakeRect(0, 0, MODULE_WIDTH, MODULE_HEIGHT))
            widget.label = self.shortName
            self.view = widget
        }
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
        
        colors.subscribe(observer: self) { (value, _) in
            guard let widget = self.view as? Widget else {
                return
            }
            widget.redraw()
        }
    }
    
    func stop() {
        self.reader.stop()
        self.reader.value.unsubscribe(observer: self)
        colors.unsubscribe(observer: self)
    }
}
