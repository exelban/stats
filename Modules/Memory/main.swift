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

public struct Usage: value_t {
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
    private let popupView: Popup = Popup()
    private var usageReader: UsageReader = UsageReader()
    
    public init(_ store: UnsafePointer<Store>?) {
        super.init(
            store: store,
            popup: self.popupView,
            settings: nil
        )
        
        self.usageReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader.callbackHandler = { [unowned self] value in
            self.loadCallback(value: value)
        }
        
        self.addReader(self.usageReader)
    }
    
    private func loadCallback(value: Usage?) {
        if value == nil {
            return
        }
        
        self.popupView.loadCallback(value!)
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
