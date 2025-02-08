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
import Kit

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
    private var cores: [core_s]? = nil
    
    public override func setup() {
        self.hasHyperthreadingCores = sysctlByName("hw.physicalcpu") != sysctlByName("hw.logicalcpu")
        [CTL_HW, HW_NCPU].withUnsafeBufferPointer { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                self.numCPUs = 1
            }
        }
        self.cores = SystemKit.shared.device.info.cpu?.cores
    }
    
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
            error("host_processor_info(): \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
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
        
        if let cores = self.cores {
            let eCoresList: [Double] = cores.filter({ $0.type == .efficiency }).compactMap { (c: core_s) in
                if self.response.usagePerCore.indices.contains(Int(c.id)) {
                    return self.response.usagePerCore[Int(c.id)]
                }
                return 0
            }
            let pCoresList: [Double] = cores.filter({ $0.type == .performance }).compactMap { (c: core_s) in
                if self.response.usagePerCore.indices.contains(Int(c.id)) {
                    return self.response.usagePerCore[Int(c.id)]
                }
                return 0
            }
            
            self.response.usageECores = eCoresList.reduce(0, +)/Double(eCoresList.count)
            self.response.usagePCores = pCoresList.reduce(0, +)/Double(pCoresList.count)
        }
        
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
            error("kern_result_t: \(result)", log: self.log)
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
        self.setInterval(Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: 1))
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
        } catch let err {
            error("error read ps: \(err.localizedDescription)", log: self.log)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)
        _ = String(data: errorData, encoding: .utf8)
        guard let output, !output.isEmpty else { return }
        
        var index = 0
        var processes: [TopProcess] = []
        output.enumerateLines { (line, stop) in
            if index != 0 {
                let str = line.trimmingCharacters(in: .whitespaces)
                let pidFind = str.findAndCrop(pattern: "^\\d+")
                let usageFind = pidFind.remain.findAndCrop(pattern: "^[0-9,.]+ ")
                let command = usageFind.remain.trimmingCharacters(in: .whitespaces)
                let pid = Int(pidFind.cropped) ?? 0
                let usage = Double(usageFind.cropped.replacingOccurrences(of: ",", with: ".")) ?? 0
                
                var name: String = command
                if let app = NSRunningApplication(processIdentifier: pid_t(pid)), let n = app.localizedName {
                    name = n
                }
                
                processes.append(TopProcess(pid: pid, name: name, usage: usage))
            }
            
            if index == self.numberOfProcesses { stop = true }
            index += 1
        }
        
        self.callback(processes)
    }
}

public class TemperatureReader: Reader<Double> {
    var list: [String] = []
    
    public override func setup() {
        switch SystemKit.shared.device.platform {
        case .m1, .m1Pro, .m1Max, .m1Ultra:
            self.list = ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
        case .m2, .m2Pro, .m2Max, .m2Ultra:
        self.list = ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
        case .m3, .m3Pro, .m3Max, .m3Ultra:
            self.list = ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"]
        case .m4, .m4Pro, .m4Max, .m4Ultra:
            self.list = ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
        default: break
        }
    }
    
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
        } else {
            var total: Double = 0
            var counter: Double = 0
            self.list.forEach { (key: String) in
                if let value = SMC.shared.getValue(key) {
                    total += value
                    counter += 1
                }
            }
            if total != 0 && counter != 0 {
                temperature = total / counter
            }
        }
        
        self.callback(temperature)
    }
}

// inspired by https://github.com/shank03/StatsBar/blob/e175aa71c914ce882ce2e90163f3eb18262a8e25/StatsBar/Service/IOReport.swift
public class FrequencyReader: Reader<[Double]> {
    private var eCoreFreqs: [Int32] = []
    private var pCoreFreqs: [Int32] = []
    
    private var channels: CFMutableDictionary? = nil
    private var subscription: IOReportSubscriptionRef? = nil
    private var prev: (samples: CFDictionary, time: TimeInterval)? = nil
    
    private let measurementCount: Int = 4
    
    private struct IOSample {
        let group: String
        let subGroup: String
        let channel: String
        let unit: String
        let delta: CFDictionary
    }
    
