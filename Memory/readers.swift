//
//  readers.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 12/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit

public class UsageReader: Reader<MemoryUsage> {
    public var totalSize: Float = 0
    
    public override func setup() {
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
    }
    
    public override func read() {
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
            let free = self.totalSize - used
            
            self.callback(MemoryUsage(usage: Double((self.totalSize - free) / self.totalSize), total: Double(self.totalSize), used: Double(used), free: Double(free)))
        } else {
            print("Error with host_statistics64(): " + (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
}
