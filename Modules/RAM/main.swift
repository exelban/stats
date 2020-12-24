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

public struct RAM_Usage: value_t {
    var active: Double
    var inactive: Double
    var wired: Double
    var compressed: Double
    
    var usage: Double
    var total: Double
    var used: Double
    var free: Double
    
    var pressureLevel: Int
    var swap: Swap
    
    public var widget_value: Double {
        get {
            return self.usage
        }
    }
}

public struct Swap {
    var total: Double
    var used: Double
    var free: Double
}

public class RAM: Module {
    private var settingsView: Settings
    private let popupView: Popup
    private var usageReader: UsageReader? = nil
    private var processReader: ProcessReader? = nil
    
    public init(_ store: UnsafePointer<Store>) {
        self.settingsView = Settings("RAM", store: store)
        self.popupView = Popup("RAM", store: store)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.settingsView.setInterval = { [unowned self] value in
            self.processReader?.read()
            self.usageReader?.setInterval(value)
        }
        
        self.usageReader = UsageReader()
        self.processReader = ProcessReader(self.config.name, store: store)
        
        self.settingsView.callbackWhenUpdateNumberOfProcesses = {
            self.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self.processReader?.read()
            }
        }
        
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.loadCallback(value)
        }
        
        self.processReader?.callbackHandler = { [unowned self] value in
            if let list = value {
                self.popupView.processCallback(list)
            }
        }
        
        if let reader = self.usageReader {
            self.addReader(reader)
        }
        if let reader = self.processReader {
            self.addReader(reader)
        }
    }
    
    private func loadCallback(_ raw: RAM_Usage?) {
        guard raw != nil, let value = raw else {
            return
        }
        
        self.popupView.loadCallback(value)
        if let widget = self.widget as? Mini {
            widget.setValue(value.usage)
            widget.setPressure(value.pressureLevel)
        }
        if let widget = self.widget as? LineChart {
            widget.setValue(value.usage)
            widget.setPressure(value.pressureLevel)
        }
        if let widget = self.widget as? BarChart {
            widget.setValue([value.usage])
            widget.setPressure(value.pressureLevel)
        }
        if let widget = self.widget as? PieChart {
            let total: Double = value.total
            widget.setValue([
                circle_segment(value: value.active/total, color: NSColor.systemBlue),
                circle_segment(value: value.wired/total, color: NSColor.systemOrange),
                circle_segment(value: value.compressed/total, color: NSColor.systemPink)
            ])
        }
        if let widget = self.widget as? MemoryWidget {
            let free = Units(bytes: Int64(value.free)).getReadableMemory()
            let used = Units(bytes: Int64(value.used)).getReadableMemory()
            widget.setValue((free, used))
        }
    }
}
