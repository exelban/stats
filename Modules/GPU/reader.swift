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
import StatsKit
import ModuleKit
import os.log

public struct device {
    public let model: String
    public let pci: String
    public var used: Bool
}

internal class InfoReader: Reader<GPUs> {
    internal var smc: UnsafePointer<SMCService>? = nil
    
    private var gpus: GPUs = GPUs()
    private var devices: [device] = []
    
    public override func setup() {
        guard let PCIdevices = fetchIOService("IOPCIDevice") else {
            return
        }
        let devices = PCIdevices.filter{ $0.object(forKey: "IOName") as? String == "display" }
        
        devices.forEach { (dict: NSDictionary) in
            guard let deviceID = dict["device-id"] as? Data, let vendorID = dict["vendor-id"] as? Data else {
                os_log(.error, log: log, "device-id or vendor-id not found")
                return
            }
            let pci = "0x" + Data([deviceID[1], deviceID[0], vendorID[1], vendorID[0]]).map { String(format: "%02hhX", $0) }.joined().lowercased()
            
            guard let modelData = dict["model"] as? Data, let modelName = String(data: modelData, encoding: .ascii) else {
                os_log(.error, log: log, "GPU model not found")
                return
            }
            let model = modelName.replacingOccurrences(of: "\0", with: "")
            
            self.devices.append(device(model: model, pci: pci, used: false))
        }
    }
    
    public override func read() {
        guard let accelerators = fetchIOService(kIOAcceleratorClassName) else {
            return
        }
        var devices = self.devices
        
        accelerators.forEach { (accelerator: NSDictionary) in
            guard let IOClass = accelerator.object(forKey: "IOClass") as? String else {
                os_log(.error, log: log, "IOClass not found")
                return
            }
            
            guard let stats = accelerator["PerformanceStatistics"] as? [String:Any] else {
                os_log(.error, log: log, "PerformanceStatistics not found")
                return
            }
            
            var model: String = ""
            let accMatch = (accelerator["IOPCIMatch"] as? String ?? accelerator["IOPCIPrimaryMatch"] as? String ?? "").lowercased()
            
            for (i, device) in devices.enumerated() {
                if accMatch.range(of: device.pci) != nil && !device.used {
                    model = device.model
                    devices[i].used = true
                    break
                }
            }
            
            let ioClass = IOClass.lowercased()
            var predictModel = ""
            var type: GPU_types = .unknown
            
            if ioClass == "nvAccelerator" || ioClass.contains("nvidia") {
                predictModel = "Nvidia Graphics"
                type = .discrete
            } else if ioClass.contains("amd") {
                predictModel = "AMD Graphics"
                type = .discrete
            } else if ioClass.contains("intel") {
                predictModel = "Intel Graphics"
                type = .integrated
            } else {
                predictModel = "Unknown"
                type = .unknown
            }
            
            if model == "" {
                model = predictModel
            }
            
            if self.gpus.list.first(where: { $0.model == model }) == nil {
                self.gpus.list.append(GPU_Info(model: model, IOClass: IOClass, type: type.rawValue))
            }
            guard let idx = self.gpus.list.firstIndex(where: { $0.model == model }) else {
                return
            }
            
            let utilization = stats["Device Utilization %"] as? Int ?? stats["GPU Activity(%)"] as? Int ?? 0
            var temperature = stats["Temperature(C)"] as? Int ?? 0
            
            if temperature == 0 {
                if IOClass == "IntelAccelerator" {
                    if let tmp = self.smc?.pointee.getValue("TCGC") {
                        temperature = Int(tmp)
                    }
                } else if IOClass.starts(with: "AMDRadeon") {
                    if let tmp = self.smc?.pointee.getValue("TGDD") {
                        temperature = Int(tmp)
                    }
                }
            }
            
            if let agcInfo = accelerator["AGCInfo"] as? [String:Int] {
                self.gpus.list[idx].state = agcInfo["poweredOffByAGC"] == 0
            }
            
            self.gpus.list[idx].utilization = utilization == 0 ? 0 : Double(utilization)/100
            self.gpus.list[idx].temperature = temperature
        }
        
        self.gpus.list.sort{ !$0.state && $1.state }
        self.callback(self.gpus)
    }
}
