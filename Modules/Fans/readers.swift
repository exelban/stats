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
            guard let name = smc.pointee.getStringValue("F\(i)ID") else {
                continue
            }
            
            guard let minSpeed = smc.pointee.getValue("F\(i)Mn") else {
                continue
            }
            
            guard let maxSpeed = smc.pointee.getValue("F\(i)Mx") else {
                continue
            }
            
            guard let value = smc.pointee.getValue("F\(i)Ac") else {
                continue
            }
            
            self.list.append(Fan(id: i, name: name, minSpeed: Int(minSpeed), maxSpeed: Int(maxSpeed), value: value))
        }
    }
    
    public override func read() {
        for i in 0..<self.list.count {
            self.list[i].value = smc.pointee.getValue("F\(self.list[i].id)Ac")
        }
        self.callback(self.list)
    }
}
