//
//  main.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

public enum Network_t: String {
    case wifi
    case ethernet
}

public struct NetworkUsage {
    var active: Bool = false
    
    var download: Int64 = 0
    var upload: Int64 = 0
    
    var laddr: String? = nil // local ip
    var paddr: String? = nil // remote ip
    var iaddr: String? = nil // mac adress
    
    var connectionType: Network_t? = nil
    
    var countryCode: String? = nil
    var networkName: String? = nil
    
    mutating func reset() {
        self.active = false
        
        self.download = 0
        self.upload = 0
        
        self.laddr = nil
        self.paddr = nil
        self.iaddr = nil
        
        self.connectionType = nil
        
        self.countryCode = nil
        self.networkName = nil
    }
}

public class Network: Module {
    private var usageReader: UsageReader = UsageReader()
    private let popupView: Popup = Popup()
    
    public init(_ store: UnsafePointer<Store>?) {
        super.init(
            store: store,
            popup: self.popupView,
            settings: nil
        )
        
        self.usageReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        
        self.addReader(self.usageReader)
    }
    
    private func usageCallback(_ value: NetworkUsage?) {
        if value == nil {
            return
        }
        
        self.popupView.usageCallback(value!)
        if let widget = self.widget as? NetworkWidget {
            widget.setValue(upload: value!.upload, download: value!.download)
        }
    }
}
