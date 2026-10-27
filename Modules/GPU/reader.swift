//
//  reader.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public struct device {
    public let vendor: String?
    public let model: String
    public let pci: String
    public var used: Bool
}

let vendors: [Data: String] = [
    Data.init([0x86, 0x80, 0x00, 0x00]): "Intel",
    Data.init([0x02, 0x10, 0x00, 0x00]): "AMD"
]

private func maxANEPower(for platform: Platform?) -> Double {
    switch platform {
    case .m1, .m1Pro, .m1Max:       return 2.0
    case .m1Ultra:                  return 4.0
    case .m2, .m2Pro, .m2Max:       return 2.5
    case .m2Ultra:                  return 5.0
    case .m3, .m3Pro, .m3Max:       return 3.0
    case .m3Ultra:                  return 6.0
    case .m4, .m4Pro, .m4Max:       return 6.0
    case .m5, .m5Pro, .m5Max:       return 8.0
    case .m5Ultra:                  return 16.0
    case .m6, .m6Pro, .m6Max:       return 16.0
    default:                        return 8.0
    }
}

internal class InfoReader: Reader<GPUs> {
    private var gpus: GPUs = GPUs()
    private var displays: [gpu_s] = []
    private var devices: [device] = []

    private var aneChannels: CFMutableDictionary? = nil
    private var aneSubscription: IOReportSubscriptionRef? = nil
    private var previousANEEnergy: Double = 0
    private var previousANERead: Date? = nil
    private var aneMaxPower: Double = 8.0

    private var framesChannels: CFMutableDictionary? = nil
    private var framesSubscription: IOReportSubscriptionRef? = nil
    private var previousFramesCount: Int64 = 0
    private var previousFramesTime: CFAbsoluteTime = 0
    
    public override func setup() {
        if let list = SystemKit.shared.device.info.gpu {
            self.displays = list
        }
        
        guard let PCIdevices = fetchIOService("IOPCIDevice") else {
            return
        }
        let devices = PCIdevices.filter{ $0.object(forKey: "IOName") as? String == "display" }
        
        #if arch(arm64)
        self.aneMaxPower = maxANEPower(for: SystemKit.shared.device.platform)
        self.setupANE()
        self.setupFrames()
        #endif
        
        devices.forEach { (dict: NSDictionary) in
            guard let deviceID = dict["device-id"] as? Data, let vendorID = dict["vendor-id"] as? Data else {
                error("device-id or vendor-id not found", log: self.log)
                return
            }
            let pci = "0x" + Data([deviceID[1], deviceID[0], vendorID[1], vendorID[0]]).map { String(format: "%02hhX", $0) }.joined().lowercased()
            
            guard let modelData = dict["model"] as? Data, let modelName = String(data: modelData, encoding: .ascii) else {
                error("GPU model not found", log: self.log)
                return
            }
            let model = modelName.replacingOccurrences(of: "\0", with: "")
            
            var vendor: String? = nil
            if let v = vendors.first(where: { $0.key == vendorID }) {
                vendor = v.value
            }
            
            self.devices.append(device(
                vendor: vendor,
                model: model,
                pci: pci,
                used: false
            ))
        }
    }
    
