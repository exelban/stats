//
//  main.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit

public struct CPULoad {
    var totalUsage: Double?
    var usagePerCore: [Double]
}

public class CPU: Module {
    private var loadReader: Reader_p?
    
    public init(menuBarItem: NSStatusItem) throws {
        super.init(name: "CPU", menuBarItem: menuBarItem, defaultWidget: "Mini")
        
        do {
            try self.load()
        } catch {
            throw "failed to load CPU module: \(error.localizedDescription)"
        }
        
        self.loadReader = LoadReader(callback: self.loadCallback, ready: self.readyCallback)
        self.addReader(self.loadReader!)
    }
    
    private func loadCallback(value: CPULoad?) {
        if let widget = self.widget as? Mini {
            if value == nil {
                return
            }
            
            DispatchQueue.main.async(execute: {
                widget.valueView.stringValue = "\(Int((value?.totalUsage!.rounded(toPlaces: 2))! * 100))%"
                widget.valueView.textColor = value?.totalUsage!.usageColor(color: widget.color)
            })
        }
    }
}
