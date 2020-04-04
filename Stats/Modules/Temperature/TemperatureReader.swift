//
//  TemperatureReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import IOKit
import Foundation

struct TemperatureValue {
    var CPUDie: Double = 0
    var CPUProximity: Double = 0
    var GPUDie: Double = 0
    var GPUProximity: Double = 0
}

class TemperatureReader: Reader {
    public var name: String = "Temperature"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    
    public var callback: (TemperatureValue) -> Void = {_ in}
    
    init(_ updater: @escaping (TemperatureValue) -> Void) {
        self.callback = updater
        
        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
    }
    
    func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        let temp = TemperatureValue(
            CPUDie: GetTemperature(SMC_TEMP_CPU_0_DIE.UTF8CString),
            CPUProximity: GetTemperature(SMC_TEMP_CPU_0_PROXIMITY.UTF8CString),
            GPUDie: GetTemperature(SMC_TEMP_GPU_0_DIODE.UTF8CString),
            GPUProximity: GetTemperature(SMC_TEMP_GPU_0_PROXIMITY.UTF8CString)
        )

        self.callback(temp)
    }
    
    func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
}
