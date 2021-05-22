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
import os.log

internal class LoadReader: Reader<CPU_Load> {
    private var cpuInfo: processor_info_array_t!
    private var prevCpuInfo: processor_info_array_t?
    private var numCpuInfo: mach_msg_type_number_t = 0
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    private var numCPUs: uint = 0
    private let CPUUsageLock: NSLock = NSLock()
    private var previousInfo = host_cpu_load_info()
    private var hasHyperthreadingCores = false
    
    private var response: CPU_Load = CPU_Load()
    private var numCPUsU: natural_t = 0
    private var usagePerCore: [Double] = []
    
    public override func setup() {
        self.hasHyperthreadingCores = sysctlByName("hw.physicalcpu") != sysctlByName("hw.logicalcpu")
        [CTL_HW, HW_NCPU].withUnsafeBufferPointer { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                self.numCPUs = 1
            }
        }
    }
    
    // swiftlint:disable function_body_length
    public override func read() {
        let result: kern_return_t = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &self.numCPUsU, &self.cpuInfo, &self.numCpuInfo)
        if result == KERN_SUCCESS {
            self.CPUUsageLock.lock()
            self.usagePerCore = []
            
            for i in 0 ..< Int32(numCPUs) {
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
                
                if total != 0 {
                    self.usagePerCore.append(Double(inUse) / Double(total))
                }
            }
            self.CPUUsageLock.unlock()
            
            let showHyperthratedCores = Store.shared.bool(key: "CPU_hyperhreading", defaultValue: false) 
            if showHyperthratedCores || !self.hasHyperthreadingCores {
                self.response.usagePerCore = self.usagePerCore
            } else {
                var i = 0
                var a = 0
                
                self.response.usagePerCore = []
                while i < Int(self.usagePerCore.count/2) {
                    a = i*2
                    if self.usagePerCore.indices.contains(a) && self.usagePerCore.indices.contains(a+1) {
                        self.response.usagePerCore.append((Double(self.usagePerCore[a]) + Double(self.usagePerCore[a+1])) / 2)
                    }
                    i += 1
                }
            }
            
            if let prevCpuInfo = self.prevCpuInfo {
                let prevCpuInfoSize: size_t = MemoryLayout<integer_t>.stride * Int(self.numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(prevCpuInfoSize))
            }
            
            self.prevCpuInfo = self.cpuInfo
            self.numPrevCpuInfo = self.numCpuInfo
            
            self.cpuInfo = nil
            self.numCpuInfo = 0
        } else {
            os_log(.error, log: log, "host_processor_info(): %s", "\((String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))")
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
        let count = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(count)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: count) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        if result != KERN_SUCCESS {
            os_log(.error, log: log, "kern_result_t: %s", "\(result)")
            return nil
        }
        
        return cpuLoadInfo
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private let title: String = "CPU"
    
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    
    public override func setup() {
        self.popup = true
    }
    
    public override func read() {
        if self.numberOfProcesses == 0 {
            return
        }
        
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-Aceo pid,pcpu,comm", "-r"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let error {
            os_log(.error, log: log, "error read ps: %s", "\(error.localizedDescription)")
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        _ = String(decoding: errorData, as: UTF8.self)
        
        if output.isEmpty {
            return
        }
        
        var index = 0
        var processes: [TopProcess] = []
        output.enumerateLines { (line, stop) -> Void in
            if index != 0 {
                var str = line.trimmingCharacters(in: .whitespaces)
                let pidString = str.findAndCrop(pattern: "^\\d+")
                let usageString = str.findAndCrop(pattern: "^[0-9,.]+ ")
                let command = str.trimmingCharacters(in: .whitespaces)
                
                let pid = Int(pidString) ?? 0
                let usage = Double(usageString.replacingOccurrences(of: ",", with: ".")) ?? 0
                
                var name: String? = nil
                var icon: NSImage? = nil
                if let app = NSRunningApplication(processIdentifier: pid_t(pid) ) {
                    name = app.localizedName ?? nil
                    icon = app.icon
                }
                
                processes.append(TopProcess(pid: pid, command: command, name: name, usage: usage, icon: icon))
            }
            
            if index == self.numberOfProcesses { stop = true }
            index += 1
        }
        
        self.callback(processes)
    }
}

public class TemperatureReader: Reader<Double> {
    public override func read() {
        var temperature: Double? = nil
        
        if let value = SMC.shared.getValue("TC0D"), value < 110 {
            temperature = value
        } else if let value = SMC.shared.getValue("TC0E"), value < 110 {
            temperature = value
        } else if let value = SMC.shared.getValue("TC0F"), value < 110 {
            temperature = value
        } else if let value = SMC.shared.getValue("TC0P"), value < 110 {
            temperature = value
        } else if let value = SMC.shared.getValue("TC0H"), value < 110 {
            temperature = value
        }
        
        self.callback(temperature)
    }
}

// swiftlint:disable identifier_name
public class FrequencyReader: Reader<Double> {
    private typealias PGSample = UInt64
    private typealias UDouble = UnsafeMutablePointer<Double>
    