    public override func setup() {
        self.eCoreFreqs = SystemKit.shared.device.info.cpu?.eCoreFrequencies ?? []
        self.pCoreFreqs = SystemKit.shared.device.info.cpu?.pCoreFrequencies ?? []
        self.channels = self.getChannels()
        var dict: Unmanaged<CFMutableDictionary>?
        self.subscription = IOReportCreateSubscription(nil, self.channels, &dict, 0, nil)
        dict?.release()
    }
    
    public override func read() {
        guard !self.eCoreFreqs.isEmpty && !self.pCoreFreqs.isEmpty, self.channels != nil, self.subscription != nil else { return }
        let minECoreFreq = Double(self.eCoreFreqs.min() ?? 0)
        let minPCoreFreq = Double(self.pCoreFreqs.min() ?? 0)
        
        Task {
            var eCores: [Double] = []
            var pCores: [Double] = []
            
            for (samples, _) in await self.getSamples() {
                var eCore: [Double] = []
                var pCore: [Double] = []
                
                for sample in samples {
                    guard sample.group == "CPU Stats" else { continue }
                    if sample.channel.starts(with: "ECPU") {
                        eCore.append(self.calculateFrequencies(dict: sample.delta, freqs: self.eCoreFreqs))
                    }
                    if sample.channel.starts(with: "PCPU") {
                        pCore.append(self.calculateFrequencies(dict: sample.delta, freqs: self.pCoreFreqs))
                    }
                }
                
                let eCoresAvgFreq: Double = eCore.isEmpty ? 0 : (eCore.reduce(0.0, { $0 + $1 }) / Double(eCore.count))
                let pCoresAvgFreq: Double = pCore.isEmpty ? 0 : (pCore.reduce(0.0, { $0 + $1 }) / Double(pCore.count))
                eCores.append(max(eCoresAvgFreq, minECoreFreq))
                pCores.append(max(pCoresAvgFreq, minPCoreFreq))
            }
            
            let eFreq: Double = eCores.reduce(0, { $0 + $1 }) / Double(self.measurementCount)
            let pFreq: Double = pCores.reduce(0, { $0 + $1 }) / Double(self.measurementCount)
            
            self.callback([eFreq, pFreq])
        }
    }
    
    private func calculateFrequencies(dict: CFDictionary, freqs: [Int32]) -> Double {
        let items = self.getResidencies(dict: dict)
        guard let offset = items.firstIndex(where: { $0.0 != "IDLE" && $0.0 != "DOWN" && $0.0 != "OFF" }) else { return 0 }
        let usage = items.dropFirst(offset).reduce(0.0) { $0 + Double($1.f) }
        let count = freqs.count
        var avgFreq: Double = 0
        
        for i in 0..<count {
            let key = i + offset
            if !items.indices.contains(key) { continue }
            let percent = usage == 0 ? 0 : Double(items[key].f) / usage
            avgFreq += percent * Double(freqs[i])
        }
        
        return avgFreq
    }
    
    func getResidencies(dict: CFDictionary) -> [(ns: String, f: Int64)] {
        let count = IOReportStateGetCount(dict)
        var res: [(String, Int64)] = []
        
        for i in 0..<count {
            let name = IOReportStateGetNameForIndex(dict, i)?.takeUnretainedValue() ?? ("" as CFString)
            let val = IOReportStateGetResidency(dict, i)
            res.append((name as String, val))
        }
        
        return res
    }
    
    private func getChannels() -> CFMutableDictionary? {
        let channelNames = [
            ("CPU Stats", "CPU Complex Performance States"),
            ("CPU Stats", "CPU Core Performance States")
        ]
        
        var channels: [CFDictionary] = []
        for (gname, sname) in channelNames {
            let channel = IOReportCopyChannelsInGroup(gname as CFString?, sname as CFString?, 0, 0, 0)
            guard let channel = channel?.takeRetainedValue() else { continue }
            channels.append(channel)
        }
        
        let chan = channels[0]
        for i in 1..<channels.count {
            IOReportMergeChannels(chan, channels[i], nil)
        }
        
        let size = CFDictionaryGetCount(chan)
        guard let channel = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, size, chan),
              let chan = channel as? [String: Any], chan["IOReportChannels"] != nil else {
            return nil
        }
        
