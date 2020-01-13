//
//  CPUUsageReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 13/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class CPULoadReader: Reader {
    public var name: String = "Load"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    public var callback: ([Double]) -> Void = {_ in}
    public var chartCallback: (Double) -> Void = {_ in}
    
    public var perCoreMode: Bool = true
    public var hyperthreading: Bool = false
    
    private var cpuInfo: processor_info_array_t!
    private var prevCpuInfo: processor_info_array_t?
    private var numCpuInfo: mach_msg_type_number_t = 0
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    private var numCPUs: uint = 0
    private let CPUUsageLock: NSLock = NSLock()
    private var loadPrevious = host_cpu_load_info()
    
    init(_ name: String, _ updater: @escaping ([Double]) -> Void, _ chartUpdater: @escaping (Double) -> Void, _ coreMode: Bool = false) {
        self.callback = updater
        self.chartCallback = chartUpdater
        self.perCoreMode = coreMode
        self.hyperthreading = UserDefaults.standard.object(forKey: "\(name)_hyperthreading") != nil ? UserDefaults.standard.bool(forKey: "\(name)_hyperthreading") : false
        
        let mibKeys: [Int32] = [ CTL_HW, HW_NCPU ]
        
        mibKeys.withUnsafeBufferPointer() { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                numCPUs = 1
            }
        }
        
        if self.available {
            self.read()
        }
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
    
    public func read() {
        if !self.enabled && self.initialized { return }
        
        var numCPUsU: natural_t = 0
        let err: kern_return_t = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
        
        if err == KERN_SUCCESS {
            CPUUsageLock.lock()

            var inUseOnAllCores: Int32 = 0
            var totalOnAllCores: Int32 = 0
            var usagePerCore: [Double] = []

            var incrementNumber = 1
            if !self.hyperthreading && self.perCoreMode {
                incrementNumber = 2
            }

            for i in stride(from: 0, to: Int32(numCPUs), by: incrementNumber) {
                var inUse: Int32
                var total: Int32
                if let prevCpuInfo = prevCpuInfo {
                    inUse = cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                        total = inUse + (cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)])
                } else {
                    inUse = cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                            total = inUse + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                }

                inUseOnAllCores = inUseOnAllCores + inUse
                totalOnAllCores = totalOnAllCores + total
                if total != 0 {
                    usagePerCore.append(Double(inUse) / Double(total))
                }
            }
            
            DispatchQueue.main.async(execute: {
                if self.perCoreMode {
                    self.callback(usagePerCore)
                } else {
                    self.callback([(Double(inUseOnAllCores) / Double(totalOnAllCores))])
                }
                self.chartCallback(Double(inUseOnAllCores) / Double(totalOnAllCores))
            })
            
            CPUUsageLock.unlock()

            if let prevCpuInfo = prevCpuInfo {
                let prevCpuInfoSize: size_t = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(prevCpuInfoSize))
            }

            prevCpuInfo = cpuInfo
            numPrevCpuInfo = numCpuInfo

            cpuInfo = nil
            numCpuInfo = 0
        } else {
            print("Error KERN_SUCCESS!")
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
