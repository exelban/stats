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
import Kit

public class Sensors: Module {
    private var sensorsReader: SensorsReader
    private let popupView: Popup
    private var settingsView: Settings
    
    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "\(self.config.name)_fanValue", defaultValue: "percentage")) ?? .percentage
    }
    
    public init() {
        self.sensorsReader = SensorsReader()
        self.settingsView = Settings("Sensors", list: self.sensorsReader.list)
        self.popupView = Popup()
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.popupView.setup(self.sensorsReader.list)
        
        self.settingsView.callback = { [unowned self] in
            self.sensorsReader.read()
        }
        self.settingsView.setInterval = { [unowned self] value in
            self.sensorsReader.setInterval(value)
        }
        self.settingsView.HIDcallback = { [unowned self] in
            DispatchQueue.global(qos: .background).async {
                self.sensorsReader.HIDCallback()
                DispatchQueue.main.async {
                    self.popupView.setup(self.sensorsReader.list)
                    self.settingsView.setList(list: self.sensorsReader.list)
                }
            }
        }
        self.settingsView.unknownCallback = { [unowned self] in
            DispatchQueue.global(qos: .background).async {
                self.sensorsReader.unknownCallback()
                DispatchQueue.main.async {
                    self.popupView.setup(self.sensorsReader.list)
                    self.settingsView.setList(list: self.sensorsReader.list)
                }
            }
        }
        
        self.sensorsReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        self.sensorsReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.addReader(self.sensorsReader)
    }
    
    public override func willTerminate() {
        guard SMCHelper.shared.isActive() else { return }
        
        self.sensorsReader.list.filter({ $0 is Fan }).forEach { (s: Sensor_p) in
            if let f = s as? Fan, let mode = f.customMode {
                if mode != .automatic {
                    SMCHelper.shared.setFanMode(f.id, mode: FanMode.automatic.rawValue)
                }
            }
        }
    }
    
    public override func isAvailable() -> Bool {
        return !self.sensorsReader.list.isEmpty
    }
    
    private func checkIfNoSensorsEnabled() {
        if self.sensorsReader.list.filter({ $0.state }).isEmpty {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.config.name, "state": false])
        }
    }
    
    private func usageCallback(_ raw: [Sensor_p]?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        var list: [KeyValue_t] = []
        var flatList: [[ColorValue]] = []
        
        value.forEach { (s: Sensor_p) in
            if s.state {
                var value = s.formattedMiniValue
                if let f = s as? Fan {
                    flatList.append([ColorValue(((f.value*100)/f.maxSpeed)/100)])
                    if self.fanValueState == .percentage {
                        value = "\(f.percentage)%"
                    }
                }
                list.append(KeyValue_t(key: s.key, value: value, additional: s.name))
            }
        }
        
        self.popupView.usageCallback(value)
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SensorsWidget: widget.setValues(list)
            case let widget as BarChart: widget.setValue(flatList)
            default: break
            }
        }
    }
}
