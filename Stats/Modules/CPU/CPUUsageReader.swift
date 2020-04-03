//
//  CPUUsageReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 13/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

struct CPUUsage {
    var system: Double = 0
    var user: Double = 0
    var idle: Double = 0
}

class CPUUsageReader: Reader {
    public var name: String = "Usage"
    public var enabled: Bool = false
    public var available: Bool = true
    public var optional: Bool = true
    public var initialized: Bool = false
    public var callback: (CPUUsage) -> Void = {_ in}
    
    private var loadPrevious = host_cpu_load_info()
    
    init(_ updater: @escaping (CPUUsage) -> Void) {
        self.callback = updater
        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
    
    public func read() {
        if !self.enabled && self.initialized { return }
        
        let load = hostCPULoadInfo()
        let userDiff = Double(load!.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let sysDiff  = Double(load!.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let idleDiff = Double(load!.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let niceDiff = Double(load!.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        
        let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
        
        let sys  = sysDiff  / totalTicks * 100.0
        let user = userDiff / totalTicks * 100.0
        let idle = idleDiff / totalTicks * 100.0
        
        self.loadPrevious = load!
        self.initialized = true
        
        if !sys.isNaN && !user.isNaN && !idle.isNaN {
            DispatchQueue.main.async(execute: {
                self.callback(CPUUsage(system: sys, user: user, idle: idle))
            })
        }
    }
    
    private func hostCPULoadInfo() -> host_cpu_load_info? {
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        if result != KERN_SUCCESS {
            print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
            return nil
        }
        
        return cpuLoadInfo
    }
}
