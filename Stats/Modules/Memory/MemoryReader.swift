//
//  reader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

struct MemoryUsage {
    var total: Double = 0
    var used: Double = 0
    var free: Double = 0
}

class MemoryReader: Reader {
    public var value: Observable<[Double]>!
    public var usage: Observable<MemoryUsage> = Observable(MemoryUsage())
    public var processes: Observable<[TopProcess]> = Observable([TopProcess]())
    public var available: Bool = true
    public var updateTimer: Timer!
    public var totalSize: Float
    
    private var topProcess: Process = Process()
    private var pipe: Pipe = Pipe()
    
    init() {
        self.value = Observable([])
        var stats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        self.topProcess.launchPath = "/usr/bin/top"
        self.topProcess.arguments = ["-s", "3", "-o", "mem", "-n", "5", "-stats", "pid,command,mem"]
        self.topProcess.standardOutput = pipe
        
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
                if line.matches("^\\d+ + .+ +\\d+.\\d[M\\+\\-]+ *$") {
                    var str = line.trimmingCharacters(in: .whitespaces)
                    let pidString = str.findAndCrop(pattern: "^\\d+")
                    let usageString = str.findAndCrop(pattern: " [0-9]+M(\\+|\\-)*$")
                    var command = str.trimmingCharacters(in: .whitespaces)
                    
                    if let regex = try? NSRegularExpression(pattern: " (\\+|\\-)*$", options: .caseInsensitive) {
                        command = regex.stringByReplacingMatches(in: command, options: [], range: NSRange(location: 0, length:  command.count), withTemplate: "")
                    }
                    
                    let pid = Int(pidString) ?? 0
                    guard let usage = Double(usageString.filter("01234567890.".contains)) else {
                        return
                    }
                    let process = TopProcess(pid: pid, command: command, usage: usage * Double(1024 * 1024))
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
            
            let used = active + wired + compressed
            let free = totalSize - used
            
            self.usage << MemoryUsage(total: Double(totalSize), used: Double(used), free: Double(free))
            self.value << [Double((totalSize - free) / totalSize)]
        }
        else {
            print("Error with host_statistics64(): " + (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
}
