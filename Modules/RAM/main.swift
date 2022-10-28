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
    
    var pressureLevel: DispatchSource.MemoryPressureEvent
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
    
    private var notificationLevelState: Bool = false
    private var notificationID: String? = nil
    
    private var splitValueState: Bool {
        return Store.shared.bool(key: "\(self.config.name)_splitValue", defaultValue: false)
    }
    private var notificationLevel: String {
        return Store.shared.string(key: "\(self.config.name)_notificationLevel", defaultValue: "Disabled")
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
        self.settingsView = Settings("RAM")
        self.popupView = Popup("RAM")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.settingsView.callback = { [unowned self] in
            self.usageReader?.read()
        }
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
        guard raw != nil, let value = raw, self.enabled else {
            return
        }
        
        self.popupView.loadCallback(value)
        self.checkNotificationLevel(value.usage)
        
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
                widget.setValue((free, used))
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
    
    private func checkNotificationLevel(_ value: Double) {
        guard self.notificationLevel != "Disabled", let level = Double(self.notificationLevel) else { return }
        
        if let id = self.notificationID, value < level && self.notificationLevelState {
            if #available(macOS 10.14, *) {
                removeNotification(id)
            } else {
                removeNSNotification(id)
            }
            
            self.notificationID = nil
            self.notificationLevelState = false
        } else if value >= level && !self.notificationLevelState {
            let title = localizedString("RAM utilization threshold")
            let subtitle = localizedString("RAM utilization is", "\(Int((value)*100))%")
            
            if #available(macOS 10.14, *) {
                self.notificationID = showNotification(title: title, subtitle: subtitle)
            } else {
                self.notificationID = showNSNotification(title: title, subtitle: subtitle)
            }
            
            self.notificationLevelState = true
        }
    }
}
