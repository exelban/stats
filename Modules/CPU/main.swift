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
        self.limitReader = LimitReader(popup: true)
        
        #if arch(x86_64)
        self.temperatureReader = TemperatureReader(popup: true)
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
            if value != nil {
                self.popupView.temperatureCallback(value!)
            }
        }
        self.frequencyReader?.callbackHandler = { [unowned self] value in
            if value != nil {
                self.popupView.frequencyCallback(value!)
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
    }
    
    private func loadCallback(_ raw: CPU_Load?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        self.popupView.loadCallback(value)
        
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
            default: break
            }
        }
    }
}
