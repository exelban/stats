//
//  RAM.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

class RAM: Module {
    public var name: String = "RAM"
    public var updateInterval: Double = 1
    
    public var enabled: Bool = true
    public var available: Bool = true
    
    public var readers: [Reader] = []
    public var task: Repeater?
    
    public var widget: ModuleWidget = ModuleWidget()
    public var popup: ModulePopup = ModulePopup(true)
    public var menu: NSMenuItem = NSMenuItem()
    
    public let defaults = UserDefaults.standard
    public var submenu: NSMenu = NSMenu()
    
    public var totalValue: NSTextField = NSTextField()
    public var usedValue: NSTextField = NSTextField()
    public var freeValue: NSTextField = NSTextField()
    public var processViewList: [NSStackView] = []
    public var chart: LineChartView = LineChartView()
    
    init() {
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        
        readers.append(RAMUsageReader(self.usageUpdater))
        readers.append(RAMProcessReader(self.processesUpdater))
        
        self.initWidget()
        self.initMenu()
        self.initPopup()
        
        self.task = Repeater.init(interval: .seconds(self.updateInterval), observer: { _ in
            self.readers.forEach { reader in
                reader.read()
            }
        })
    }
    
    public func start() {
        if self.task != nil && self.task!.state.isRunning == false {
            self.task!.start()
        }
    }
    
    public func stop() {
        if self.task!.state.isRunning {
            self.task?.pause()
        }
    }
    
    public func restart() {
        self.stop()
        self.start()
    }
    
    private func usageUpdater(value: RAMUsage) {
        self.chartUpdater(value: value)
        self.overviewUpdater(value: value)
        
        if self.widget.view is Widget {
            (self.widget.view as! Widget).setValue(data: [value.usage])
        }
    }
}
