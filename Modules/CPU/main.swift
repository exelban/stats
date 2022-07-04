//
//  main.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public struct CPU_Load: value_t {
    var totalUsage: Double = 0
    var usagePerCore: [Double] = []
    
    var systemLoad: Double = 0
    var userLoad: Double = 0
    var idleLoad: Double = 0
    
    public var widgetValue: Double {
        get {
            return self.totalUsage
        }
    }
}

public struct CPU_Limit {
    var scheduler: Int = 0
    var cpus: Int = 0
    var speed: Int = 0
}

public class CPU: Module {
    private var popupView: Popup
    private var settingsView: Settings
    
    private var loadReader: LoadReader? = nil
    private var processReader: ProcessReader? = nil
    private var temperatureReader: TemperatureReader? = nil
    private var frequencyReader: FrequencyReader? = nil
    private var limitReader: LimitReader? = nil
    private var averageReader: AverageReader? = nil
    
    private var notificationLevelState: Bool = false
    private var notificationID: String? = nil
    
    private var usagePerCoreState: Bool {
        get {
            return Store.shared.bool(key: "\(self.config.name)_usagePerCore", defaultValue: false)
        }
    }
    private var splitValueState: Bool {
        get {
            return Store.shared.bool(key: "\(self.config.name)_splitValue", defaultValue: false)
        }
    }
    private var notificationLevel: String {
        get {
            return Store.shared.string(key: "\(self.config.name)_notificationLevel", defaultValue: "Disabled")
        }
    }
    
    public init() {
        self.settingsView = Settings("CPU")
        self.popupView = Popup("CPU")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.loadReader = LoadReader()
        self.processReader = ProcessReader()
        self.averageReader = AverageReader(popup: true)
        self.temperatureReader = TemperatureReader(popup: true)
        
        #if arch(x86_64)
        self.limitReader = LimitReader(popup: true)
        self.frequencyReader = FrequencyReader(popup: true)
        #endif
        
        self.settingsView.callback = { [unowned self] in
            self.loadReader?.read()
        }
        self.settingsView.callbackWhenUpdateNumberOfProcesses = {
            self.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self.processReader?.read()
            }
        }
        self.settingsView.setInterval = { [unowned self] value in
            self.loadReader?.setInterval(value)
        }
        self.settingsView.setTopInterval = { [unowned self] value in
            self.processReader?.setInterval(value)
        }
        self.settingsView.IPGCallback = { [unowned self] value in
            if value {
                self.frequencyReader?.setup()
            }
            self.popupView.toggleFrequency(state: value)
        }
        
        self.loadReader?.callbackHandler = { [unowned self] value in
            self.loadCallback(value)
        }
        self.loadReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.processReader?.callbackHandler = { [unowned self] value in
            if let list = value {
                self.popupView.processCallback(list)
            }
        }
        
        self.temperatureReader?.callbackHandler = { [unowned self] value in
            if let v = value  {
                self.popupView.temperatureCallback(v)
            }
        }
        self.frequencyReader?.callbackHandler = { [unowned self] value in
            if let v = value  {
                self.popupView.frequencyCallback(v)
            }
        }
        self.limitReader?.callbackHandler = { [unowned self] value in
            if let v = value  {
                self.popupView.limitCallback(v)
            }
        }
        self.averageReader?.callbackHandler = { [unowned self] value in
            if let v = value  {
                self.popupView.averageCallback(v)
            }
        }
        
        if let reader = self.loadReader {
            self.addReader(reader)
        }
        if let reader = self.processReader {
            self.addReader(reader)
        }
        if let reader = self.temperatureReader {
            self.addReader(reader)
        }
        if let reader = self.frequencyReader {
            self.addReader(reader)
        }
        if let reader = self.limitReader {
            self.addReader(reader)
        }
        if let reader = self.averageReader {
            self.addReader(reader)
        }
    }
    
    private func loadCallback(_ raw: CPU_Load?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        self.popupView.loadCallback(value)
        self.checkNotificationLevel(value.totalUsage)
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini: widget.setValue(value.totalUsage)
            case let widget as LineChart: widget.setValue(value.totalUsage)
            case let widget as BarChart:
                var val: [[ColorValue]] = [[ColorValue(value.totalUsage)]]
                if self.usagePerCoreState {
                    val = value.usagePerCore.map({ [ColorValue($0)] })
                } else if self.splitValueState {
                    val = [[
                        ColorValue(value.systemLoad, color: NSColor.systemRed),
                        ColorValue(value.userLoad, color: NSColor.systemBlue)
                    ]]
                }
                widget.setValue(val)
            case let widget as PieChart:
                widget.setValue([
                    circle_segment(value: value.systemLoad, color: NSColor.systemRed),
                    circle_segment(value: value.userLoad, color: NSColor.systemBlue)
                ])
            case let widget as Tachometer:
                widget.setValue([
                    circle_segment(value: value.systemLoad, color: NSColor.systemRed),
                    circle_segment(value: value.userLoad, color: NSColor.systemBlue)
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
            let title = localizedString("CPU usage threshold")
            let subtitle = localizedString("CPU usage is", "\(Int((value)*100))%")
            
            if #available(macOS 10.14, *) {
                self.notificationID = showNotification(title: title, subtitle: subtitle)
            } else {
                self.notificationID = showNSNotification(title: title, subtitle: subtitle)
            }
            
            self.notificationLevelState = true
        }
    }
}
