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
import Kit

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
            let wired = Double(stats.wire_count) * Double(vm_page_size)
            let compressed = Double(stats.compressor_page_count) * Double(vm_page_size)
            let purgeable = Double(stats.purgeable_count) * Double(vm_page_size)
            let external = Double(stats.external_page_count) * Double(vm_page_size)
            let swapins = Int64(stats.swapins)
            let swapouts = Int64(stats.swapouts)
            
            let used = active + inactive + speculative + wired + compressed - purgeable - external
            let free = self.totalSize - used
            
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
                used: used,
                free: free,
                
                active: active,
                inactive: inactive,
                wired: wired,
                compressed: compressed,
                
                app: used - wired - compressed,
                cache: purgeable + external,
                
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
            self.callback([])
            return
        }

        let processes = ProcessReader.fetchProcesses(
            limit: self.combinedProcesses ? nil : self.numberOfProcesses,
            log: self.log
        )
        if !self.combinedProcesses {
            self.callback(processes)
            return
        }

        let result = ProcessReader.combineProcesses(processes)
        self.callback(Array(result.prefix(self.numberOfProcesses)))
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

    static func selection(for process: TopProcess, mode: ProcessMemoryTrackMode) -> ProcessMemorySelection {
        let responsiblePid = self.getResponsiblePid(process.pid)

        switch mode {
        case .process:
            return ProcessMemorySelection(
                pid: process.pid,
                responsiblePid: responsiblePid,
                name: process.name,
                bundleIdentifier: self.bundleIdentifier(for: process.pid),
                mode: .process
            )
        case .application:
            let name = self.applicationName(for: responsiblePid, fallback: process.name)
            return ProcessMemorySelection(
                pid: process.pid,
                responsiblePid: responsiblePid,
                name: name,
                bundleIdentifier: self.bundleIdentifier(for: responsiblePid),
                mode: .application
            )
        }
    }

    static func fetchProcesses(limit: Int? = nil, log: NextLog = NextLog.shared) -> [TopProcess] {
        let task = Process()
        task.launchPath = "/usr/bin/top"

        var arguments = ["-l", "1", "-o", "mem"]
        if let limit {
            arguments += ["-n", "\(limit)"]
        }
        arguments += ["-stats", "pid,command,mem"]
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
            error("top(): \(err.localizedDescription)", log: log)
            return []
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)
        _ = String(data: errorData, encoding: .utf8)
        guard let output, !output.isEmpty else { return [] }

        var processes: [TopProcess] = []
        output.enumerateLines { line, _ in
            if line.matches("^\\d+\\** +.* +\\d+[A-Z]*\\+?\\-? *$") {
                processes.append(ProcessReader.parseProcess(line))
            }
        }

        return processes
    }

    static func combineProcesses(_ processes: [TopProcess]) -> [TopProcess] {
        var processGroups: [String: [TopProcess]] = [:]
        for process in processes {
            let responsiblePid = self.getResponsiblePid(process.pid)
            let groupKey = "\(responsiblePid)"

            if processGroups[groupKey] != nil {
                processGroups[groupKey]!.append(process)
            } else {
                processGroups[groupKey] = [process]
            }
        }

        var result: [TopProcess] = []
        for (_, processes) in processGroups {
            let totalUsage = processes.reduce(0) { $0 + $1.usage }
            let firstProcess = processes.first!
            let responsiblePid = self.getResponsiblePid(firstProcess.pid)
            let name = self.applicationName(for: responsiblePid, fallback: firstProcess.name)

            result.append(TopProcess(
                pid: responsiblePid,
                name: name,
                usage: totalUsage
            ))
        }

        return result.sorted { $0.usage > $1.usage }
    }

    static func trackedProcess(for selection: ProcessMemorySelection, in processes: [TopProcess]) -> TopProcess? {
        switch selection.mode {
        case .application:
            let combined = self.combineProcesses(processes)
            if let process = combined.first(where: { $0.pid == selection.responsiblePid }) {
                return process
            }
            if let bundleIdentifier = selection.bundleIdentifier,
               let process = combined.first(where: { self.bundleIdentifier(for: $0.pid) == bundleIdentifier }) {
                return process
            }
            return combined.first(where: { $0.name == selection.name })
        case .process:
            if let process = processes.first(where: { $0.pid == selection.pid }) {
                return process
            }
            if let bundleIdentifier = selection.bundleIdentifier {
                let matches = processes.filter { self.bundleIdentifier(for: $0.pid) == bundleIdentifier }
                if matches.count == 1 {
                    return matches[0]
                }
            }
            let matches = processes.filter { $0.name == selection.name }
            return matches.count == 1 ? matches[0] : nil
        }
    }

    static func bundleIdentifier(for pid: Int) -> String? {
        NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier
    }

    private static func applicationName(for pid: Int, fallback: String) -> String {
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)),
           let name = app.localizedName,
           !name.isEmpty {
            return name
        }
        return fallback
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
        
        var name: String = command
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)), let n = app.localizedName {
            name = n
        }
        
        if command.contains("com.apple.Virtua") && name.contains("Docker") {
            name = "Docker"
        }
        
        return TopProcess(pid: pid, name: name, usage: usage * Double(1000 * 1000))
    }
}

public class PinnedProcessReader: Reader<TrackedProcessMemory> {
    private let title: String = "RAM"

    public override func setup() {
        self.optional = true
        self.setInterval(Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: 1))
    }

    public override func read() {
        guard let selection = ProcessMemorySelection.load(module: self.title) else { return }

        let processes = ProcessReader.fetchProcesses(log: self.log)
        let process = ProcessReader.trackedProcess(for: selection, in: processes)

        self.callback(TrackedProcessMemory(
            selection: selection,
            pid: process?.pid,
            name: process?.name ?? selection.displayName,
            usage: process?.usage,
            bundleIdentifier: process.flatMap { ProcessReader.bundleIdentifier(for: $0.pid) } ?? selection.bundleIdentifier
        ))
    }
}
