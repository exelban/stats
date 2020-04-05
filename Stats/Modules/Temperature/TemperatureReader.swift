//
//  TemperatureReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import IOKit
import Foundation

class TemperatureReader: Reader {
    public var name: String = "Temperature"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    
    public var callback: (Temperatures) -> Void = {_ in}
    
    init(_ updater: @escaping (Temperatures) -> Void) {
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
        
        var temperatures: Temperatures = Temperatures()
        GetTemperatures(&temperatures)

        self.callback(temperatures)
    }
    
    func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
}
