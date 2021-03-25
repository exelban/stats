//
//  main.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

public class Sensors: Module {
    private var sensorsReader: SensorsReader
    private let popupView: Popup = Popup()
    private var settingsView: Settings
    
    public init() {
        self.sensorsReader = SensorsReader()
        self.settingsView = Settings("Sensors", list: &self.sensorsReader.list)
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.checkIfNoSensorsEnabled()
        self.popupView.setup(self.sensorsReader.list)
        
        self.settingsView.callback = { [unowned self] in
            self.checkIfNoSensorsEnabled()
            self.sensorsReader.read()
        }
        self.settingsView.setInterval = { [unowned self] value in
            self.sensorsReader.setInterval(value)
        }
        
        self.sensorsReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        self.sensorsReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.addReader(self.sensorsReader)
    }
    
    public override func isAvailable() -> Bool {
        return !self.sensorsReader.list.isEmpty
    }
    
    private func checkIfNoSensorsEnabled() {
        if self.sensorsReader.list.filter({ $0.state }).count == 0 {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.config.name, "state": false])
        }
    }
    
    private func usageCallback(_ raw: [Sensor_t]?) {
        guard let value = raw else {
            return
        }
        
        var list: [KeyValue_t] = []
        value.forEach { (s: Sensor_t) in
            if s.state {
                list.append(KeyValue_t(key: s.key, value: s.formattedMiniValue))
            }
        }
        
        self.popupView.usageCallback(value)
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SensorsWidget: widget.setValues(list)
            default: break
            }
        }
    }
}
