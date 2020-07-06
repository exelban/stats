//
//  main.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit
import IOKit.ps

struct Battery_Usage: value_t {
    var powerSource: String = ""
    var state: String = ""
    var isCharged: Bool = false
    var level: Double = 0
    var cycles: Int = 0
    var health: Int = 0
    
    var amperage: Int = 0
    var voltage: Double = 0
    var temperature: Double = 0
    
    var ACwatts: Int = 0
    var ACstatus: Bool = true
    
    var timeToEmpty: Int = 0
    var timeToCharge: Int = 0
    
    public var widget_value: Double {
        get {
            return self.level
        }
    }
}

public class Battery: Module {
    private var usageReader: UsageReader? = nil
    private let popupView: Popup = Popup()
    
    public init(_ store: UnsafePointer<Store>?) {
        super.init(
            store: store,
            popup: self.popupView,
            settings: nil
        )
        guard self.available else { return }
        
        self.usageReader = UsageReader()
        
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        
        if let reader = self.usageReader {
            self.addReader(reader)
        }
    }
    
    public override func isAvailable() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        return sources.count > 0
    }
    
    private func usageCallback(_ value: Battery_Usage?) {
        if value == nil {
            return
        }
        
        self.popupView.usageCallback(value!)
        if let widget = self.widget as? Mini {
            widget.setValue(abs(value!.level), sufix: "%")
        }
        if let widget = self.widget as? BatterykWidget {
            widget.setValue(
                percentage: value?.level ?? 0,
                isCharging: value?.level == 100 ? true : value!.level > 0,
                time: (value?.timeToEmpty == 0 && value?.timeToCharge != 0 ? value?.timeToCharge : value?.timeToEmpty) ?? 0
            )
        }
    }
}
