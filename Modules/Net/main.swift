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
import SystemConfiguration

public enum Network_t: String {
    case wifi
    case ethernet
    case bluetooth
    case other
}

public struct Network_interface {
    var displayName: String = ""
    var BSDName: String = ""
    var address: String = ""
}

public struct Network_Usage: value_t {
    var download: Int64 = 0
    var upload: Int64 = 0
    
    var laddr: String? = nil // local ip
    var raddr: String? = nil // remote ip
    
    var interface: Network_interface? = nil
    var connectionType: Network_t? = nil
    
    var countryCode: String? = nil
    var ssid: String? = nil
    
    mutating func reset() {
        self.download = 0
        self.upload = 0
        
        self.laddr = nil
        self.raddr = nil
        
        self.interface = nil
        self.connectionType = nil
        
        self.countryCode = nil
        self.ssid = nil
    }
    
    public var widget_value: Double = 0
}

public class Network: Module {
    private var usageReader: UsageReader?
    private let popupView: Popup = Popup()
    private var settingsView: Settings
    
    public init(_ store: UnsafePointer<Store>?) {
        self.settingsView = Settings("Network", store: store!)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.usageReader = UsageReader()
        self.usageReader?.store = store
        
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        
        self.settingsView.callback = { [unowned self] in
            self.usageReader?.getDetails()
            self.usageReader?.read()
        }
        
        if let reader = self.usageReader {
            self.addReader(reader)
        }
    }
    
    public override func isAvailable() -> Bool {
        var list: [String] = []
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                list.append(displayName as String)
            }
        }
        return list.count > 0
    }
    
    private func usageCallback(_ value: Network_Usage?) {
        if value == nil {
            return
        }
        
        self.popupView.usageCallback(value!)
        if let widget = self.widget as? NetworkWidget {
            widget.setValue(upload: value!.upload, download: value!.download)
        }
    }
}
