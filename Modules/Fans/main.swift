//
//  main.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 20/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

public struct Fan {
    public let id: Int
    public let name: String
    public let minSpeed: Double
    public let maxSpeed: Double
    public var value: Double
    
    var state: Bool {
        get {
            return Store.shared.bool(key: "fan_\(self.id)", defaultValue: true)
        }
    }
    
    var formattedValue: String {
        get {
            return "\(Int(value)) RPM"
        }
    }
}

public class Fans: Module {
    private let store: UnsafePointer<Store>
    private var smc: UnsafePointer<SMCService>
    
    private var fansReader: FansReader
    private var settingsView: Settings
    private let popupView: Popup = Popup()
    
    public init(_ store: UnsafePointer<Store>, _ smc: UnsafePointer<SMCService>) {
        self.store = store
        self.smc = smc
        self.fansReader = FansReader(smc)
        self.settingsView = Settings("Fans", store: store, list: &self.fansReader.list)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.checkIfNoSensorsEnabled()
        self.popupView.setup(self.fansReader.list)
        
        self.settingsView.callback = { [unowned self] in
            self.checkIfNoSensorsEnabled()
            self.fansReader.read()
        }
        self.settingsView.setInterval = { [unowned self] value in
            self.fansReader.setInterval(value)
        }
        
        self.fansReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.fansReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        
        self.addReader(self.fansReader)
    }
    
    public override func isAvailable() -> Bool {
        return smc.pointee.getValue("FNum") != nil && smc.pointee.getValue("FNum") != 0 && !self.fansReader.list.isEmpty
    }
    
    private func checkIfNoSensorsEnabled() {
        if self.fansReader.list.filter({ $0.state }).count == 0 {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.config.name, "state": false])
        }
    }
    
    private func usageCallback(_ value: [Fan]?) {
        if value == nil {
            return
        }
        
        self.popupView.usageCallback(value!)
        
        let label: Bool = store.pointee.bool(key: "Fans_label", defaultValue: false)
        var list: [SensorValue_t] = []
        value!.forEach { (f: Fan) in
            if f.state {
                let str = label ? "\(f.name.prefix(1).uppercased()): \(f.formattedValue)" : f.formattedValue
                list.append(SensorValue_t(str))
            }
        }
        
        if let widget = self.widget as? SensorsWidget {
            widget.setValues(list)
        }
    }
}
