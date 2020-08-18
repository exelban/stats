//
//  main.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

public struct GPU_Info {
    public let name: String
    public let IOclass: String
    public var state: Bool = false
    
    public var utilization: Double = 0
    public var temperature: Int = 0
}

public struct GPUs: value_t {
    public var list: [GPU_Info] = []
    
    internal func active() -> [GPU_Info] {
        return self.list.filter{ $0.state }
    }
    
    internal func igpu() -> GPU_Info? {
        return self.active().first{ $0.IOclass == "IntelAccelerator" }
    }
    
    public var widget_value: Double {
        get {
            return list[0].utilization
        }
    }
}

public class GPU: Module {
    private let smc: UnsafePointer<SMCService>?
    private let store: UnsafePointer<Store>
    
    private var infoReader: InfoReader? = nil
    private var settingsView: Settings
    private var popupView: Popup = Popup()
    
    private var selectedGPU: String = ""
    
    public init(_ store: UnsafePointer<Store>, _ smc: UnsafePointer<SMCService>) {
        self.store = store
        self.smc = smc
        self.settingsView = Settings("GPU", store: store)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.infoReader = InfoReader()
        self.infoReader?.smc = smc
        self.selectedGPU = store.pointee.string(key: "\(self.config.name)_gpu", defaultValue: self.selectedGPU)
        
        self.infoReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.infoReader?.callbackHandler = { [unowned self] value in
            self.infoCallback(value)
        }
        
        self.settingsView.selectedGPUHandler = { [unowned self] value in
            self.selectedGPU = value
            self.infoReader?.read()
        }
        self.settingsView.setInterval = { [unowned self] value in
            self.infoReader?.setInterval(value)
        }
        
        if let reader = self.infoReader {
            self.addReader(reader)
        }
    }
    
    private func infoCallback(_ value: GPUs?) {
        guard value != nil else {
            return
        }
        
        self.popupView.infoCallback(value!)
        self.settingsView.setList(value!)
        
        let activeGPU = value!.active()
        let selectedGPU = activeGPU.first{ $0.name == self.selectedGPU } ?? value!.igpu() ?? value!.list[0]
        
        if let widget = self.widget as? Mini {
            widget.setValue(selectedGPU.utilization, sufix: "%")
        }
        if let widget = self.widget as? LineChart {
            widget.setValue(selectedGPU.utilization)
        }
        if let widget = self.widget as? BarChart {
            widget.setValue([selectedGPU.utilization])
        }
    }
}
