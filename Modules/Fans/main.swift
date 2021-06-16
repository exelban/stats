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
import Kit

public struct Fan {
    public let id: Int
    public let name: String
    public let minSpeed: Double
    public let maxSpeed: Double
    public var value: Double
    public var mode: FanMode
    
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
    private var fansReader: FansReader
    private var settingsView: Settings
    private let popupView: Popup
    
    public init() {
        self.fansReader = FansReader()
        self.settingsView = Settings("Fans", list: &self.fansReader.list)
        self.popupView = Popup()
        
        super.init(
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
        
        self.fansReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        self.fansReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.addReader(self.fansReader)
    }
    
    public override func isAvailable() -> Bool {
        return SMC.shared.getValue("FNum") != nil && SMC.shared.getValue("FNum") != 0 && !self.fansReader.list.isEmpty
    }
    
    private func checkIfNoSensorsEnabled() {
        if self.fansReader.list.filter({ $0.state }).isEmpty {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.config.name, "state": false])
        }
    }
    
    private func usageCallback(_ raw: [Fan]?) {
        guard let value = raw else {
            return
        }
        
        self.popupView.usageCallback(value)
        
        let label: Bool = Store.shared.bool(key: "Fans_label", defaultValue: false)
        var list: [KeyValue_t] = []
        var flatList: [Double] = []
        value.forEach { (f: Fan) in
            if f.state {
                let str = label ? "\(f.name.prefix(1).uppercased()): \(Int(f.value))" : f.formattedValue
                list.append(KeyValue_t(key: "Fan#\(f.id)", value: str))
                flatList.append(((f.value*100)/f.maxSpeed)/100)
            }
        }
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SensorsWidget: widget.setValues(list)
            case let widget as BarChart: widget.setValue(flatList)
            default: break
            }
        }
    }
}
