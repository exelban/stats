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

internal class InfoReader: Reader<GPUs> {
    internal var smc: UnsafePointer<SMCService>? = nil
    
    private var gpus: GPUs = GPUs()
    private var devices: [NSDictionary]? = nil
    
    public override func setup() {
        guard let devices = fetchIOService("IOPCIDevice") else {
            return
        }
        
        self.devices = devices.filter{ $0.object(forKey: "IOName") as? String == "display" }
    }
    
    public override func read() {
        guard let acceletators = fetchIOService(kIOAcceleratorClassName) else {
            return
        }
        
        acceletators.forEach { (accelerator: NSDictionary) in
            guard let matchedGPU = self.devices?.first(where: { (gpu: NSDictionary) -> Bool in
                guard let deviceID = gpu["device-id"] as? Data, let vendorID = gpu["vendor-id"] as? Data else {
                    return false
                }
                
                let pciMatch = "0x" + Data([deviceID[1], deviceID[0], vendorID[1], vendorID[0]]).map { String(format: "%02hhX", $0) }.joined().lowercased()
                let accMatch = (accelerator["IOPCIMatch"] as? String ?? accelerator["IOPCIPrimaryMatch"] as? String ?? "").lowercased()
                
                return accMatch.range(of: pciMatch) != nil
            }) else { return }
            
            guard let agcInfo = accelerator["AGCInfo"] as? [String:Int] else {
                return
            }
            
            guard let stats = accelerator["PerformanceStatistics"] as? [String:Any] else {
                return
            }
            
            guard let model = matchedGPU.object(forKey: "model") as? Data, var modelName = String(data: model, encoding: .ascii) else {
                return
            }
            modelName = modelName.replacingOccurrences(of: "\0", with: "")
            
            guard let IOClass = accelerator.object(forKey: "IOClass") as? String else {
                return
            }
            
            if self.gpus.list.first(where: { $0.name == modelName }) == nil {
                self.gpus.list.append(GPU_Info(name: modelName, IOclass: IOClass))
            }
            
            guard let idx = self.gpus.list.firstIndex(where: { $0.name == modelName }) else {
                return
            }
            
            let utilization = stats["Device Utilization %"] as? Int ?? 0
//            let totalVram = (accelerator["VRAM,totalMB"] as? Int ?? matchedGPU["VRAM,totalMB"] as? Int ?? 0) * 1000000
//            let freeVram = stats["vramFreeBytes"] as? Int ?? 0
//            let coreClock = stats["Core Clock(MHz)"] as? Int ?? 0
            var temperature = stats["Temperature(C)"] as? Int ?? 0
            
            if IOClass == "IntelAccelerator" {
                if temperature == 0 {
                    if let tmp = self.smc?.pointee.getValue("TCGC") {
                        temperature = Int(tmp)
                    } else if let tmp = self.smc?.pointee.getValue("TG0D") {
                        temperature = Int(tmp)
                    }
                }
            }
            
            self.gpus.list[idx].state = agcInfo["poweredOffByAGC"] == 0
            
            self.gpus.list[idx].utilization = utilization == 0 ? 0 : Double(utilization)/100
            self.gpus.list[idx].temperature = temperature
        }
        
        self.gpus.list.sort{ !$0.state && $1.state }
        self.callback(self.gpus)
    }
}
