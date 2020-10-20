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
    
    init(_ smc: UnsafePointer<SMCService>) {
        self.smc = smc
    }
    
    public override func read() {
        print(1)
    }
}
