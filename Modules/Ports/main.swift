//
//  main.swift
//  Ports
//
//  Created by Dogukan Akin on 05/10/2025.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Ports: Module {
    private let popupView: Popup
    private let settingsView: Settings
    
    private var portsReader: PortsReader? = nil
    
    public init() {
        self.settingsView = Settings(.Ports)
        self.popupView = Popup(.Ports)
        
        super.init(
            moduleType: .Ports,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.settingsView.setInterval = { [weak self] value in
            self?.portsReader?.setInterval(value)
        }
        
        self.portsReader = PortsReader(.Ports) { [weak self] value in
            if let ports = value {
                self?.popupView.portsCallback(ports)
            }
        }
        
        self.popupView.setReader(self.portsReader!)
        self.setReaders([self.portsReader])
    }
}
