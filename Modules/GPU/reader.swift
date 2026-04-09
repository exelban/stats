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

internal class InfoReader: Reader<GPUs> {
    private var gpus: GPUs = GPUs()
    private var displays: [gpu_s] = []
    private var devices: [device] = []

    private var aneChannels: CFMutableDictionary? = nil
    private var aneSubscription: IOReportSubscriptionRef? = nil
    private var previousANEResidencies: [(on: Int64, total: Int64)] = []
    
    public override func setup() {
        if let list = SystemKit.shared.device.info.gpu {
            self.displays = list
        }
        
        guard let PCIdevices = fetchIOService("IOPCIDevice") else {
            return
        }
        let devices = PCIdevices.filter{ $0.object(forKey: "IOName") as? String == "display" }
        
        #if arch(arm64)
        self.setupANE()
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
                return
            }
            
            guard let stats = accelerator["PerformanceStatistics"] as? [String: Any] else {
                error("PerformanceStatistics not found", log: self.log)
                return
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
        let aneValue = self.readANEUtilization()
        for i in self.gpus.list.indices where self.gpus.list[i].IOClass.lowercased().contains("agx") {
            self.gpus.list[i].aneUtilization = aneValue ?? 0
        }
        #endif
        
        self.gpus.list.sort{ !$0.state && $1.state }
        self.callback(self.gpus)
    }
    
    // MARK: - ANE utilization
    
    private func setupANE() {
        guard let channel = IOReportCopyChannelsInGroup("SoC Stats" as CFString, "Cluster Power States" as CFString, 0, 0, 0)?.takeRetainedValue() else { return }
        
        let size = CFDictionaryGetCount(channel)
        guard let mutable = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, size, channel),
              let dict = mutable as? [String: Any], dict["IOReportChannels"] != nil else { return }
        
        self.aneChannels = mutable
        var sub: Unmanaged<CFMutableDictionary>?
        self.aneSubscription = IOReportCreateSubscription(nil, mutable, &sub, 0, nil)
        sub?.release()
    }
    
    private func readANEUtilization() -> Double? {
        guard let subscription = self.aneSubscription,
              let channels = self.aneChannels,
              let reportSample = IOReportCreateSamples(subscription, channels, nil)?.takeRetainedValue(),
              let dict = reportSample as? [String: Any] else {
            return nil
        }
        let items = dict["IOReportChannels"] as! CFArray
        
        var currentResidencies: [(on: Int64, total: Int64)] = []
        
        for i in 0..<CFArrayGetCount(items) {
            let item = unsafeBitCast(CFArrayGetValueAtIndex(items, i), to: CFDictionary.self)
            
            guard let group = IOReportChannelGetGroup(item)?.takeUnretainedValue() as? String,
                  group == "SoC Stats",
                  let subgroup = IOReportChannelGetSubGroup(item)?.takeUnretainedValue() as? String,
                  subgroup == "Cluster Power States",
                  let channel = IOReportChannelGetChannelName(item)?.takeUnretainedValue() as? String,
                  channel.hasPrefix("ANE") else { continue }
            
            let stateCount = IOReportStateGetCount(item)
            guard stateCount == 2 else { continue }
            
            var on: Int64 = 0
            var total: Int64 = 0
            for s in 0..<stateCount {
                let residency = IOReportStateGetResidency(item, s)
                let name = IOReportStateGetNameForIndex(item, s)?.takeUnretainedValue() as? String ?? ""
                total += residency
                if name != "INACT" {
                    on += residency
                }
            }
            
            currentResidencies.append((on: on, total: total))
        }
        
        guard !currentResidencies.isEmpty else { return nil }
        
        defer { self.previousANEResidencies = currentResidencies }
        guard self.previousANEResidencies.count == currentResidencies.count else { return nil }
        
        var totalDeltaOn: Int64 = 0
        var totalDeltaAll: Int64 = 0
        for i in 0..<currentResidencies.count {
            totalDeltaOn += currentResidencies[i].on - self.previousANEResidencies[i].on
            totalDeltaAll += currentResidencies[i].total - self.previousANEResidencies[i].total
        }
        
        guard totalDeltaAll > 0 else { return 0 }
        return Double(totalDeltaOn) / Double(totalDeltaAll)
    }
}
