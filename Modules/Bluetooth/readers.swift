//
//  readers.swift
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
import IOBluetooth

internal class DevicesReader: Reader<[BLEDevice]> {
    private let queue = DispatchQueue(label: "eu.exelban.Stats.Bluetooth.reader", attributes: .concurrent)
    
    private var _devices: [BLEDevice] = []
    private var _uuidAddress: [UUID: String] = [:]
    private var peripherals: [CBPeripheral] = []
    private var characteristicsDict: [UUID: CBCharacteristic] = [:]
    
    internal var devices: [BLEDevice] {
        get {
            self.queue.sync { self._devices }
        }
        set {
            self.queue.async(flags: .barrier) {
                self._devices = newValue
            }
        }
    }
    private var uuidAddress: [UUID: String] {
        get {
            self.queue.sync { self._uuidAddress }
        }
        set {
            self.queue.async(flags: .barrier) {
                self._uuidAddress = newValue
            }
        }
    }
    
    private let batteryServiceUUID = CBUUID(string: "0x180F")
    private let batteryCharacteristicsUUID = CBUUID(string: "0x2A19")
    
    init() {
        super.init()
    }
    
    public override func read() {
        self.IODevices()
        self.cacheDevices()
        
        IOBluetoothDevice.pairedDevices()?.forEach({ d in
            guard let device = d as? IOBluetoothDevice, device.isPaired() || device.isConnected(),
                  let idx = self.devices.firstIndex(where: { $0.address == device.addressString }) else {
                return
            }
            
            self.devices[idx].name = device.nameOrAddress
            self.devices[idx].isPaired = device.isPaired()
            self.devices[idx].isConnected = device.isConnected()
        })
        
        self.callback(self.devices)
    }
    
    // MARK: - IODevices
    
    private func IODevices() {
        guard var ioDevices = fetchIOService("AppleDeviceManagementHIDEventService") else {
            return
        }
        ioDevices = ioDevices.filter{ $0.object(forKey: "BluetoothDevice") as? Bool == true }
        
        ioDevices.forEach { (d: NSDictionary) in
            guard let name = d.object(forKey: "Product") as? String, let batteryPercent = d.object(forKey: "BatteryPercent") as? Int else {
                return
            }
            
            var address: String = ""
            if let addr = d.object(forKey: "DeviceAddress") as? String, addr != "" {
                address = addr
            } else if let addr = d.object(forKey: "SerialNumber") as? String, addr != "" {
                address = addr
            } else if let bleAddr = d.object(forKey: "BD_ADDR") as? Data, let addr = String(data: bleAddr, encoding: .utf8), addr != "" {
                address = addr
            }
            
            if let idx = self.devices.firstIndex(where: { $0.address == address && $0.conn == .ioDevice }) {
                self.devices[idx].batteryLevel = [KeyValue_t(key: "battery", value: "\(batteryPercent)")]
            } else {
                self.devices.append(BLEDevice(
                    conn: .ioDevice,
                    address: address,
                    name: name,
                    batteryLevel: [KeyValue_t(key: "battery", value: "\(batteryPercent)")],
                    isConnected: true,
                    isPaired: true
                ))
            }
        }
    }
    
    // MARK: - Cache
    
    private func cacheDevices() {
        guard let cache = UserDefaults(suiteName: "/Library/Preferences/com.apple.Bluetooth"),
              let deviceCache = cache.object(forKey: "DeviceCache") as? [String: [String: Any]],
              let pairedDevices = cache.object(forKey: "PairedDevices") as? [String],
              let coreCache = cache.object(forKey: "CoreBluetoothCache") as? [String: [String: Any]] else {
            return
        }
        
        coreCache.forEach { (key: String, dict: [String: Any]) in
            guard let field = dict.first(where: { $0.key == "DeviceAddress" }),
                  let value = field.value as? String else {
                return
            }
            
            if let uuid = UUID(uuidString: key), self.uuidAddress[uuid] == nil {
                self.uuidAddress[uuid] = value
            }
        }
        
        deviceCache.filter({ pairedDevices.contains($0.key) }).forEach { (address: String, dict: [String: Any]) in
            if self.devices.filter({ $0.conn == .ioDevice || $0.conn == .ble }).contains(where: { $0.address == address }) {
                return
            }
            
            var batteryLevel: [KeyValue_t] = []
            
            for key in ["BatteryPercent", "BatteryPercentCase", "BatteryPercentLeft", "BatteryPercentRight"] {
                if let pair = dict.first(where: { $0.key == key }) {
                    var percentage: Int = 0
                    switch pair.value {
                    case let value as Int:
                        percentage = value
                        if percentage == 1 {
                            percentage *= 100
                        }
                    case let value as Double:
                        percentage = Int(value*100)
                    default: continue
                    }
                    
                    batteryLevel.append(KeyValue_t(key: key, value: "\(percentage)"))
                }
            }
            
            if !batteryLevel.isEmpty {
                let name = dict.first{ $0.key == "Name" }?.value as? String
                
                if let idx = self.devices.firstIndex(where: { $0.address == address && $0.conn == .cache }) {
                    self.devices[idx].batteryLevel = batteryLevel
                    
                    if let device: IOBluetoothDevice = IOBluetoothDevice.pairedDevices().first(where: { d in
                        guard let device = d as? IOBluetoothDevice, device.isPaired() || device.isConnected() else {
                            return false
                        }
                        return device.addressString == address
                    }) as? IOBluetoothDevice {
                        self.devices[idx].RSSI = device.rawRSSI() == 127 ? nil : Int(device.rawRSSI())
                        self.devices[idx].isConnected = device.isConnected()
                        self.devices[idx].isPaired = device.isPaired()
                    }
                } else {
                    self.devices.append(BLEDevice(
                        conn: .cache,
                        address: address,
                        name: name ?? "",
                        batteryLevel: batteryLevel,
                        isPaired: true
                    ))
                }
            }
        }
    }
}
