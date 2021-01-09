//
//  readers.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit
import os.log

internal class UsageReader: Reader<Battery_Usage> {
    private var service: io_connect_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
    
    private var source: CFRunLoopSource?
    private var loop: CFRunLoop?
    
    private var usage: Battery_Usage = Battery_Usage()
    
    public override func start() {
        self.active = true
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        self.source = IOPSNotificationCreateRunLoopSource({ (context) in
            guard let ctx = context else {
                return
            }
            
            let watcher = Unmanaged<UsageReader>.fromOpaque(ctx).takeUnretainedValue()
            if watcher.active {
                watcher.read()
            }
        }, context).takeRetainedValue()
        
        self.loop = RunLoop.current.getCFRunLoop()
        CFRunLoopAddSource(self.loop, source, .defaultMode)
        
        self.read()
    }
    
    public override func stop() {
        guard let runLoop = loop, let source = source else {
            return
        }
        
        self.active = false
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
    }
    
    public override func read() {
        let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
        
        if psList.count == 0 {
            return
        }
        
        for ps in psList {
            if let list = IOPSGetPowerSourceDescription(psInfo, ps).takeUnretainedValue() as? Dictionary<String, Any> {
                self.usage.powerSource = list[kIOPSPowerSourceStateKey] as? String ?? "AC Power"
                self.usage.isCharged = list[kIOPSIsChargedKey] as? Bool ?? false
                self.usage.isCharging = self.getBoolValue("IsCharging" as CFString) ?? false
                self.usage.level = Double(list[kIOPSCurrentCapacityKey] as? Int ?? 0) / 100
                
                if let time = list[kIOPSTimeToEmptyKey] as? Int {
                    self.usage.timeToEmpty = Int(time)
                }
                if let time = list[kIOPSTimeToFullChargeKey] as? Int {
                    self.usage.timeToCharge = Int(time)
                }
                
                self.usage.cycles = self.getIntValue("CycleCount" as CFString) ?? 0
                
                let maxCapacity = self.getIntValue("MaxCapacity" as CFString) ?? 1
                let designCapacity = self.getIntValue("DesignCapacity" as CFString) ?? 1
                #if arch(x86_64)
                self.usage.health = (100 * maxCapacity) / designCapacity
                self.usage.state = list[kIOPSBatteryHealthKey] as? String
                #else
                self.usage.health = maxCapacity
                #endif
                
                self.usage.amperage = self.getIntValue("Amperage" as CFString) ?? 0
                self.usage.voltage = self.getVoltage() ?? 0
                self.usage.temperature = self.getTemperature() ?? 0
                
                var ACwatts: Int = 0
                if let ACDetails = IOPSCopyExternalPowerAdapterDetails() {
                    if let ACList = ACDetails.takeUnretainedValue() as? Dictionary<String, Any> {
                        guard let watts = ACList[kIOPSPowerAdapterWattsKey] else {
                            return
                        }
                        ACwatts = Int(watts as! Int)
                    }
                }
                self.usage.ACwatts = ACwatts
                
                self.callback(self.usage)
            }
        }
    }
    
    private func getBoolValue(_ forIdentifier: CFString) -> Bool? {
        if let value = IORegistryEntryCreateCFProperty(self.service, forIdentifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Bool
        }
        return nil
    }
    
    private func getIntValue(_ identifier: CFString) -> Int? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Int
        }
        return nil
    }
    
    private func getDoubleValue(_ identifier: CFString) -> Double? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? Double
        }
        return nil
    }
    
    private func getVoltage() -> Double? {
        if let value = self.getDoubleValue("Voltage" as CFString) {
            return value / 1000.0
        }
        return nil
    }
    
    private func getTemperature() -> Double? {
        if let value = IORegistryEntryCreateCFProperty(self.service, "Temperature" as CFString, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as! Double / 100.0
        }
        return nil
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private var task: Process? = nil
    private var initialized: Bool = false
    
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
    
    public override func start() {
        if !self.initialized {
            DispatchQueue.global().async {
                self.read()
            }
            self.initialized = true
            return
        }
        
        DispatchQueue.global().async {
            self.task = Process()
            let pipe = Pipe()
            
            self.task?.standardOutput = pipe
            self.task?.launchPath = "/usr/bin/top"
            self.task?.arguments = ["-o", "power", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,power"]
            
            pipe.fileHandleForReading.readabilityHandler = { (fileHandle) -> Void in
                let output = String(decoding: fileHandle.availableData, as: UTF8.self)
                var processes: [TopProcess] = []
                
                output.enumerateLines { (line, _) -> () in
                    if line.matches("^\\d* +.+ \\d*.?\\d*$") {
                        var str = line.trimmingCharacters(in: .whitespaces)
                        
                        let pidString = str.findAndCrop(pattern: "^\\d+")
                        let usageString = str.findAndCrop(pattern: " +[0-9]+.*[0-9]*$")
                        let command = str.trimmingCharacters(in: .whitespaces)
                        
                        let pid = Int(pidString) ?? 0
                        guard let usage = Double(usageString.filter("01234567890.".contains)) else {
                            return
                        }
                        
                        var name: String? = nil
                        var icon: NSImage? = nil
                        if let app = NSRunningApplication(processIdentifier: pid_t(pid) ) {
                            name = app.localizedName ?? nil
                            icon = app.icon
                        }
                        
                        processes.append(TopProcess(pid: pid, command: command, name: name, usage: usage, icon: icon))
                    }
                }
                
                if processes.count != 0 {
                    self.callback(processes)
                }
            }

            self.task?.launch()
            self.task?.waitUntilExit()
        }
    }
    
    public override func stop() {
        if self.task == nil || !self.task!.isRunning {
            return
        }
        
        self.task?.interrupt()
        self.task = nil
    }
    
    public override func read() {
        if self.numberOfProcesses == 0 {
            return
        }
        
        let task = Process()
        task.launchPath = "/usr/bin/top"
        task.arguments = ["-l", "1", "-o", "power", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,power"]
        
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
            if line.matches("^\\d* +.+ \\d*.?\\d*$") {
                var str = line.trimmingCharacters(in: .whitespaces)
                
                let pidString = str.findAndCrop(pattern: "^\\d+")
                let usageString = str.findAndCrop(pattern: " +[0-9]+.*[0-9]*$")
                let command = str.trimmingCharacters(in: .whitespaces)
                
                let pid = Int(pidString) ?? 0
                guard let usage = Double(usageString.filter("01234567890.".contains)) else {
                    return
                }
                
                var name: String? = nil
                var icon: NSImage? = nil
                if let app = NSRunningApplication(processIdentifier: pid_t(pid) ) {
                    name = app.localizedName ?? nil
                    icon = app.icon
                }
                
                processes.append(TopProcess(pid: pid, command: command, name: name, usage: usage, icon: icon))
            }
        }
        
        self.callback(processes)
    }
}
