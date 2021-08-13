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

public enum BLEConnType: Int {
    case ioDevice
    case cache
    case ble
}

public struct BLEDevice {
    let conn: BLEConnType
    
    let address: String
    let name: String
    var uuid: UUID?
    
    var RSSI: Int? = nil
    var batteryLevel: [KeyValue_t] = []
    
    var isConnected: Bool = false
    var isPaired: Bool = false
    
    var peripheral: CBPeripheral?
    var isPeripheralConnected: Bool = false
}

public class Bluetooth: Module {
    private var devicesReader: DevicesReader? = nil
    private let popupView: Popup = Popup()
    private let settingsView: Settings
    
    private var selectedBattery: String = ""
    
    public init() {
        self.settingsView = Settings("Bluetooth")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.devicesReader = DevicesReader()
        self.selectedBattery = Store.shared.string(key: "\(self.config.name)_battery", defaultValue: self.selectedBattery)
        
        self.settingsView.selectedBatteryHandler = { [unowned self] value in
            self.selectedBattery = value
        }
        
        self.devicesReader?.callbackHandler = { [unowned self] value in
            self.batteryCallback(value)
        }
        self.devicesReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        if let reader = self.devicesReader {
            self.addReader(reader)
        }
    }
    
    private func batteryCallback(_ raw: [BLEDevice]?) {
        guard let value = raw else {
            return
        }
        
        let active = value.filter{ $0.isPaired && ($0.isConnected || !$0.batteryLevel.isEmpty) }
        DispatchQueue.main.async(execute: {
            self.popupView.batteryCallback(active)
        })
        self.settingsView.setList(active)
        
        var battery = active.first?.batteryLevel.first
        if self.selectedBattery != "" {
            let pair = self.selectedBattery.split(separator: "@")
            
            guard let device = value.first(where: { $0.name == pair.first! }) else {
//                error("cannot find selected battery: \(self.selectedBattery)")
                return
            }
            
            if pair.count == 1 {
                battery = device.batteryLevel.first
            } else if pair.count == 2 {
                battery = device.batteryLevel.first{ $0.key == pair.last! }
            }
        }
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini:
                guard let percentage = Double(battery?.value ?? "0") else {
                    return
                }
                widget.setValue(percentage/100)
            case let widget as BatterykWidget:
                var percentage: Double? = nil
                if let value = battery?.value {
                    percentage = (Double(value) ?? 0) / 100
                }
                widget.setValue(percentage: percentage)
            default: break
            }
        }
    }
}
