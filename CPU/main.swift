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

public struct CPULoad: value_t {
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

public struct TopProcess {
    var pid: Int = 0
    var command: String = ""
    var usage: Double = 0
}

public class CPU: Module {
    private var loadReader: LoadReader = LoadReader()
    
    private let popup: Popup = Popup()
    private let smc: UnsafePointer<SMCService>?
    
    public init(_ store: UnsafePointer<Store>, _ smc: UnsafePointer<SMCService>) {
        var widgets: [widget_t] = [.mini, .lineChart, .barChart]
        PG_start()
        self.smc = smc
        super.init(
            store: store,
            name: "CPU",
            icon: nil,
            popup: self.popup,
            defaultWidget: .mini,
            widgets: &widgets,
            defaultState: true
        )
        
        self.loadReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.loadReader.callbackHandler = { [unowned self] value in
            self.loadCallback(value)
        }
        
        self.addReader(self.loadReader)
    }
    
    private func loadCallback(_ value: CPULoad?) {
        if value == nil {
            return
        }
        
        let temperature = self.smc?.pointee.getValue("TC0F") ?? self.smc?.pointee.getValue("TC0P") ?? self.smc?.pointee.getValue("TC0H")
        var frequency: Double? = nil
        if let readFrequency = PG_getCPUFrequency() {
            frequency = readFrequency.pointee
        }
        self.popup.loadCallback(value!, freqValue: frequency, tempValue: temperature)
        
        if let widget = self.widget as? Mini {
            widget.setValue(value!.totalUsage, sufix: "%")
        }
        if let widget = self.widget as? LineChart {
            widget.setValue(value!.totalUsage)
        }
    }
}
