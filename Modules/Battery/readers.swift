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
    private var service: io_connect_t = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    
    private var source: CFRunLoopSource?
    private var loop: CFRunLoop?
    
    private var usage: Battery_Usage = Battery_Usage()
    private let readLock = NSLock()
    
    public override func setup() {
        self.defaultInterval = 5
    }
    
    deinit {
        if let source = self.source {
            CFRunLoopSourceInvalidate(source)
        }
        if self.service != 0 {
            IOObjectRelease(self.service)
            self.service = 0
        }
    }
    
    public override func start() {
        super.start()
        guard self.source == nil else { return }
        
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let source = IOPSNotificationCreateRunLoopSource({ (context) in
            guard let ctx = context else {
                return
            }
            
            let watcher = Unmanaged<UsageReader>.fromOpaque(ctx).takeUnretainedValue()
            if watcher.active {
                watcher.read()
            }
        }, context)?.takeRetainedValue() else {
            return
        }
        
        self.source = source
        self.loop = RunLoop.current.getCFRunLoop()
        CFRunLoopAddSource(self.loop, source, .defaultMode)
    }
    
    public override func stop() {
        super.stop()
        guard let runLoop = loop, let source = source else {
            return
        }
        
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        CFRunLoopSourceInvalidate(source)
        self.source = nil
        self.loop = nil
    }
    
    public override func read() {
        self.readLock.lock()
        defer { self.readLock.unlock() }
        
        let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
        
        if psList.isEmpty {
            return
        }
        
        let descriptions = psList.compactMap { IOPSGetPowerSourceDescription(psInfo, $0).takeUnretainedValue() as? [String: Any] }
        guard let list = descriptions.first(where: { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }) ?? descriptions.first else {
            return
        }
        
        self.usage.ups = nil
        if let ups = descriptions.first(where: { $0[kIOPSTypeKey] as? String == kIOPSUPSType }) {
            let state = ups[kIOPSPowerSourceStateKey] as? String ?? "AC Power"
            self.usage.ups = UPS_Usage(
                name: ups[kIOPSNameKey] as? String ?? "",
                powerSource: state,
                isBatteryPowered: state == "UPS Power",
                isCharged: ups[kIOPSIsChargedKey] as? Bool ?? false,
                isCharging: ups[kIOPSIsChargingKey] as? Bool ?? false,
                level: Double(ups[kIOPSCurrentCapacityKey] as? Int ?? 0) / 100,
            )
        }
        
        let powerSource = list[kIOPSPowerSourceStateKey] as? String
        let isCharging = self.getBoolValue("IsCharging" as CFString)
        let level = list[kIOPSCurrentCapacityKey] as? Int
        
        self.usage.powerSource = powerSource ?? "AC Power"
        self.usage.isBatteryPowered = self.usage.powerSource == "Battery Power"
        self.usage.isCharged = list[kIOPSIsChargedKey] as? Bool ?? false
        self.usage.isCharging = isCharging ?? false
        self.usage.optimizedChargingEngaged = list["Optimized Battery Charging Engaged"] as? Int == 1
        self.usage.level = Double(level ?? 0) / 100
        
        self.usage.timeToEmpty = list[kIOPSTimeToEmptyKey] as? Int ?? 0
        self.usage.timeToCharge = list[kIOPSTimeToFullChargeKey] as? Int ?? 0
        
        if self.usage.powerSource == "AC Power" {
            self.usage.timeOnACPower = Date()
        }
        
        let cycles = self.getIntValue("CycleCount" as CFString)
        self.usage.cycles = cycles ?? 0
        
        let batteryData = self.getDictValue("BatteryData" as CFString)
        
        self.usage.currentCapacity = self.getIntValue("AppleRawCurrentCapacity" as CFString) ?? batteryData?["RemainingCapacity"] as? Int ?? 0
        self.usage.designedCapacity = self.getIntValue("DesignCapacity" as CFString) ?? batteryData?["DesignCapacity"] as? Int ?? 1
        if self.usage.designedCapacity == 0 {
            self.usage.designedCapacity = 1
        }
        self.usage.maxCapacity = self.getIntValue((isARM ? "AppleRawMaxCapacity" : "MaxCapacity") as CFString)
            ?? self.getIntValue("NominalChargeCapacity" as CFString)
            ?? batteryData?["NominalChargeCapacity"] as? Int
            ?? batteryData?["FullChargeCapacity"] as? Int
            ?? 1
        if self.usage.maxCapacity == 0 {
            self.usage.maxCapacity = 1
        }
        if !isARM {
            self.usage.state = list[kIOPSBatteryHealthKey] as? String
        }
        self.usage.health = Int((Double(100 * self.usage.maxCapacity) / Double(self.usage.designedCapacity)).rounded(.toNearestOrEven))
        if self.usage.health > 100 {
            self.usage.health = 100
        }
        self.usage.available = list[kIOPSTypeKey] as? String == kIOPSInternalBatteryType &&
            (0...100).contains(level ?? -1) &&
            (powerSource == "AC Power" || powerSource == "Battery Power") &&
            isCharging != nil && (cycles ?? -1) >= 0
        
        self.usage.current = self.getIntValue("Amperage" as CFString) ?? 0
        self.usage.voltage = self.getVoltage() ?? 0
        self.usage.temperature = self.getTemperature()
        
        var ACwatts: Int = 0
        if let ACDetails = IOPSCopyExternalPowerAdapterDetails() {
            if let ACList = ACDetails.takeRetainedValue() as? [String: Any],
               let watts = ACList[kIOPSPowerAdapterWattsKey] as? Int {
                ACwatts = watts
            }
        }
        self.usage.ACwatts = ACwatts
        
        let calculatedPower = self.usage.voltage * (Double(self.usage.current) / 1000)
        self.usage.batteryPower = isARM ? (SMC.shared.getValue("PPBR") ?? calculatedPower) : calculatedPower
        self.usage.adapterPower = SMC.shared.getValue("PDTR") ?? 0
        self.usage.adapterVoltage = 0
        if !self.usage.isBatteryPowered, let adapterDetails = self.getAdapterDetails() {
            self.usage.adapterVoltage = Double(adapterDetails["AdapterVoltage"] as? Int ?? 0) / 1000
        }
        
        self.usage.chargingCurrent = 0
        self.usage.chargingVoltage = 0
        if let chargerData = self.getChargerData() {
            if !self.usage.isBatteryPowered {
                self.usage.chargingCurrent = chargerData["ChargingCurrent"] as? Int ?? 0
                self.usage.chargingVoltage = chargerData["ChargingVoltage"] as? Int ?? 0
            }
            
            if !self.usage.optimizedChargingEngaged && !self.usage.isBatteryPowered && !self.usage.isCharging && self.usage.level < 1,
               let notChargingReason = chargerData["NotChargingReason"] as? Int, notChargingReason != 0 {
                self.usage.optimizedChargingEngaged = true
            }
        }
        
        self.callback(self.usage)
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

    private func getDictValue(_ identifier: CFString) -> [String: Any]? {
        if let value = IORegistryEntryCreateCFProperty(self.service, identifier, kCFAllocatorDefault, 0) {
            return value.takeRetainedValue() as? [String: Any]
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
        if let value = IORegistryEntryCreateCFProperty(self.service, "Temperature" as CFString, kCFAllocatorDefault, 0),
           let temperature = value.takeRetainedValue() as? Double, temperature.isFinite && temperature > 0 {
            return temperature / 100.0
        }
        
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBatteryPack"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            
            if let value = IORegistryEntryCreateCFProperty(service, "BatteryData" as CFString, kCFAllocatorDefault, 0),
               let batteryData = value.takeRetainedValue() as? [String: Any],
               let temperature = batteryData["Temperature"] as? Double, temperature.isFinite && temperature > 0 {
                return temperature / 100.0
            }
        }
        
        let sensors = ["TB1T", "TB2T"].compactMap { SMC.shared.getValue($0) }.filter { $0.isFinite && $0 > 0 }
        if !sensors.isEmpty {
            return sensors.reduce(0, +) / Double(sensors.count)
        }
        
        return nil
    }
    
    private func getChargerData() -> [String: Any]? {
        if let chargerData = IORegistryEntryCreateCFProperty(service, "ChargerData" as CFString, kCFAllocatorDefault, 0) {
            return chargerData.takeRetainedValue() as? [String: Any]
        }
        return nil
    }
    
    private func getAdapterDetails() -> [String: Any]? {
        if let adapterDetails = IORegistryEntryCreateCFProperty(service, "AdapterDetails" as CFString, kCFAllocatorDefault, 0) {
            return adapterDetails.takeRetainedValue() as? [String: Any]
        }
        return nil
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "Battery_processes", defaultValue: 8)
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
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-o", "power", "-l", "2", "-n", "\(self.numberOfProcesses)", "-stats", "pid,command,power"]
        
        let outputPipe = Pipe()
        defer {
            outputPipe.fileHandleForReading.closeFile()
        }
        task.standardOutput = outputPipe
        
        do {
            try task.run()
        } catch let err {
            error("error read ps: \(err.localizedDescription)", log: self.log)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if outputData.isEmpty {
            return
        }
        
        let output = String(data: outputData.advanced(by: outputData.count/2), encoding: .utf8)
        guard let output, !output.isEmpty else { return }
        
        var processes: [TopProcess] = []
        output.enumerateLines { (line, _) in
            if line.matches("^\\d+ *[^(\\d)]*\\d+\\.*\\d* *$") {
                let str = line.trimmingCharacters(in: .whitespaces)
                let pidFind = str.findAndCrop(pattern: "^\\d+")
                let usageFind = pidFind.remain.findAndCrop(pattern: " +[0-9]+.*[0-9]*$")
                let command = usageFind.remain.trimmingCharacters(in: .whitespaces)
                let pid = Int(pidFind.cropped) ?? 0
                guard let usage = Double(usageFind.cropped.filter("01234567890.".contains)) else {
                    return
                }
                
                var name: String = command
                if let app = NSRunningApplication(processIdentifier: pid_t(pid)), let n = app.localizedName {
                    name = n
                }
                
                processes.append(TopProcess(pid: pid, name: name, usage: usage))
            }
        }
        
        self.callback(processes.suffix(self.numberOfProcesses).sorted(by: { $0.usage > $1.usage }))
    }
}
