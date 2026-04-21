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
import Darwin
import Kit

@_silgen_name("proc_pid_rusage")
private func proc_pid_rusage_bridge(_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutableRawPointer) -> Int32

internal struct RAMMemoryBreakdown {
    let app: Double
    let wired: Double
    let compressed: Double
    let cache: Double
    let used: Double
    let free: Double
}

internal struct RAMProcessSnapshot {
    let pid: Int
    let name: String
    let usage: Double
}

internal class UsageReader: Reader<RAM_Usage> {
    public var totalSize: Double = 0
    
    public override func setup() {
        var stats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.totalSize = Double(stats.max_mem)
            return
        }
        
        self.totalSize = 0
        error("host_info(): \(String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
    }
    
    public override func read() {
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let active = Double(stats.active_count) * Double(vm_page_size)
            let speculative = Double(stats.speculative_count) * Double(vm_page_size)
            let inactive = Double(stats.inactive_count) * Double(vm_page_size)
            let breakdown = Self.memoryBreakdown(
                totalSize: self.totalSize,
                stats: stats,
                pageSize: Double(vm_page_size)
            )
            let swapins = Int64(stats.swapins)
            let swapouts = Int64(stats.swapouts)
            
            var intSize: size_t = MemoryLayout<uint>.size
            var pressureLevel: Int = 0
            sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &intSize, nil, 0)
            
            var pressureValue: RAMPressure
            switch pressureLevel {
            case 2: pressureValue = .warning
            case 4: pressureValue = .critical
            default: pressureValue = .normal
            }
            
            var stringSize: size_t = MemoryLayout<xsw_usage>.size
            var swap: xsw_usage = xsw_usage()
            sysctlbyname("vm.swapusage", &swap, &stringSize, nil, 0)
            
