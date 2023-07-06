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

public struct BLEDevice: Codable {
    let address: String
    var name: String
    var uuid: UUID?
    
    var RSSI: Int? = nil
    var batteryLevel: [KeyValue_t] = []
    
    var isConnected: Bool = false
    var isPaired: Bool = false
    
    var peripheral: CBPeripheral? = nil
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
    
    private enum CodingKeys: String, CodingKey {
        case address, name, uuid, RSSI, batteryLevel, isConnected, isPaired
    }
    
    init(address: String, name: String, uuid: UUID?, RSSI: Int?, batteryLevel: [KeyValue_t], isConnected: Bool, isPaired: Bool) {
        self.address = address
        self.name = name
        self.uuid = uuid
        self.RSSI = RSSI
        self.batteryLevel = batteryLevel
        self.isConnected = isConnected
        self.isPaired = isPaired
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.address = try container.decode(String.self, forKey: .address)
        self.name = try container.decode(String.self, forKey: .name)
        self.uuid = try? container.decode(UUID.self, forKey: .uuid)
        self.RSSI = try? container.decode(Int.self, forKey: .RSSI)
        self.batteryLevel = try container.decode(Array<KeyValue_t>.self, forKey: .batteryLevel)
        self.isConnected = try container.decode(Bool.self, forKey: .isConnected)
        self.isPaired = try container.decode(Bool.self, forKey: .isPaired)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(RSSI, forKey: .RSSI)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(isConnected, forKey: .isConnected)
        try container.encode(isPaired, forKey: .isPaired)
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
        
        var list: [Stack_t] = []
        active.forEach { (d: BLEDevice) in
            if d.state {
                d.batteryLevel.forEach { (p: KeyValue_t) in
                    list.append(Stack_t(key: "\(d.address)-\(p.key)", value: "\(p.value)%"))
                }
            }
        }
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as StackWidget: widget.setValues(list)
            default: break
            }
        }
    }
}
