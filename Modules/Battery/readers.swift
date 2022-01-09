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
import Kit

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
        
        if psList.isEmpty {
            return
        }
        
        for ps in psList {
            if let list = IOPSGetPowerSourceDescription(psInfo, ps).takeUnretainedValue() as? [String: Any] {
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
                
                if self.usage.powerSource == "AC Power" {
                    self.usage.timeOnACPower = Date()
                }
                
                self.usage.cycles = self.getIntValue("CycleCount" as CFString) ?? 0
                
                var maxCapacity: Int = 1
                let designCapacity: Int = self.getIntValue("DesignCapacity" as CFString) ?? 1
                #if arch(x86_64)
                maxCapacity = self.getIntValue("MaxCapacity" as CFString) ?? 1
                self.usage.state = list[kIOPSBatteryHealthKey] as? String
                #else
                maxCapacity = self.getIntValue("AppleRawMaxCapacity" as CFString) ?? 1
                #endif
                self.usage.health = (100 * maxCapacity) / designCapacity
                
                self.usage.amperage = self.getIntValue("Amperage" as CFString) ?? 0
                self.usage.voltage = self.getVoltage() ?? 0
                self.usage.temperature = self.getTemperature() ?? 0
                
                var ACwatts: Int = 0
                if let ACDetails = IOPSCopyExternalPowerAdapterDetails() {
                    if let ACList = ACDetails.takeRetainedValue() as? [String: Any] {
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
    private let title: String = "Battery"
    
    private var task: Process = Process()
    private var initialized: Bool = false
    private var paused: Bool = false
    private var initRead: Bool = false
    
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    
    public override func setup() {
        self.popup = true
        
        let pipe = Pipe()
        
        self.task.standardOutput = pipe
        self.task.launchPath = "/usr/bin/top"
        self.task.arguments = ["-o", "power", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,power"]
        
        pipe.fileHandleForReading.readabilityHandler = { (fileHandle) -> Void in
            let output = String(decoding: fileHandle.availableData, as: UTF8.self)
            var processes: [TopProcess] = []
            
            output.enumerateLines { (line, _) -> Void in
                if line.matches("^\\d* +.+ \\d*.?\\d*$") {
                    var str = line.trimmingCharacters(in: .whitespaces)
                    
                    if self.paused {
                        return
                    }
                    
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
            
            if !processes.isEmpty {
                self.callback(processes.prefix(self.numberOfProcesses).reversed().reversed())
            }
            
            if !self.initRead {
                self.pause()
                self.initRead = true
            }
        }
    }
    
    public override func start() {
        if !self.initialized {
            self.task.launch()
            self.initialized = true
            return
        }
        
        self.initRead = true
        if !self.task.isRunning {
            do {
                try self.task.run()
            } catch let error {
                debug("run Battery process reader \(error)", log: self.log)
            }
        } else if self.paused {
            self.paused = !self.task.resume()
        }
    }
    
    public override func pause() {
        if self.task.isRunning && !self.paused {
            self.paused = self.task.suspend()
        }
    }
    
    public override func stop() {
        if self.task.isRunning && !self.paused {
            self.paused = self.task.suspend()
        }
    }
}
