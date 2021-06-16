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
import Kit
import os.log

internal class FansReader: Reader<[Fan]> {
    internal var list: [Fan] = []
    
    init() {
        super.init()
        
        guard let count = SMC.shared.getValue("FNum") else {
            return
        }
        os_log(.debug, log: self.log, "Found %.0f fans", count)
        
        for i in 0..<Int(count) {
            self.list.append(Fan(
                id: i,
                name: SMC.shared.getStringValue("F\(i)ID") ?? "Fan #\(i)",
                minSpeed: SMC.shared.getValue("F\(i)Mn") ?? 1,
                maxSpeed: SMC.shared.getValue("F\(i)Mx") ?? 1,
                value: SMC.shared.getValue("F\(i)Ac") ?? 0,
                mode: self.getFanMode(i)
            ))
        }
    }
    
    public override func read() {
        for i in 0..<self.list.count {
            self.list[i].value = SMC.shared.getValue("F\(self.list[i].id)Ac") ?? 0
        }
        self.callback(self.list)
    }
    
    private func getFanMode(_ id: Int) -> FanMode {
        let fansMode: Int = Int(SMC.shared.getValue("FS! ") ?? 0)
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
