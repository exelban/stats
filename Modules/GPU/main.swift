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
import Kit

public typealias GPU_type = String
public enum GPU_types: GPU_type {
    case unknown = ""
    
    case integrated = "i"
    case external = "e"
    case discrete = "d"
}

public struct GPU_Info: Codable {
    public let id: String
    public let type: GPU_type
    
    public let IOClass: String
    public var vendor: String? = nil
    public let model: String
    public var cores: Int? = nil
    
    public var state: Bool = true
    
    public var fanSpeed: Int? = nil
    public var coreClock: Int? = nil
    public var memoryClock: Int? = nil
    public var temperature: Double? = nil
    public var utilization: Double? = nil
    public var renderUtilization: Double? = nil
    public var tilerUtilization: Double? = nil
    
    init(id: String, type: GPU_type, IOClass: String, vendor: String? = nil, model: String, cores: Int?) {
        self.id = id
        self.type = type
        self.IOClass = IOClass
        self.vendor = vendor
        self.model = model
        self.cores = cores
    }
}

public struct GPUs: value_t, Codable {
    public var list: [GPU_Info] = []
    
    internal func active() -> [GPU_Info] {
        return self.list.filter{ $0.state && $0.utilization != nil }.sorted{ $0.utilization ?? 0 > $1.utilization ?? 0 }
    }
    
    public var widgetValue: Double {
        get {
            return list.isEmpty ? 0 : (list[0].utilization ?? 0)
        }
    }
}

public class GPU: Module {
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal
    
    private var infoReader: InfoReader? = nil
    
    private var selectedGPU: String = ""
    private var notificationLevelState: Bool = false
    private var notificationID: String? = nil
    
    private var showType: Bool {
        get {
            return Store.shared.bool(key: "\(self.config.name)_showType", defaultValue: false)
        }
    }
    private var notificationLevel: String {
        get {
            return Store.shared.string(key: "\(self.config.name)_notificationLevel", defaultValue: "Disabled")
        }
    }
    
    public init() {
        self.popupView = Popup()
        self.settingsView = Settings("GPU")
        self.portalView = Portal("GPU")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView
        )
        guard self.available else { return }
        
        self.infoReader = InfoReader(.GPU)
        self.selectedGPU = Store.shared.string(key: "\(self.config.name)_gpu", defaultValue: self.selectedGPU)
        
        self.infoReader?.callbackHandler = { [unowned self] value in
            self.infoCallback(value)
        }
        self.infoReader?.readyCallback = { [unowned self] in
            self.readyHandler()
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
        guard raw != nil && !raw!.list.isEmpty, let value = raw, self.enabled else {
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
        guard let utilization = selectedGPU.utilization else {
            return
        }
        
        self.portalView.loadCallback(selectedGPU)
        self.checkNotificationLevel(utilization)
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini:
                widget.setValue(utilization)
                widget.setTitle(self.showType ? "\(selectedGPU.type)GPU" : nil)
            case let widget as LineChart: widget.setValue(utilization)
            case let widget as BarChart: widget.setValue([[ColorValue(utilization)]])
            case let widget as Tachometer:
                widget.setValue([
                    circle_segment(value: utilization, color: NSColor.systemBlue)
                ])
            default: break
            }
        }
    }
    
    private func checkNotificationLevel(_ value: Double) {
        guard self.notificationLevel != "Disabled", let level = Double(self.notificationLevel) else { return }
        
        if let id = self.notificationID, value < level && self.notificationLevelState {
            removeNotification(id)
            self.notificationID = nil
            self.notificationLevelState = false
        } else if value >= level && !self.notificationLevelState {
            self.notificationID = showNotification(
                title: localizedString("GPU usage threshold"),
                subtitle: localizedString("GPU usage is", "\(Int((value)*100))%")
            )
            self.notificationLevelState = true
        }
    }
}