            self.callback(RAM_Usage(
                total: self.totalSize,
                used: breakdown.used,
                free: breakdown.free,
                
                active: active,
                inactive: inactive,
                wired: breakdown.wired,
                compressed: breakdown.compressed,
                
                app: breakdown.app,
                cache: breakdown.cache,
                
                swap: Swap(
                    total: Double(swap.xsu_total),
                    used: Double(swap.xsu_used),
                    free: Double(swap.xsu_avail)
                ),
                pressure: Pressure(level: pressureLevel, value: pressureValue),
                
                swapins: swapins,
                swapouts: swapouts
            ))
            return
        }
        
        error("host_statistics64(): \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
    }
    
    static func memoryBreakdown(totalSize: Double, stats: vm_statistics64, pageSize: Double) -> RAMMemoryBreakdown {
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let purgeable = Double(stats.purgeable_count) * pageSize
        let external = Double(stats.external_page_count) * pageSize
        let appPages = max(Int64(stats.internal_page_count) - Int64(stats.purgeable_count), 0)
        let app = Double(appPages) * pageSize
        let cache = purgeable + external
        let used = min(max(app + wired + compressed, 0), totalSize)
        let free = max(totalSize - used, 0)
        
        return RAMMemoryBreakdown(
            app: app,
            wired: wired,
            compressed: compressed,
            cache: cache,
            used: used,
            free: free
        )
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private let title: String = "RAM"
    
    private var numberOfProcesses: Int {
        get { Store.shared.int(key: "\(self.title)_processes", defaultValue: 8) }
    }
    
    private var combinedProcesses: Bool{
        get { Store.shared.bool(key: "\(self.title)_combinedProcesses", defaultValue: false) }
    }
    
    private typealias dynGetResponsiblePidFuncType = @convention(c) (CInt) -> CInt
    
    public override func setup() {
        self.popup = true
        self.setInterval(Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: 1))
    }
    
    public override func read() {
        if self.numberOfProcesses == 0 {
            return
        }
        let snapshots = Self.readProcessSnapshots()
        if !snapshots.isEmpty {
            self.callback(Self.buildTopProcessList(
                from: snapshots,
                combined: self.combinedProcesses,
                limit: self.numberOfProcesses
            ))
            return
        }
        
        let fallbackProcesses = Self.readTopProcesses(
            arguments: self.combinedProcesses ?
                ["-l", "1", "-o", "mem", "-stats", "pid,command,mem"] :
                ["-l", "1", "-o", "mem", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,mem"],
            log: self.log
        )
        guard !fallbackProcesses.isEmpty else { return }
        
        let fallbackSnapshots = fallbackProcesses.map {
            RAMProcessSnapshot(pid: $0.pid, name: $0.name, usage: $0.usage)
        }
        self.callback(Self.buildTopProcessList(
            from: fallbackSnapshots,
            combined: self.combinedProcesses,
            limit: self.numberOfProcesses
        ))
    }
    
    private static let dynGetResponsiblePidFunc: UnsafeMutableRawPointer? = {
        let result = dlsym(UnsafeMutableRawPointer(bitPattern: -1), "responsibility_get_pid_responsible_for_pid")
        if result == nil {
            error("Error loading responsibility_get_pid_responsible_for_pid")
        }
        return result
    }()
    
    static func getResponsiblePid(_ childPid: Int) -> Int {
        guard ProcessReader.dynGetResponsiblePidFunc != nil else {
            return childPid
        }
        let responsiblePid = unsafeBitCast(ProcessReader.dynGetResponsiblePidFunc, to: dynGetResponsiblePidFuncType.self)(CInt(childPid))
        guard responsiblePid != -1 else {
            return childPid
        }
        return Int(responsiblePid)
    }
    
    static func localizedAppName(pid: Int) -> String? {
        NSRunningApplication(processIdentifier: pid_t(pid))?.localizedName
    }
    
    static func executablePath(pid: Int) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid_t(pid), &pathBuffer, UInt32(pathBuffer.count))
        guard length > 0 else {
            return nil
        }
        let path = String(cString: pathBuffer)
        return path.isEmpty ? nil : path
    }
    
    static func processName(pid: Int, executablePath: String? = nil) -> String {
        if let executablePath {
            let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
            if !executableName.isEmpty {
                return executableName
            }
        }
        
        var nameBuffer = [CChar](repeating: 0, count: 1024)
        let length = proc_name(pid_t(pid), &nameBuffer, UInt32(nameBuffer.count))
        guard length > 0 else {
            return "\(pid)"
        }
        
        let name = String(cString: nameBuffer)
        return name.isEmpty ? "\(pid)" : name
    }
    
    static func bestProcessName(
        pid: Int,
        fallbackName: String,
        executablePath: String? = nil,
        preferAppName: Bool,
        appNameProvider: ((Int) -> String?) = ProcessReader.localizedAppName
    ) -> String {
        if fallbackName.contains("com.apple.Virtua"), let appName = appNameProvider(pid), appName.contains("Docker") {
            return "Docker"
        }
        
        if preferAppName, let appName = appNameProvider(pid), !appName.isEmpty {
            return appName
        }
        
        if let executablePath {
            let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
            if !executableName.isEmpty && executableName.count >= fallbackName.count {
                return executableName
            }
        }
        
        if !fallbackName.isEmpty {
            return fallbackName
        }
        
        return appNameProvider(pid) ?? "\(pid)"
    }
    
    static func buildTopProcessList(
        from snapshots: [RAMProcessSnapshot],
        combined: Bool,
        limit: Int,
        responsiblePidProvider: ((Int) -> Int) = ProcessReader.getResponsiblePid,
        appNameProvider: ((Int) -> String?) = ProcessReader.localizedAppName
    ) -> [TopProcess] {
        let sortedSnapshots = snapshots.sorted { $0.usage > $1.usage }
        guard combined else {
            return Array(sortedSnapshots.prefix(limit)).map {
                TopProcess(pid: $0.pid, name: $0.name, usage: $0.usage)
            }
        }
        
        var processGroups: [Int: [RAMProcessSnapshot]] = [:]
        sortedSnapshots.forEach { snapshot in
            let responsiblePid = responsiblePidProvider(snapshot.pid)
            processGroups[responsiblePid, default: []].append(snapshot)
        }
        
        let result = processGroups.map { (responsiblePid, group) in
            let totalUsage = group.reduce(0) { $0 + $1.usage }
            let fallbackName = group.first(where: { $0.pid == responsiblePid })?.name ?? group.first?.name ?? "\(responsiblePid)"
            return TopProcess(
                pid: responsiblePid,
                name: bestProcessName(
                    pid: responsiblePid,
                    fallbackName: fallbackName,
                    preferAppName: true,
                    appNameProvider: appNameProvider
                ),
                usage: totalUsage
            )
        }
        
        return Array(result.sorted { $0.usage > $1.usage }.prefix(limit))
    }
    
    private static func readProcessSnapshots() -> [RAMProcessSnapshot] {
        let processCount = proc_listallpids(nil, 0)
        guard processCount > 0 else {
            return []
        }
        
        var pids = [pid_t](repeating: 0, count: Int(processCount))
        let written = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard written > 0 else {
            return []
        }
        
        var snapshots: [RAMProcessSnapshot] = []
        snapshots.reserveCapacity(Int(written) + 1)
        
        pids.prefix(Int(written)).forEach { pid in
            guard pid > 0, let snapshot = self.readProcessSnapshot(pid: Int(pid)) else {
                return
            }
            snapshots.append(snapshot)
        }
        
        if let kernelTask = self.kernelTaskSnapshot() {
            snapshots.append(kernelTask)
        }
        
        return snapshots
    }
    
    private static func readProcessSnapshot(pid: Int) -> RAMProcessSnapshot? {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pid_rusage_bridge(pid_t(pid), RUSAGE_INFO_CURRENT, UnsafeMutableRawPointer(pointer))
        }
        guard result == 0, info.ri_phys_footprint > 0 else {
            return nil
        }
        
        let executablePath = self.executablePath(pid: pid)
        let fallbackName = self.processName(pid: pid, executablePath: executablePath)
        let name = self.bestProcessName(
            pid: pid,
            fallbackName: fallbackName,
            executablePath: executablePath,
            preferAppName: false
        )
        
        return RAMProcessSnapshot(pid: pid, name: name, usage: Double(info.ri_phys_footprint))
    }
    
    private static func kernelTaskSnapshot() -> RAMProcessSnapshot? {
        let processes = self.readTopProcesses(arguments: ["-l", "1", "-pid", "0", "-stats", "pid,command,mem"])
        guard let process = processes.first(where: { $0.pid == 0 }) else {
            return nil
        }
        return RAMProcessSnapshot(pid: process.pid, name: process.name, usage: process.usage)
    }
    
    private static func readTopProcesses(arguments: [String], log: NextLog? = nil) -> [TopProcess] {
        let task = Process()
        task.launchPath = "/usr/bin/top"
        task.arguments = arguments
        
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
            if let log {
                error("top(): \(err.localizedDescription)", log: log)
            }
            return []
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)
        _ = String(data: errorData, encoding: .utf8)
        guard let output, !output.isEmpty else {
            return []
        }
        
        var processes: [TopProcess] = []
        output.enumerateLines { (line, _) in
            if line.matches("^\\d+\\** +.* +\\d+[A-Z]*\\+?\\-? *$") {
                processes.append(ProcessReader.parseProcess(line))
            }
        }
        
        return processes
    }
    
    static public func parseProcess(_ raw: String) -> TopProcess {
        var str = raw.trimmingCharacters(in: .whitespaces)
        let pidString = str.find(pattern: "^\\d+")
        
        if let range = str.range(of: pidString) {
            str = str.replacingCharacters(in: range, with: "")
        }
        
        var arr = str.split(separator: " ")
        if arr.first == "*" {
            arr.removeFirst()
        }
        
        var usageString = str.suffix(6)
        if let lastElement = arr.last {
            usageString = lastElement
            arr.removeLast()
        }
        
        var command = arr.joined(separator: " ")
            .replacingOccurrences(of: pidString, with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if let regex = try? NSRegularExpression(pattern: " (\\+|\\-)*$", options: .caseInsensitive) {
            command = regex.stringByReplacingMatches(in: command, options: [], range: NSRange(location: 0, length: command.count), withTemplate: "")
        }
        
        let pid = Int(pidString.filter("01234567890.".contains)) ?? 0
        var usage = Double(usageString.filter("01234567890.".contains)) ?? 0
        if usageString.last == "G" {
            usage *= 1024 // apply gigabyte multiplier
        } else if usageString.last == "K" {
            usage /= 1024 // apply kilobyte divider
        } else if usageString.last == "M" && usageString.count == 5 {
            usage /= 1024
            usage *= 1000
        }
        
        let name = bestProcessName(pid: pid, fallbackName: command, preferAppName: false)
        
        return TopProcess(pid: pid, name: name, usage: usage * Double(1000 * 1000))
    }
}
