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
import StatsKit
import ModuleKit
import os.log

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
        os_log(.error, log: log, "host_info(): %s", "\((String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))")
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
            let inactive = Double(stats.inactive_count) * Double(vm_page_size)
            let wired = Double(stats.wire_count) * Double(vm_page_size)
            let compressed = Double(stats.compressor_page_count) * Double(vm_page_size)
            
            let used = active + wired + compressed
            let free = self.totalSize - used
            
            var size: size_t = MemoryLayout<uint>.size
            var pressureLevel: Int = 0
            sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0)
            
            self.callback(RAM_Usage(
                active: active,
                inactive: inactive,
                wired: wired,
                compressed: compressed,
                
                usage: Double((self.totalSize - free) / self.totalSize),
                total: Double(self.totalSize),
                used: Double(used),
                free: Double(free),
                
                pressureLevel: pressureLevel
            ))
            return
        }
        
        os_log(.error, log: log, "host_statistics64(): %s", "\((String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))")
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private let store: UnsafePointer<Store>
    private let title: String
    
    private var numberOfProcesses: Int {
        get {
            return self.store.pointee.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    
    init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        super.init()
    }
    
    public override func setup() {
        self.popup = true
    }
    
    public override func read() {
        let task = Process()
        task.launchPath = "/usr/bin/top"
        task.arguments = ["-l", "1", "-o", "mem", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,mem"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let error {
            os_log(.error, log: log, "top(): %s", "\(error.localizedDescription)")
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
        output.enumerateLines { (line, _) -> () in
            if line.matches("^\\d+ +.* +\\d+[A-Z]* *$") {
                let str = line.trimmingCharacters(in: .whitespaces)
                let pidString = str.prefix(6)
                let startIndex = str.index(str.startIndex, offsetBy: 6)
                let endIndex = str.index(str.startIndex, offsetBy: 22)
                var command = String(str[startIndex...endIndex])
                let usageString = str.suffix(5)
                
                if let regex = try? NSRegularExpression(pattern: " (\\+|\\-)*$", options: .caseInsensitive) {
                    command = regex.stringByReplacingMatches(in: command, options: [], range: NSRange(location: 0, length:  command.count), withTemplate: "")
                }
                
                let pid = Int(pidString.filter("01234567890.".contains)) ?? 0
                let usage = Double(usageString.filter("01234567890.".contains)) ?? 0
                
                var name: String? = nil
                var icon: NSImage? = nil
                if let app = NSRunningApplication(processIdentifier: pid_t(pid) ) {
                    name = app.localizedName ?? nil
                    icon = app.icon
                }
                
                let process = TopProcess(pid: pid, command: command, name: name, usage: usage * Double(1024 * 1024), icon: icon)
                processes.append(process)
            }
        }
        
        self.callback(processes)
    }
}
