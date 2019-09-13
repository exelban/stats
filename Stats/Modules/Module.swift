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
    
    var tabView: NSTabViewItem { get }
    var tabAvailable: Bool { get }
    var tabInitialized: Bool { get }
    
    var reader: Reader { get }
    
    func start()
    func stop()
    
    func initMenu(active: Bool)
    func initTab()
    func initWidget()
}

extension Module {
    
    func initWidget() {
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
        case Widgets.Battery:
            widget = BatteryWidget()
        case Widgets.BatteryPercentage:
            widget = BatteryPercentageWidget()
        case Widgets.BatteryTime:
            widget = BatteryTimeWidget()
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
        self.reader.start()
        
        if !self.reader.value.value.isEmpty {
            (self.view as! Widget).setValue(data: self.reader.value.value)
        }
        
        self.reader.value.subscribe(observer: self) { (value, _) in
            if !value.isEmpty {
                (self.view as! Widget).setValue(data: value)
            }
        }
    }
    
    func stop() {
        self.reader.stop()
        self.reader.value.unsubscribe(observer: self)
    }
}
