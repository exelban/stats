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

public typealias GPU_type = String
public enum GPU_types: GPU_type {
    case unknown = ""
    
    case integrated = "i"
    case external = "e"
    case discrete = "d"
}

public struct GPU_Info {
    public let model: String
    public let IOClass: String
    public let type: GPU_type
    public var state: Bool = false
    
    public var utilization: Double = 0
    public var temperature: Int = 0
}

public struct GPUs: value_t {
    public var list: [GPU_Info] = []
    
    internal func active() -> [GPU_Info] {
        return self.list.filter{ $0.state }
    }
    
    public var widget_value: Double {
        get {
            return list.isEmpty ? 0 : list[0].utilization
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
    
    private var showType: Bool {
        get {
            return self.store.pointee.bool(key: "\(self.config.name)_showType", defaultValue: false)
        }
    }
    
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
        self.settingsView.callback = {
            self.infoReader?.read()
        }
        
        if let reader = self.infoReader {
            self.addReader(reader)
        }
    }
    
    private func infoCallback(_ raw: GPUs?) {
        guard raw != nil && !raw!.list.isEmpty, let value = raw else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.popupView.infoCallback(value)
        })
        self.settingsView.setList(value)
        
        let activeGPUs = value.active()
        guard let activeGPU = activeGPUs.first(where: { $0.state }) ?? activeGPUs.first else {
            return
        }
        let selectedGPU: GPU_Info = activeGPUs.first{ $0.model == self.selectedGPU } ?? activeGPU
        
        if let widget = self.widget as? Mini {
            widget.setValue(selectedGPU.utilization)
            widget.setTitle(self.showType ? "\(selectedGPU.type)GPU" : nil)
        }
        if let widget = self.widget as? LineChart {
            widget.setValue(selectedGPU.utilization)
        }
        if let widget = self.widget as? BarChart {
            widget.setValue([selectedGPU.utilization])
        }
    }
}