    public override func read() {
        guard let accelerators = fetchIOService(kIOAcceleratorClassName) else {
            return
        }
        var devices = self.devices
        
        for (index, accelerator) in accelerators.enumerated() {
            guard let IOClass = accelerator.object(forKey: "IOClass") as? String else {
                error("IOClass not found", log: self.log)
                continue
            }
            
            guard let stats = accelerator["PerformanceStatistics"] as? [String: Any] else {
                error("PerformanceStatistics not found", log: self.log)
                continue
            }
            
            var id: String = ""
            var vendor: String? = nil
            var model: String = ""
            var cores: Int? = nil
            let accMatch = (accelerator["IOPCIMatch"] as? String ?? accelerator["IOPCIPrimaryMatch"] as? String ?? "").lowercased()
            
            for (i, device) in devices.enumerated() {
                if accMatch.range(of: device.pci) != nil && !device.used {
                    model = device.model
                    vendor = device.vendor
                    id = "\(model) #\(index)"
                    devices[i].used = true
                    break
                }
            }
            
            let ioClass = IOClass.lowercased()
            var predictModel = ""
            var type: GPU_types = .unknown
            
            let utilization: Int? = stats["Device Utilization %"] as? Int ?? stats["GPU Activity(%)"] as? Int ?? nil
            let renderUtilization: Int? = stats["Renderer Utilization %"] as? Int ?? nil
            let tilerUtilization: Int? = stats["Tiler Utilization %"] as? Int ?? nil
            var temperature: Int? = stats["Temperature(C)"] as? Int ?? nil
            let fanSpeed: Int? = stats["Fan Speed(%)"] as? Int ?? nil
            let coreClock: Int? = stats["Core Clock(MHz)"] as? Int ?? nil
            let memoryClock: Int? = stats["Memory Clock(MHz)"] as? Int ?? nil
            
            if ioClass == "nvaccelerator" || ioClass.contains("nvidia") { // nvidia
                predictModel = "Nvidia Graphics"
                type = .discrete
            } else if ioClass.contains("amd") { // amd
                predictModel = "AMD Graphics"
                type = .discrete
                
                if temperature == nil || temperature == 0 {
                    if let tmp = SMC.shared.getValue("TGDD"), tmp != 128 {
                        temperature = Int(tmp)
                    }
                }
            } else if ioClass.contains("intel") { // intel
                predictModel = "Intel Graphics"
                type = .integrated
                
                if temperature == nil || temperature == 0 {
                    if let tmp = SMC.shared.getValue("TCGC"), tmp != 128 {
                        temperature = Int(tmp)
                    }
                }
            } else if ioClass.contains("agx") { // apple
                predictModel = stats["model"] as? String ?? "Apple Graphics"
                if let display = self.displays.first(where: { $0.vendor == "sppci_vendor_Apple" }) {
                    if let name = display.name {
                        predictModel = name
                    }
                    if let num = display.cores {
                        cores = num
                    }
                }
                type = .integrated
            } else {
                predictModel = "Unknown"
                type = .unknown
            }
            
            if model == "" {
                model = predictModel
            }
            if let v = vendor {
                model = model.removedRegexMatches(pattern: v, replaceWith: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if self.gpus.list.first(where: { $0.id == id }) == nil {
                self.gpus.list.append(GPU_Info(
                    id: id,
                    type: type.rawValue,
                    IOClass: IOClass,
                    vendor: vendor,
                    model: model,
                    cores: cores
                ))
            }
            guard let idx = self.gpus.list.firstIndex(where: { $0.id == id }) else {
                return
            }
            
            if let agcInfo = accelerator["AGCInfo"] as? [String: Int], let state = agcInfo["poweredOffByAGC"] {
                self.gpus.list[idx].state = state == 0
            }
            
            if var value = utilization {
                if value > 100 {
                    value = 100
                }
                self.gpus.list[idx].utilization = Double(value)/100
            }
            if var value = renderUtilization {
                if value > 100 {
                    value = 100
                }
                self.gpus.list[idx].renderUtilization = Double(value)/100
            }
            if var value = tilerUtilization {
                if value > 100 {
                    value = 100
                }
                self.gpus.list[idx].tilerUtilization = Double(value)/100
            }
            if let value = temperature {
                self.gpus.list[idx].temperature = Double(value)
            }
            if let value = fanSpeed {
                self.gpus.list[idx].fanSpeed = value
            }
            if let value = coreClock {
                self.gpus.list[idx].coreClock = value
            }
            if let value = memoryClock {
                self.gpus.list[idx].memoryClock = value
            }
        }
        
        #if arch(arm64)
        let anePower = self.readANEPower()
        let aneUtil = anePower.map { min(1.0, max(0.0, $0 / self.aneMaxPower)) }
        let fpsValue = self.readFrames()
        for i in self.gpus.list.indices where self.gpus.list[i].IOClass.lowercased().contains("agx") {
            self.gpus.list[i].aneUtilization = aneUtil ?? 0
            self.gpus.list[i].fps = fpsValue
        }
        #endif
        
        self.gpus.list.sort{ !$0.state && $1.state }
        self.callback(self.gpus)
    }
    
    // MARK: - FPS
    
    private func setupFrames() {
        let groups = ["DCP", "DCP0", "DCPEXT0", "DCPEXT1", "DCPEXT2", "DCPEXT3"]
        var merged: CFMutableDictionary? = nil
        
        for group in groups {
            guard let channel = IOReportCopyChannelsInGroup(group as CFString, "swap" as CFString, 0, 0, 0)?.takeRetainedValue() else { continue }
            if merged == nil {
                merged = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, channel)
            } else {
                IOReportMergeChannels(merged, channel, nil)
            }
        }
        
        guard let merged, let dict = merged as? [String: Any], dict["IOReportChannels"] != nil else { return }
        
        self.framesChannels = merged
        var sub: Unmanaged<CFMutableDictionary>?
        self.framesSubscription = IOReportCreateSubscription(nil, merged, &sub, 0, nil)
        sub?.release()
    }
    
    private func readFrames() -> Double? {
        guard let subscription = self.framesSubscription,
              let channels = self.framesChannels,
              let sample = IOReportCreateSamples(subscription, channels, nil)?.takeRetainedValue(),
              let dict = sample as? [String: Any],
              let channelsList = dict["IOReportChannels"] as? NSArray else {
            return nil
        }
        let items = channelsList as CFArray
        
        var total: Int64 = 0
        for i in 0..<CFArrayGetCount(items) {
            let item = unsafeBitCast(CFArrayGetValueAtIndex(items, i), to: CFDictionary.self)
            guard let group = IOReportChannelGetGroup(item)?.takeUnretainedValue() as? String,
                  group.hasPrefix("DCP"),
                  let sub = IOReportChannelGetSubGroup(item)?.takeUnretainedValue() as? String,
                  sub == "swap" else { continue }
            total += IOReportSimpleGetIntegerValue(item, 0)
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        defer {
            self.previousFramesCount = total
            self.previousFramesTime = now
        }
        
        guard self.previousFramesTime != 0 else { return nil }
        let elapsed = now - self.previousFramesTime
        guard elapsed > 0 else { return nil }
        let delta = total - self.previousFramesCount
        guard delta >= 0 else { return nil }
        return Double(delta) / elapsed
    }
    
    // MARK: - ANE power
    
    private func setupANE() {
        guard let channel = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0)?.takeRetainedValue() else { return }
        
        let size = CFDictionaryGetCount(channel)
        guard let mutable = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, size, channel),
              let dict = mutable as? [String: Any], dict["IOReportChannels"] != nil else { return }
        
        self.aneChannels = mutable
        var sub: Unmanaged<CFMutableDictionary>?
        self.aneSubscription = IOReportCreateSubscription(nil, mutable, &sub, 0, nil)
        sub?.release()
    }
    
