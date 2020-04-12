//
//  main.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 12/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit

public struct MemoryUsage {
    var usage: Double?
    var total: Double?
    var used: Double?
    var free: Double?
}

public class Memory: Module {
    private var usageReader: Reader_p?
    
    public init(menuBarItem: NSStatusItem) throws {
        super.init(name: "RAM", icon: NSImage(), menuBarItem: menuBarItem, defaultWidget: "Mini")
        
        do {
            try self.load()
        } catch {
            throw "failed to load RAM module: \(error.localizedDescription)"
        }
        
        self.usageReader = UsageReader(callback: self.loadCallback, ready: self.readyCallback)
        self.addReader(self.usageReader!)
    }
    
    private func loadCallback(value: MemoryUsage?) {
        if let widget = self.widget as? Mini {
            if value == nil {
                return
            }
            
            DispatchQueue.main.async(execute: {
                widget.valueView.stringValue = "\(Int(value!.usage!.rounded(toPlaces: 2) * 100))%"
                widget.valueView.textColor = value!.usage!.usageColor(color: widget.color)
            })
        }
    }
}
