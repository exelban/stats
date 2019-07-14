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
    func initWidget(label: Bool = false) {
        var widget: Widget = Mini()
        
        switch self.widgetType {
        case Widgets.Mini:
            widget = Mini()
        case Widgets.Chart:
            widget = Chart()
        case Widgets.ChartWithValue:
            widget = ChartWithValue()
        case Widgets.NetworkDots:
            widget = NetworkDotsView()
        case Widgets.NetworkArrows:
            widget = NetworkArrowsView()
        case Widgets.NetworkText:
            widget = NetworkTextView()
        case Widgets.NetworkDotsWithText:
            widget = NetworkDotsTextView()
        case Widgets.NetworkArrowsWithText:
            widget = NetworkArrowsTextView()
        case Widgets.BarChart:
            widget = BarChart()
        default:
            widget = Mini()
        }
        
        widget.name = self.name
        widget.shortName = self.shortName
        widget.activeModule = self.active
        widget.Init()
        
        self.view = widget as! NSView
    }
    
    func start() {
        if !self.reader.value.value.isEmpty {
            guard let widget = self.view as? Widget else {
                return
            }
            widget.setValue(data: self.reader.value.value)
        }
        
        self.reader.start()
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isEmpty {
                guard let widget = self.view as? Widget else {
                    return
                }
                widget.setValue(data: value)
            }
        }
    }
    
    func stop() {
        self.reader.stop()
        self.reader.value.unsubscribe(observer: self)
    }
}