    private func readANEPower() -> Double? {
        guard let subscription = self.aneSubscription,
              let channels = self.aneChannels,
              let reportSample = IOReportCreateSamples(subscription, channels, nil)?.takeRetainedValue(),
              let dict = reportSample as? [String: Any],
              let channelsList = dict["IOReportChannels"] as? NSArray else {
            return nil
        }
        let items = channelsList as CFArray
        
        var currentEnergy: Double = 0
        var found = false
        
        for i in 0..<CFArrayGetCount(items) {
            let item = unsafeBitCast(CFArrayGetValueAtIndex(items, i), to: CFDictionary.self)
            
            guard let group = IOReportChannelGetGroup(item)?.takeUnretainedValue() as? String,
                  group == "Energy Model",
                  let channel = IOReportChannelGetChannelName(item)?.takeUnretainedValue() as? String,
                  channel.starts(with: "ANE") else { continue }
            
            let raw = Double(IOReportSimpleGetIntegerValue(item, 0))
            let unit = (IOReportChannelGetUnitLabel(item)?.takeUnretainedValue() as? String)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            
            let joules: Double
            switch unit.lowercased() {
            case "mj":       joules = raw / 1e3
            case "uj", "µj": joules = raw / 1e6
            case "nj":       joules = raw / 1e9
            case "pj":       joules = raw / 1e12
            default:         joules = raw / 1e9
            }
            
            currentEnergy += joules
            found = true
        }
        
        guard found else { return nil }
        
        let now = Date()
        defer {
            self.previousANEEnergy = currentEnergy
            self.previousANERead = now
        }
        
        guard let previousRead = self.previousANERead else { return 0 }
        let elapsed = now.timeIntervalSince(previousRead)
        guard elapsed > 0 else { return 0 }
        return (currentEnergy - self.previousANEEnergy) / elapsed
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    internal struct Client {
        let pid: Int
        let name: String
        let gpuTime: UInt64
        let queues: Int
    }
    
    internal struct Usage {
        private var clients: [UInt64: Client] = [:]
        private(set) var timestamp: UInt64? = nil
        
        mutating func sample(_ clients: [UInt64: Client], at timestamp: UInt64, interval: Double) -> [TopProcess]? {
            guard let previousTimestamp = self.timestamp, timestamp > previousTimestamp,
                  Double(timestamp - previousTimestamp) / 1e9 <= max(interval, 1) * 3 else {
                self.clients = clients
                self.timestamp = timestamp
                return nil
            }
            let elapsed = timestamp - previousTimestamp
            guard elapsed >= 250_000_000 else { return nil }
            defer {
                self.clients = clients
                self.timestamp = timestamp
            }
            
            var processes: [Int: TopProcess] = [:]
            for (id, client) in clients {
                // Client and queue count changes or reset counters need a fresh baseline.
                guard let previous = self.clients[id], previous.pid == client.pid,
                      previous.queues == client.queues, client.gpuTime >= previous.gpuTime else { continue }
                let usage = Double(client.gpuTime - previous.gpuTime) / Double(elapsed) * 100
                if processes[client.pid] == nil {
                    processes[client.pid] = TopProcess(pid: client.pid, name: client.name, usage: 0)
                }
                processes[client.pid]?.usage += usage
            }
            
            return processes.values.sorted {
                $0.usage != $1.usage ? $0.usage > $1.usage : $0.pid < $1.pid
            }
        }
    }
    
    private let title: String = "GPU"
    private let readLock = NSLock()
    private var usage = Usage()
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    
    public override func setup() {
        self.popup = true
        self.preview = true
        self.setInterval(Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: 1))
    }
    
