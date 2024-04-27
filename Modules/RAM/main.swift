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

public struct RAM_Usage: value_t, Codable {
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
    
    var rawPressureLevel: UInt
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
    
    public var pressureLevel: DispatchSource.MemoryPressureEvent {
        DispatchSource.MemoryPressureEvent(rawValue: self.rawPressureLevel)
    }
}

public struct Swap: Codable {
    var total: Double
    var used: Double
    var free: Double
}

public class RAM: Module {
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal
    private let notificationsView: Notifications
    
    private var usageReader: UsageReader? = nil
    private var processReader: ProcessReader? = nil
    
    private var splitValueState: Bool {
        return Store.shared.bool(key: "\(self.config.name)_splitValue", defaultValue: false)
    }
    private var appColor: NSColor {
        let color = Color.secondBlue
        let key = Store.shared.string(key: "\(self.config.name)_appColor", defaultValue: color.key)
        if let c = Color.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var wiredColor: NSColor {
        let color = Color.secondOrange
        let key = Store.shared.string(key: "\(self.config.name)_wiredColor", defaultValue: color.key)
        if let c = Color.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var compressedColor: NSColor {
        let color = Color.pink
        let key = Store.shared.string(key: "\(self.config.name)_compressedColor", defaultValue: color.key)
        if let c = Color.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    
    public init() {
        self.settingsView = Settings(.RAM)
        self.popupView = Popup(.RAM)
        self.portalView = Portal(.RAM)
        self.notificationsView = Notifications(.RAM)
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView,
            notifications: self.notificationsView
        )
        guard self.available else { return }
        
        self.settingsView.callback = { [weak self] in
            self?.usageReader?.read()
        }
        self.settingsView.setInterval = { [weak self] value in
            self?.processReader?.read()
            self?.usageReader?.setInterval(value)
        }
        self.settingsView.setTopInterval = { [weak self] value in
            self?.processReader?.setInterval(value)
        }
        
        self.usageReader = UsageReader(.RAM) { [weak self] value in
            self?.loadCallback(value)
        }
        self.processReader = ProcessReader(.RAM) { [weak self] value in
            if let list = value {
                self?.popupView.processCallback(list)
            }
        }
        
        self.settingsView.callbackWhenUpdateNumberOfProcesses = { [weak self] in
            self?.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self?.processReader?.read()
            }
        }
        
        self.setReaders([self.usageReader, self.processReader])
    }
    
    private func loadCallback(_ raw: RAM_Usage?) {
        guard raw != nil, let value = raw, self.enabled else { return }
        
        self.popupView.loadCallback(value)
        self.portalView.callback(value)
        self.notificationsView.loadCallback(value)
        
        let total: Double = value.total == 0 ? 1 : value.total
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini:
                widget.setValue(value.usage)
                widget.setPressure(value.pressureLevel)
            case let widget as LineChart:
                widget.setValue(value.usage)
                widget.setPressure(value.pressureLevel)
            case let widget as BarChart:
                if self.splitValueState {
                    widget.setValue([[
                        ColorValue(value.app/total, color: self.appColor),
                        ColorValue(value.wired/total, color: self.wiredColor),
                        ColorValue(value.compressed/total, color: self.compressedColor)
                    ]])
                } else {
                    widget.setValue([[ColorValue(value.usage)]])
                    widget.setColorZones((0.8, 0.95))
                    widget.setPressure(value.pressureLevel)
                }
            case let widget as PieChart:
                widget.setValue([
                    circle_segment(value: value.app/total, color: self.appColor),
                    circle_segment(value: value.wired/total, color: self.wiredColor),
                    circle_segment(value: value.compressed/total, color: self.compressedColor)
                ])
            case let widget as MemoryWidget:
                let free = Units(bytes: Int64(value.free)).getReadableMemory()
                let used = Units(bytes: Int64(value.used)).getReadableMemory()
                widget.setValue((free, used), usedPercentage: value.usage)
                widget.setPressure(value.pressureLevel)
            case let widget as Tachometer:
                widget.setValue([
                    circle_segment(value: value.app/total, color: self.appColor),
                    circle_segment(value: value.wired/total, color: self.wiredColor),
                    circle_segment(value: value.compressed/total, color: self.compressedColor)
                ])
            default: break
            }
        }
    }
}