        return channel
    }
    
    private func getSamples() async -> [([IOSample], TimeInterval)] {
        let duration = 500
        let step = UInt64(duration / self.measurementCount)
        var samples = [([IOSample], TimeInterval)]()
        guard var prev = self.prev ?? self.getSample() else { return samples }
        
        for _ in 0..<self.measurementCount {
            let milliseconds = UInt64(step) * 1_000_000
            try? await Task.sleep(nanoseconds: milliseconds)
            guard let next = self.getSample() else { continue }
            guard let diff = IOReportCreateSamplesDelta(prev.samples, next.samples, nil)?.takeRetainedValue() else {
                continue
            }
            let elapsed = Date(timeIntervalSince1970: next.time).timeIntervalSince(Date(timeIntervalSince1970: prev.time))
            prev = next
            samples.append((self.collectIOSamples(data: diff), max(elapsed, TimeInterval(1))))
        }
        
        self.prev = prev
        return samples
    }
    
    private func getSample() -> (samples: CFDictionary, time: TimeInterval)? {
        guard let sample = IOReportCreateSamples(self.subscription, self.channels, nil)?.takeRetainedValue() else {
            return nil
        }
        return (sample, Date().timeIntervalSince1970)
    }
    
    private func collectIOSamples(data: CFDictionary) -> [IOSample] {
        let dict = data as! [String: Any]
        let items = dict["IOReportChannels"] as! CFArray
        let itemSize = CFArrayGetCount(items)
        
        var samples = [IOSample]()
        
        for index in 0..<itemSize {
            let dict = CFArrayGetValueAtIndex(items, index)
            let item = unsafeBitCast(dict, to: CFDictionary.self)
            
            let group = IOReportChannelGetGroup(item)?.takeUnretainedValue() ?? ("" as CFString)
            let subGroup = IOReportChannelGetSubGroup(item)?.takeUnretainedValue() ?? ("" as CFString)
            let channel = IOReportChannelGetChannelName(item)?.takeUnretainedValue() ?? ("" as CFString)
            let unit = IOReportChannelGetUnitLabel(item)?.takeUnretainedValue() ?? ("" as CFString)
            
            samples.append(IOSample(group: group as String, subGroup: subGroup as String, channel: channel as String, unit: unit as String, delta: item))
        }
        
        return samples
    }
}

public class LimitReader: Reader<CPU_Limit> {
    private var limits: CPU_Limit = CPU_Limit()
    
    public override func read() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "therm"]
        
        let outputPipe = Pipe()
        defer {
            outputPipe.fileHandleForReading.closeFile()
        }
        task.standardOutput = outputPipe
        
        do {
            try task.run()
        } catch let err {
            error("error read pmset: \(err.localizedDescription)", log: self.log)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: outputData, encoding: .utf8) else { return }
        var lines = str.split(separator: "\n")
        guard !lines.isEmpty else { return }
        lines.removeFirst(3)
        
        lines.forEach { (line: Substring) in
            guard let value = Int(line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) else {
                return
            }
            if line.contains("Scheduler") {
                self.limits.scheduler = value
            } else if line.contains("CPUs") {
                self.limits.cpus = value
            } else if line.contains("Speed") {
                self.limits.speed = value
            }
        }
        
        self.callback(self.limits)
    }
}

public class AverageReader: Reader<[Double]> {
    private let title: String = "CPU"
    
    public override func setup() {
        self.setInterval(60)
    }
    
    public override func read() {
        let task = Process()
        task.launchPath = "/usr/bin/uptime"
        
        let outputPipe = Pipe()
        defer {
            outputPipe.fileHandleForReading.closeFile()
        }
        task.standardOutput = outputPipe
        
        do {
            try task.run()
        } catch let err {
            error("error read uptime: \(err.localizedDescription)", log: self.log)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: outputData, encoding: .utf8), let line = raw.split(separator: "\n").first else {
            return
        }
        
        let str = line.trimmingCharacters(in: .whitespaces)
        let strFind = str.findAndCrop(pattern: "(\\d+(.|,)\\d+ *){3}$")
        let strArr = strFind.cropped.split(separator: " ")
        guard strArr.count == 3 else {
            return
        }
        
        var list: [Double] = []
        strArr.forEach { (n: Substring) in
            let value = Double(n.replacingOccurrences(of: ",", with: ".")) ?? 0
            list.append(value)
        }
        
        self.callback(list)
    }
}
