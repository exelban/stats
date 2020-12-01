//
//  main.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

public struct CPU_Load: value_t {
    var totalUsage: Double = 0
    var usagePerCore: [Double] = []
    
    var systemLoad: Double = 0
    var userLoad: Double = 0
    var idleLoad: Double = 0
    
    public var widget_value: Double {
        get {
            return self.totalUsage
        }
    }
}

public class CPU: Module {
    private var popupView: Popup
    private var settingsView: Settings
    
    private var loadReader: LoadReader? = nil
    private var processReader: ProcessReader? = nil
    private var temperatureReader: TemperatureReader? = nil
    private var frequencyReader: FrequencyReader? = nil
    private let smc: UnsafePointer<SMCService>?
    private let store: UnsafePointer<Store>
    
    private var usagePerCoreState: Bool {
        get {
            return self.store.pointee.bool(key: "\(self.config.name)_usagePerCore", defaultValue: false)
        }
    }
    
    public init(_ store: UnsafePointer<Store>, _ smc: UnsafePointer<SMCService>) {
        self.store = store
        self.smc = smc
        self.settingsView = Settings("CPU", store: store)
        self.popupView = Popup("CPU", store: store)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.loadReader = LoadReader()
        self.loadReader?.store = store
        
        self.processReader = ProcessReader(self.config.name, store: store)
        self.temperatureReader = TemperatureReader(smc)
        
        #if arch(x86_64)
        self.frequencyReader = FrequencyReader()
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
        
        self.loadReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.loadReader?.callbackHandler = { [unowned self] value in
            self.loadCallback(value)
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
    }
    
    private func loadCallback(_ value: CPU_Load?) {
        guard value != nil else {
            return
        }
        
        self.popupView.loadCallback(value!)
        
        if let widget = self.widget as? Mini {
            widget.setValue(value!.totalUsage)
        }
        if let widget = self.widget as? LineChart {
            widget.setValue(value!.totalUsage)
        }
        if let widget = self.widget as? BarChart {
            widget.setValue(self.usagePerCoreState ? value!.usagePerCore : [value!.totalUsage])
        }
        if let widget = self.widget as? PieChart {
            widget.setValue([
                circle_segment(value: value!.systemLoad, color: NSColor.systemRed),
                circle_segment(value: value!.userLoad, color: NSColor.systemBlue)
            ])
        }
    }
}
