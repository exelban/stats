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

public struct NetworkUsage {
    var laddr: String = ""
    var download: Int64 = 0
    var upload: Int64 = 0
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
        
        if let widget = self.widget as? NetworkWidget {
            widget.setValue(upload: value!.upload, download: value!.download)
        }
    }
}