    private typealias PG_InitializePointerFunction = @convention(c) () -> Bool
    private typealias PG_ShutdownPointerFunction = @convention(c) () -> Bool
    private typealias PG_ReadSamplePointerFunction = @convention(c) (Int, UnsafeMutablePointer<PGSample>) -> Bool
    private typealias PGSample_GetIAFrequencyPointerFunction = @convention(c) (PGSample, PGSample, UDouble, UDouble, UDouble) -> Bool
    private typealias PGSample_ReleasePointerFunction = @convention(c) (PGSample) -> Bool
    
    private var bundle: CFBundle? = nil
    
    private var PG_Initialize: PG_InitializePointerFunction? = nil
    private var PG_Shutdown: PG_ShutdownPointerFunction? = nil
    private var PG_ReadSample: PG_ReadSamplePointerFunction? = nil
    private var PGSample_GetIAFrequency: PGSample_GetIAFrequencyPointerFunction? = nil
    private var PGSample_Release: PGSample_ReleasePointerFunction? = nil
    
    private var sample: PGSample = 0
    private var reconnectAttempt: Int = 0
    
    private var isEnabled: Bool {
        get {
            return Store.shared.bool(key: "CPU_IPG", defaultValue: false)
        }
    }
    
    public override func setup() {
        guard self.isEnabled else { return }
        
        let path: CFString = "/Library/Frameworks/IntelPowerGadget.framework" as CFString
        let bundleURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, CFURLPathStyle.cfurlposixPathStyle, true)
        
        self.bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL)
        if self.bundle == nil {
            os_log(.error, log: log, "IntelPowerGadget framework not found")
            return
        }
        
        if !CFBundleLoadExecutable(self.bundle) {
            os_log(.error, log: log, "failed to load IPG framework")
            return
        }
        
        guard let PG_InitializePointer = CFBundleGetFunctionPointerForName(self.bundle, "PG_Initialize" as CFString) else {
            os_log(.error, log: log, "failed to find PG_Initialize")
            return
        }
        guard let PG_ShutdownPointer = CFBundleGetFunctionPointerForName(self.bundle, "PG_Shutdown" as CFString) else {
            os_log(.error, log: log, "failed to find PG_Shutdown")
            return
        }
        guard let PG_ReadSamplePointer = CFBundleGetFunctionPointerForName(self.bundle, "PG_ReadSample" as CFString) else {
            os_log(.error, log: log, "failed to find PG_ReadSample")
            return
        }
        guard let PGSample_GetIAFrequencyPointer = CFBundleGetFunctionPointerForName(self.bundle, "PGSample_GetIAFrequency" as CFString) else {
            os_log(.error, log: log, "failed to find PGSample_GetIAFrequency")
            return
        }
        guard let PGSample_ReleasePointer = CFBundleGetFunctionPointerForName(self.bundle, "PGSample_Release" as CFString) else {
            os_log(.error, log: log, "failed to find PGSample_Release")
            return
        }
        
        self.PG_Initialize = unsafeBitCast(PG_InitializePointer, to: PG_InitializePointerFunction.self)
        self.PG_Shutdown = unsafeBitCast(PG_ShutdownPointer, to: PG_ShutdownPointerFunction.self)
        self.PG_ReadSample = unsafeBitCast(PG_ReadSamplePointer, to: PG_ReadSamplePointerFunction.self)
        self.PGSample_GetIAFrequency = unsafeBitCast(PGSample_GetIAFrequencyPointer, to: PGSample_GetIAFrequencyPointerFunction.self)
        self.PGSample_Release = unsafeBitCast(PGSample_ReleasePointer, to: PGSample_ReleasePointerFunction.self)
        
        if let initialize = self.PG_Initialize {
            if !initialize() {
                os_log(.error, log: log, "IPG initialization failed")
                return
            }
        }
    }
    
    deinit {
        if let bundle = self.bundle {
            CFBundleUnloadExecutable(bundle)
        }
    }
    
    public override func terminate() {
        if let shutdown = self.PG_Shutdown {
            if !shutdown() {
                os_log(.error, log: log, "IPG shutdown failed")
                return
            }
        }
        
        if let release = self.PGSample_Release {
            if self.sample != 0 {
                _ = release(self.sample)
                return
            }
        }
    }
    
    private func reconnect() {
        if self.reconnectAttempt >= 5 {
            return
        }
        
        self.sample = 0
        self.terminate()
        if let initialize = self.PG_Initialize {
            if !initialize() {
                os_log(.error, log: log, "IPG initialization failed")
                return
            }
        }
        
        self.reconnectAttempt += 1
    }
    
    public override func read() {
        if !self.isEnabled || self.PG_ReadSample == nil || self.PGSample_GetIAFrequency == nil || self.PGSample_Release == nil {
            return
        }
        
        // first sample initlialization
        if self.sample == 0 {
            if !self.PG_ReadSample!(0, &self.sample) {
                os_log(.error, log: log, "read self.sample failed")
            }
            return
        }
        
        var local: PGSample = 0
        
        if !self.PG_ReadSample!(0, &local) {
            self.reconnect()
            os_log(.error, log: log, "read local sample failed")
            return
        }
        
        var value: Double = 0
        var min: Double = 0
        var max: Double = 0
        
        defer {
            if !self.PGSample_Release!(self.sample) {
                os_log(.error, log: log, "release self.sample failed")
            }
            self.sample = local
        }
        
        if !self.PGSample_GetIAFrequency!(self.sample, local, &value, &min, &max) {
            os_log(.error, log: log, "read frequency failed")
            return
        }
        
        self.callback(value)
    }
}
