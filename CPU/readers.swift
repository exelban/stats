//
//  readers.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

public class LoadReader: Reader<CPULoad> {
    public var store: UnsafePointer<Store>? = nil
    
    private var cpuInfo: processor_info_array_t!
    private var prevCpuInfo: processor_info_array_t?
    private var numCpuInfo: mach_msg_type_number_t = 0
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    private var numCPUs: uint = 0
    private let CPUUsageLock: NSLock = NSLock()
    private var previousInfo = host_cpu_load_info()
    
    private var result: kern_return_t = 0
    private var response: CPULoad = CPULoad()
    private var numCPUsU: natural_t = 0
    private var usagePerCore: [Double] = []
    
    public override func setup() {
        self.interval = 1500
        let mibKeys: [Int32] = [ CTL_HW, HW_NCPU ]
        
        mibKeys.withUnsafeBufferPointer() { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                numCPUs = 1
            }
        }
    }
    
    public override func read() {
        self.result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &self.numCPUsU, &self.cpuInfo, &self.numCpuInfo);
        
        if self.result == KERN_SUCCESS {
            self.CPUUsageLock.lock()
            
            var inUseOnAllCores: Int32 = 0
            var totalOnAllCores: Int32 = 0
            self.usagePerCore = []
            
            var devider = 2
            if self.store?.pointee.bool(key: "CPU_multithread", defaultValue: false) ?? false {
                devider = 1
            }
            
            for i in stride(from: 0, to: Int32(self.numCPUs), by: devider) {
                var inUse: Int32
                var total: Int32
                if let prevCpuInfo = self.prevCpuInfo {
                    inUse = self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                    total = inUse + (self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)])
                } else {
                    inUse = self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                    total = inUse + self.cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                }

                inUseOnAllCores = inUseOnAllCores + inUse
                totalOnAllCores = totalOnAllCores + total
                if total != 0 {
                    self.usagePerCore.append(Double(inUse) / Double(total))
                }
            }
            
            self.CPUUsageLock.unlock()
            if let prevCpuInfo = self.prevCpuInfo {
                let prevCpuInfoSize: size_t = MemoryLayout<integer_t>.stride * Int(self.numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(prevCpuInfoSize))
            }
            
            self.prevCpuInfo = cpuInfo
            self.numPrevCpuInfo = numCpuInfo
            self.cpuInfo = nil
            self.numCpuInfo = 0
            
            self.response.usagePerCore = self.usagePerCore
        } else {
            print("ERROR host_processor_info(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
        
        let cpuInfo = hostCPULoadInfo()
        if cpuInfo == nil {
            self.callback(nil)
            return
        }
        
        let userDiff = Double(cpuInfo!.cpu_ticks.0 - self.previousInfo.cpu_ticks.0)
        let sysDiff  = Double(cpuInfo!.cpu_ticks.1 - self.previousInfo.cpu_ticks.1)
        let idleDiff = Double(cpuInfo!.cpu_ticks.2 - self.previousInfo.cpu_ticks.2)
        let niceDiff = Double(cpuInfo!.cpu_ticks.3 - self.previousInfo.cpu_ticks.3)
        let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
        
        let system = sysDiff  / totalTicks
        let user = userDiff  / totalTicks
        let idle = idleDiff  / totalTicks
        
        if !system.isNaN {
            self.response.systemLoad  = system
        }
        if !user.isNaN {
            self.response.userLoad = user
        }
        if !idle.isNaN {
            self.response.idleLoad = idle
        }
        self.previousInfo = cpuInfo!
        self.response.totalUsage = self.response.systemLoad + self.response.userLoad
        
        self.callback(self.response)
    }
    
    private func hostCPULoadInfo() -> host_cpu_load_info? {
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        var cpuLoadInfo = host_cpu_load_info()
        
        self.result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        if self.result != KERN_SUCCESS {
            print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
            return nil
        }
        
        return cpuLoadInfo
    }
}
