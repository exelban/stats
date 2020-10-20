//
//  main.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 20/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

public struct Fan {
    public let id: Int
    public let name: String
    public let minSpeed: Int
    public let maxSpeed: Int
}

public class Fans: Module {
    private let store: UnsafePointer<Store>
    private var smc: UnsafePointer<SMCService>
    
    private var fansReader: FansReader
    
    public init(_ store: UnsafePointer<Store>, _ smc: UnsafePointer<SMCService>) {
        self.store = store
        self.smc = smc
        self.fansReader = FansReader(smc)
        
        super.init(
            store: store,
            popup: nil,
            settings: nil
        )
        guard self.available else { return }
        
        self.fansReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.fansReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        
        self.addReader(self.fansReader)
    }
    
    public override func isAvailable() -> Bool {
        return smc.pointee.getValue("FNum") != nil && smc.pointee.getValue("FNum") != 0
    }
    
    private func usageCallback(_ value: [Fan]?) {
        if value == nil {
            return
        }
    }
}
