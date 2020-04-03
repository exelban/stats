//
//  RAMUsageReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

struct RAMUsage {
    var usage: Double = 0
    var total: Double = 0
    var used: Double = 0
    var free: Double = 0
}

class RAMUsageReader: Reader {
    public var name: String = "Usage"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    public var callback: (RAMUsage) -> Void = {_ in}
    
    public var totalSize: Float = 0
    public var usage: RAMUsage = RAMUsage()
    
    init(_ updater: @escaping (RAMUsage) -> Void) {
        self.callback = updater
        
        var stats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.totalSize = Float(stats.max_mem)
        }
        else {
            self.totalSize = 0
            print("Error with host_info(): " + (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
        
        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
    }
    
    func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let active = Float(stats.active_count) * Float(PAGE_SIZE)
//            let inactive = Float(stats.inactive_count) * Float(PAGE_SIZE)
            let wired = Float(stats.wire_count) * Float(PAGE_SIZE)
            let compressed = Float(stats.compressor_page_count) * Float(PAGE_SIZE)
                    
            let used = active + wired + compressed
            let free = totalSize - used

            DispatchQueue.main.async(execute: {
                self.usage = RAMUsage(usage: Double((self.totalSize - free) / self.totalSize), total: Double(self.totalSize), used: Double(used), free: Double(free))
                self.callback(self.usage)
            })
        } else {
            print("Error with host_statistics64(): " + (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
    
    func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
}
