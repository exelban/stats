//
//  Module.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 08.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

protocol Module: class {
    var name: String { get } // module name
    var updateInterval: Double { get } // module update interval
    
    var enabled: Bool { get } // determine if module is enabled or disabled
    var available: Bool { get } // determine if module is available on this PC
    
    var widget: ModuleWidget { get set } // view for widget
    var menu: NSMenuItem { get } // view for menu
    var popup: ModulePopup { get set } // popup
    
    var readers: [Reader] { get } // list of readers available for module
    var task: Repeater? { get set } // reader cron task
    
    func start() // start module internal processes
    func stop() // stop module internal processes
    func restart() // restart module internal processes
    
    func initWidget()
}

protocol Reader {
    var name: String { get } // reader name
    var enabled: Bool { get set } // determine if reader is enabled or disabled
    var available: Bool { get } // determine if reader is available on this PC
    var optional: Bool { get } // say if reader are optional (additional information)
    var initialized: Bool { get } // to check if first read already done
    
    func read() // make one read
    
    func toggleEnable(_ value: Bool) -> Void // enable/disable optional reader
}

struct ModulePopup {
    var available: Bool = true // say if module have popup view
    var view: NSTabViewItem = NSTabViewItem() // module popup view
    var active: Bool = false // indicate that popup is opened and selected this view
    var initialized: Bool = false // allows to set some value when on first load
    
    init(_ a: Bool = true) {
        available = a
    }
    
    mutating func setActive(_ state: Bool) {
        if self.active != state {
            self.active = state
        }
    }
}

struct ModuleWidget {
    var type: WidgetType = Widgets.Mini // determine a widget typ
    var view: NSView = NSView() // widget view
    
    init(_ t: WidgetType = Widgets.Mini) {
        type = t
    }
}

extension Module {
    func initWidget() {
        var widget: Widget = Mini()
        
        switch self.widget.type {
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
        widget.start()

        self.readers.forEach { reader in
            reader.read()
        }

        self.widget.view = widget as! NSView
    }
}
