//
//  main.swift
//  Stats
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
    
    public init(_ store: UnsafePointer<Store>?, _ smc: UnsafePointer<SMCService>) {
        self.sensorsReader = SensorsReader(smc)
        super.init(
            store: store,
            popup: self.popupView,
            settings: nil
        )
        
        self.popupView.setup(self.sensorsReader.list)
        
        self.sensorsReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.sensorsReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        
        self.addReader(self.sensorsReader)
    }
    
    private func usageCallback(_ value: [Sensor_t]?) {
        if value == nil {
            return
        }
        
        self.popupView.usageCallback(value!)
        
        let value_1 = value?.first{ $0.key == "TC0F" }
        let value_2 = value?.first{ $0.key == "TC0P" }
        
        if let widget = self.widget as? SensorsWidget {
            widget.setValues([value_1!.formattedMiniValue, value_2!.formattedMiniValue])
        }
    }
}
