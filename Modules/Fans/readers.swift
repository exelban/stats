//
//  readers.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 20/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit
import os.log

internal class FansReader: Reader<[Fan]> {
    private var smc: UnsafePointer<SMCService>
    internal var list: [Fan] = []
    
    init(_ smc: UnsafePointer<SMCService>) {
        self.smc = smc
        super.init()
        
        guard let count = smc.pointee.getValue("FNum") else {
            return
        }
        os_log(.debug, log: self.log, "Found %.0f fans", count)
        
        for i in 0..<Int(count) {
            self.list.append(Fan(
                id: i,
                name: smc.pointee.getStringValue("F\(i)ID") ?? "Fan #\(i)",
                minSpeed: smc.pointee.getValue("F\(i)Mn") ?? 1,
                maxSpeed: smc.pointee.getValue("F\(i)Mx") ?? 1,
                value: smc.pointee.getValue("F\(i)Ac") ?? 0,
                mode: self.getFanMode(i)
            ))
        }
    }
    
    public override func read() {
        for i in 0..<self.list.count {
            self.list[i].value = smc.pointee.getValue("F\(self.list[i].id)Ac") ?? 0
        }
        self.callback(self.list)
    }
    
    private func getFanMode(_ id: Int) -> FanMode {
        let fansMode: Int = Int(self.smc.pointee.getValue("FS! ") ?? 0)
        var mode: FanMode = .automatic
        
        if fansMode == 0 {
            mode = .automatic
        } else if fansMode == 3 {
            mode = .forced
        } else if fansMode == 1 && id == 0 {
            mode = .forced
        } else if fansMode == 2 && id == 1 {
            mode = .forced
        }
        
        return mode
    }
}
