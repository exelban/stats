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

public struct CPULoad {
    var totalUsage: Double = 0
    var usagePerCore: [Double] = []
    
    var systemLoad: Double = 0
    var userLoad: Double = 0
    var idleLoad: Double = 0
}

public class CPU: Module {
    private var loadReader: Reader_p?
    private let popup: Popup = Popup()
    
    private let smc: UnsafeMutablePointer<SMCService>?
    
    public init(menuBarItem: NSStatusItem, smc: UnsafeMutablePointer<SMCService>) throws {
        PG_start()
        self.smc = smc
        super.init(
            name: "CPU",
            icon: nil,
            menuBarItem: menuBarItem,
            defaultWidget: "Mini",
            popup: self.popup
        )
        
        do {
            try self.load()
        } catch {
            throw "failed to load CPU module: \(error.localizedDescription)"
        }
        
        self.loadReader = LoadReader(delegate: self, callback: self.loadCallback, ready: self.readyCallback)
        self.addReader(self.loadReader!)
    }
    
    public override func willTerminate() {
        PG_stop()
    }
    
    private func loadCallback(value: CPULoad?) {
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
            if value == nil {
                return
            }
            
            DispatchQueue.main.async(execute: {
                widget.valueView.stringValue = "\(Int((value?.totalUsage.rounded(toPlaces: 2))! * 100))%"
                widget.valueView.textColor = value?.totalUsage.usageColor(color: widget.color)
            })
        }
    }
}
