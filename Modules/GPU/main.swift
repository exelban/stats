//
//  main.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

public struct GPU_Load {}

public class GPU: Module {
    private let smc: UnsafePointer<SMCService>?
    private let store: UnsafePointer<Store>
    
    private var loadReader: LoadReader? = nil
    
    public init(_ store: UnsafePointer<Store>, _ smc: UnsafePointer<SMCService>) {
        self.store = store
        self.smc = smc
        
        super.init(
            store: store,
            popup: nil,
            settings: nil
        )
        guard self.available else { return }
        
        self.loadReader = LoadReader()
        
        self.loadReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        if let reader = self.loadReader {
            self.addReader(reader)
        }
    }
}
