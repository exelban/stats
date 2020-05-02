//
//  main.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 12/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

public struct MemoryUsage: value_t {
    var active: Double?
    var inactive: Double?
    var wired: Double?
    var compressed: Double?
    
    var usage: Double?
    var total: Double?
    var used: Double?
    var free: Double?
    
    public var widget_value: Double {
        get {
            return self.usage ?? 0
        }
    }
}

public class Memory: Module {
    private let popup: Popup = Popup()
    
    private var usageReader: UsageReader = UsageReader()
    
    public init(_ store: UnsafePointer<Store>?) {
        var widgets: [widget_t] = [.mini, .lineChart, .barChart]
        super.init(store: store, name: "RAM", icon: nil, popup: self.popup, defaultWidget: .mini, widgets: &widgets, defaultState: true)
        
        self.usageReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader.callbackHandler = { [unowned self] value in
            self.loadCallback(value: value)
        }
        
        self.addReader(self.usageReader)
    }
    
    private func loadCallback(value: MemoryUsage?) {
        if value == nil {
            return
        }
        
        self.popup.loadCallback(value!)
        if let widget = self.widget as? Mini {
            widget.setValue(value!.usage ?? 0, sufix: "%")
        }
        if let widget = self.widget as? LineChart {
            widget.setValue(value!.usage ?? 0)
        }
        if let widget = self.widget as? BarChart {
            widget.setValue([value!.usage ?? 0])
        }
    }
}
