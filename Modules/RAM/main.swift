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
import Kit

public struct RAM_Usage: value_t {
    var total: Double
    var used: Double
    var free: Double
    
    var active: Double
    var inactive: Double
    var wired: Double
    var compressed: Double
    
    var app: Double
    var cache: Double
    var pressure: Double
    
    var pressureLevel: Int
    var swap: Swap
    
    public var widgetValue: Double {
        get {
            return self.usage
        }
    }
    
    public var usage: Double {
        get {
            return Double((self.total - self.free) / self.total)
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
    
    public init() {
        self.settingsView = Settings("RAM")
        self.popupView = Popup("RAM")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.settingsView.setInterval = { [unowned self] value in
            self.processReader?.read()
            self.usageReader?.setInterval(value)
        }
        self.settingsView.setTopInterval = { [unowned self] value in
            self.processReader?.setInterval(value)
        }
        
        self.usageReader = UsageReader()
        self.processReader = ProcessReader()
        
        self.settingsView.callbackWhenUpdateNumberOfProcesses = {
            self.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self.processReader?.read()
            }
        }
        
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.loadCallback(value)
        }
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
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
        
        let total: Double = value.total == 0 ? 1 : value.total
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini:
                widget.setValue(value.usage)
                widget.setPressure(value.pressureLevel)
            case let widget as LineChart:
                widget.setValue(value.usage)
                widget.setPressure(value.pressureLevel)
            case let widget as BarChart:
                widget.setValue([[ColorValue(value.usage)]])
                widget.setColorZones((0.8, 0.95))
                widget.setPressure(value.pressureLevel)
            case let widget as PieChart:
                widget.setValue([
                    circle_segment(value: value.app/total, color: NSColor.systemBlue),
                    circle_segment(value: value.wired/total, color: NSColor.systemOrange),
                    circle_segment(value: value.compressed/total, color: NSColor.systemPink)
                ])
            case let widget as MemoryWidget:
                let free = Units(bytes: Int64(value.free)).getReadableMemory()
                let used = Units(bytes: Int64(value.used)).getReadableMemory()
                widget.setValue((free, used))
            default: break
            }
        }
    }
}
