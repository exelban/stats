//
//  reader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

struct CPUUsage {
    var value: Double = 0
    var system: Double = 0
    var user: Double = 0
    var idle: Double = 0
}

struct TopProcess {
    var pid: Int = 0
    var command: String = ""
    var usage: Double = 0
}

class CPUReader: Reader {
    public var value: Observable<[Double]>!
    public var usage: Observable<CPUUsage> = Observable(CPUUsage())
    public var processes: Observable<[TopProcess]> = Observable([TopProcess]())
    public var available: Bool = true
    public var updateTimer: Timer!
    public var perCoreMode: Bool = false
    public var hyperthreading: Bool = true
    
    private var cpuInfo: processor_info_array_t!
    private var prevCpuInfo: processor_info_array_t?
    private var numCpuInfo: mach_msg_type_number_t = 0
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    private var numCPUs: uint = 0
    private let CPUUsageLock: NSLock = NSLock()
    private var loadPrevious = host_cpu_load_info()
    
    private var topProcess: Process = Process()
    private var pipe: Pipe = Pipe()
    
    init() {
        let mibKeys: [Int32] = [ CTL_HW, HW_NCPU ]
        self.value = Observable([])
        
        self.topProcess.launchPath = "/usr/bin/top"
        self.topProcess.arguments = ["-s", "3", "-o", "cpu", "-n", "5", "-stats", "pid,command,cpu"]
        self.topProcess.standardOutput = pipe
        
        mibKeys.withUnsafeBufferPointer() { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                numCPUs = 1
            }
            read()
        }
    }
    
    func start() {
        if updateTimer != nil {
            return
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(read), userInfo: nil, repeats: true)
        
        if topProcess.isRunning {
            return
        }
        self.pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: self.pipe.fileHandleForReading , queue: nil) { _ -> Void in
            defer {
                self.pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
            }
            
            let output = self.pipe.fileHandleForReading.availableData
            if output.isEmpty {
                return
            }
            
            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
            var processes: [TopProcess] = []
            outputString.enumerateLines { (line, stop) -> () in
                if line.matches("^\\d+ + .+ +\\d+.\\d *$") {
                    let arr = line.condenseWhitespace().split(separator: " ")
                    let pid = Int(arr[0]) ?? 0
                    let command = String(arr[1])
                    let usage = Double(arr[2]) ?? 0
                    let process = TopProcess(pid: pid, command: command, usage: usage)
                    processes.append(process)
                }
            }
            
            self.processes << processes
        }
        
        do {
            try topProcess.run()
        } catch let error {
            print(error)
        }
    }
    
    func stop() {
        if updateTimer == nil {
            return
        }
        updateTimer.invalidate()
        updateTimer = nil
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSFileHandleDataAvailable, object: nil)
    }
    
    @objc func read() {
        var numCPUsU: natural_t = 0
        let err: kern_return_t = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
        let usage = getUsage()
        
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
            
            if self.perCoreMode {
                self.value << usagePerCore
            } else {
                self.value << [(Double(inUseOnAllCores) / Double(totalOnAllCores))]
            }
            if !usage.system.isNaN && !usage.user.isNaN && !usage.idle.isNaN {
                self.usage << CPUUsage(value: Double(inUseOnAllCores) / Double(totalOnAllCores), system: usage.system, user: usage.user, idle: usage.idle)
            }
            
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
    
    func hostCPULoadInfo() -> host_cpu_load_info? {
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
    
    public func getUsage() -> (system: Double, user: Double, idle : Double) {
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
        
        return (sys, user, idle)
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
