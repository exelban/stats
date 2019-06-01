//
//  reader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

class MemoryReader: Reader {
    var usage: Observable<Float>!
    var updateTimer: Timer!
    var totalSize: Float
    
    init() {
        self.usage = Observable(0)
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
        
        read()
    }
    
    func start() {
        if updateTimer != nil {
            return
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(read), userInfo: nil, repeats: true)
    }
    
    func stop() {
        if updateTimer == nil {
            return
        }
        updateTimer.invalidate()
        updateTimer = nil
    }
    
    @objc func read() {
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
            
            let free = totalSize - (active + wired + compressed)
            self.usage << ((totalSize - free) / totalSize)
        }
        else {
            print("Error with host_statistics64(): " + (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
}