    public override func start() {
        let active = self.active
        super.start()
        if !active && self.active {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.read()
            }
        }
    }
    
    public override func pause() {
        super.pause()
        self.reset()
    }
    
    public override func stop() {
        super.stop()
        self.reset()
    }
    
    private func reset() {
        self.readLock.lock()
        defer { self.readLock.unlock() }
        self.usage = Usage()
    }
    
    public override func read() {
        self.readLock.lock()
        defer { self.readLock.unlock() }
        guard self.active else { return }
        
        let limit = self.numberOfProcesses
        guard limit > 0 else {
            self.usage = Usage()
            self.callback([])
            return
        }
        guard let clients = Self.readClients() else { return }
        let previousTimestamp = self.usage.timestamp
        guard let processes = self.usage.sample(clients, at: DispatchTime.now().uptimeNanoseconds, interval: self.interval ?? 1) else {
            if self.usage.timestamp != previousTimestamp {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.read()
                }
            }
            return
        }
        
        self.callback(processes.prefix(limit).map { process in
            var process = process
            if let app = NSRunningApplication(processIdentifier: pid_t(process.pid)), let name = app.localizedName {
                process.name = name
            } else {
                var buffer = [UInt8](repeating: 0, count: 4096)
                let length = proc_pidpath(pid_t(process.pid), &buffer, UInt32(buffer.count))
                if length > 0, let path = String(bytes: buffer.prefix(Int(length)), encoding: .utf8) {
                    process.name = URL(fileURLWithPath: path).lastPathComponent
                }
            }
            return process
        })
    }
    
    internal static func readClients() -> [UInt64: Client]? {
        var iterator: io_iterator_t = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOAcceleratorClassName), &iterator) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }
        
        var clients: [UInt64: Client] = [:]
        var accelerator = IOIteratorNext(iterator)
        while accelerator != 0 {
            let service = accelerator
            defer { IOObjectRelease(service) }
            var children: io_iterator_t = io_iterator_t()
            guard IORegistryEntryGetChildIterator(accelerator, kIOServicePlane, &children) == kIOReturnSuccess else { return nil }
            defer { IOObjectRelease(children) }
            
            var child = IOIteratorNext(children)
            while child != 0 {
                var properties: Unmanaged<CFMutableDictionary>?
                var id: UInt64 = 0
                if IORegistryEntryGetRegistryEntryID(child, &id) == kIOReturnSuccess,
                   IORegistryEntryCreateCFProperties(child, &properties, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let properties = properties?.takeRetainedValue() as? [String: Any], let client = Self.parseClient(properties) {
                    clients[id] = client
                }
                IOObjectRelease(child)
                child = IOIteratorNext(children)
            }
            guard IOIteratorIsValid(children) != 0 else { return nil }
            accelerator = IOIteratorNext(iterator)
        }
        guard IOIteratorIsValid(iterator) != 0 else { return nil }
        return clients
    }
    
    internal static func parseClient(_ properties: [String: Any]) -> Client? {
        guard let creator = properties["IOUserClientCreator"] as? String, creator.hasPrefix("pid "),
              let queues = properties["AppUsage"] as? [[String: Any]] else { return nil }
        let parts = creator.dropFirst(4).split(separator: ",", maxSplits: 1)
        guard let first = parts.first, let pid = Int(first.trimmingCharacters(in: .whitespaces)), pid > 0 else { return nil }
        let times = queues.compactMap { ($0["accumulatedGPUTime"] as? NSNumber)?.uint64Value }
        guard !times.isEmpty else { return nil }
        
        let name = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "\(pid)"
        return Client(pid: pid, name: name, gpuTime: times.reduce(0, +), queues: times.count)
    }
}
