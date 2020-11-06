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
        
        print("------------", Date(), "------------", to: &Log.log)
        print("Found \(devices.count) devices", to: &Log.log)
        
        devices.forEach { (dict: NSDictionary) in
            guard let deviceID = dict["device-id"] as? Data, let vendorID = dict["vendor-id"] as? Data else {
                print("device-id or vendor-id not found", to: &Log.log)
                return
            }
            let pci = "0x" + Data([deviceID[1], deviceID[0], vendorID[1], vendorID[0]]).map { String(format: "%02hhX", $0) }.joined().lowercased()
            
            guard let modelData = dict["model"] as? Data, let modelName = String(data: modelData, encoding: .ascii) else {
                print("GPU model not found", to: &Log.log)
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
        
        for (i, _) in self.devices.enumerated() {
            self.devices[i].used = false
        }
        
        print("------------", "read()", "------------", to: &Log.log)
        print("Found \(accelerators.count) accelerators", to: &Log.log)
        
        accelerators.forEach { (accelerator: NSDictionary) in
            guard let IOClass = accelerator.object(forKey: "IOClass") as? String else {
                print("IOClass not found", to: &Log.log)
                return
            }
            print("Processing \(IOClass) accelerator", to: &Log.log)
            
            guard let stats = accelerator["PerformanceStatistics"] as? [String:Any] else {
                print("PerformanceStatistics not found", to: &Log.log)
                return
            }
            
            var model: String = ""
            let accMatch = (accelerator["IOPCIMatch"] as? String ?? accelerator["IOPCIPrimaryMatch"] as? String ?? "").lowercased()
            
            for (i, device) in self.devices.enumerated() {
                let matched = accMatch.range(of: device.pci)
                if matched != nil && !device.used {
                    model = device.model
                    self.devices[i].used = true
                } else if device.used {
                    print("Device `\(device.model)` with pci `\(device.pci)` is already used", to: &Log.log)
                } else {
                    print("`\(device.pci)` and `\(accMatch)` not match", to: &Log.log)
                }
            }
            
            if model == "" {
                let ioClass = IOClass.lowercased()
                if ioClass == "nvAccelerator" || ioClass.contains("nvidia") {
                    model = "Nvidia Graphics"
                } else if ioClass.contains("amd") {
                    model = "AMD Graphics"
                } else if ioClass.contains("intel") {
                    model = "Intel Graphics"
                } else {
                    model = "Unknown"
                }
            }
            
            if self.gpus.list.first(where: { $0.model == model }) == nil {
                self.gpus.list.append(GPU_Info(model: model, IOClass: IOClass))
            }
            guard let idx = self.gpus.list.firstIndex(where: { $0.model == model }) else {
                return
            }
            
            let utilization = stats["Device Utilization %"] as? Int ?? stats["GPU Activity(%)"] as? Int ?? 0
            var temperature = stats["Temperature(C)"] as? Int ?? 0
            
            if IOClass == "IntelAccelerator" && temperature == 0 {
                if let tmp = self.smc?.pointee.getValue("TCGC") {
                    temperature = Int(tmp)
                } else if let tmp = self.smc?.pointee.getValue("TG0D") {
                    temperature = Int(tmp)
                }
            }
            
            if let agcInfo = accelerator["AGCInfo"] as? [String:Int] {
                self.gpus.list[idx].state = agcInfo["poweredOffByAGC"] == 0
            }
            
            self.gpus.list[idx].utilization = utilization == 0 ? 0 : Double(utilization)/100
            self.gpus.list[idx].temperature = temperature
            
            print("\(model): utilization=\(utilization), temperature=\(temperature)", to: &Log.log)
        }
        
        print("Callback \(self.gpus.list.count) GPUs", to: &Log.log)
        
        self.gpus.list.sort{ !$0.state && $1.state }
        self.callback(self.gpus)
    }
}
