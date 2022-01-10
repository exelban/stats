//
//  main.swift
//  Bluetooth
//
//  Created by Serhiy Mytrovtsiy on 08/06/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import Kit
import CoreBluetooth

public struct BLEDevice {
    let address: String
    var name: String
    var uuid: UUID?
    
    var RSSI: Int? = nil
    var batteryLevel: [KeyValue_t] = []
    
    var isConnected: Bool = false
    var isPaired: Bool = false
    
    var peripheral: CBPeripheral?
    var isPeripheralInitialized: Bool = false
    
    var id: String {
        get {
            return self.uuid?.uuidString ?? self.address
        }
    }
    
    var state: Bool {
        get {
            return Store.shared.bool(key: "ble_\(self.id)", defaultValue: false)
        }
    }
}

public class Bluetooth: Module {
    private var devicesReader: DevicesReader = DevicesReader()
    private let popupView: Popup = Popup()
    private let settingsView: Settings = Settings()
    
    public init() {
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.settingsView.callback = { [unowned self] in
            self.devicesReader.read()
        }
        
        self.devicesReader.callbackHandler = { [unowned self] value in
            self.batteryCallback(value)
        }
        self.devicesReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.addReader(self.devicesReader)
    }
    
    private func batteryCallback(_ raw: [BLEDevice]?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        let active = value.filter{ $0.isPaired || ($0.isConnected && !$0.batteryLevel.isEmpty) }
        DispatchQueue.main.async(execute: {
            self.popupView.batteryCallback(active)
            self.settingsView.setList(active)
        })
        
        var list: [KeyValue_t] = []
        active.forEach { (d: BLEDevice) in
            if d.state {
                d.batteryLevel.forEach { (p: KeyValue_t) in
                    list.append(KeyValue_t(key: p.key, value: "\(p.value)%"))
                }
            }
        }
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SensorsWidget: widget.setValues(list)
            default: break
            }
        }
    }
}
