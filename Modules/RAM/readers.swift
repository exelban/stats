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
            
            let used = active + inactive + speculative + wired + compressed - purgeable - external
            let free = self.totalSize - used
            
            var intSize: size_t = MemoryLayout<uint>.size
            var pressureLevel: Int = 0
            sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &intSize, nil, 0)
            
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
                pressure: 100.0 * (wired + compressed) / self.totalSize,
                
                rawPressureLevel: UInt(pressureLevel),
                
                swap: Swap(
                    total: Double(swap.xsu_total),
                    used: Double(swap.xsu_used),
                    free: Double(swap.xsu_avail)
                )
            ))
            return
        }
        
        error("host_statistics64(): \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private let title: String = "RAM"
    
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
        task.launchPath = "/usr/bin/top"
        task.arguments = ["-l", "1", "-o", "mem", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,mem"]
        
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
            error("top(): \(err.localizedDescription)", log: self.log)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        _ = String(decoding: errorData, as: UTF8.self)
        
        if output.isEmpty {
            return
        }
        
        var processes: [TopProcess] = []
        output.enumerateLines { (line, _) -> Void in
            if line.matches("^\\d+\\** +.* +\\d+[A-Z]*\\+?\\-? *$") {
                processes.append(ProcessReader.parseProcess(line))
            }
        }
        
        self.callback(processes)
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
        }
        
        var name: String = command
        if let app = NSRunningApplication(processIdentifier: pid_t(pid) ) {
            name = app.localizedName ?? command
        }
        
        return TopProcess(pid: pid, command: command, name: name, usage: usage * Double(1024 * 1024))
    }
}
