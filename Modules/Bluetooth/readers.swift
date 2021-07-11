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
    private let ble: BluetoothDelegate = BluetoothDelegate()
    
    init() {
        super.init()
    }
    
    public override func read() {
        self.ble.read()
        self.callback(self.ble.devices)
    }
}

class BluetoothDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var manager: CBCentralManager!
    private let cache = UserDefaults(suiteName: "/Library/Preferences/com.apple.Bluetooth")
    
    private var peripherals: [CBPeripheral] = []
    public var devices: [BLEDevice] = []
    private var characteristicsDict: [UUID: CBCharacteristic] = [:]
    
    private let batteryServiceUUID = CBUUID(string: "0x180F")
    private let batteryCharacteristicsUUID = CBUUID(string: "0x2A19")
    
    override init() {
        super.init()
        self.manager = CBCentralManager.init(delegate: self, queue: nil)
    }
    
    public func read() {
        IOBluetoothDevice.pairedDevices().forEach { (d) in
            guard let device = d as? IOBluetoothDevice,
                  let cache = self.findInCache(address: device.addressString) else {
                return
            }
            
            let rssi = device.rawRSSI() == 127 ? nil : Int(device.rawRSSI())
            
            if let idx = self.devices.firstIndex(where: { $0.uuid == cache.uuid }) {
                self.devices[idx].isConnected = device.isConnected()
                self.devices[idx].isPaired = device.isPaired()
                self.devices[idx].RSSI = rssi
            } else {
                self.devices.append(BLEDevice(
                    uuid: cache.uuid,
                    name: device.nameOrAddress,
                    type: .unknown,
                    RSSI: rssi,
                    batteryLevel: cache.batteryLevel,
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired(),
                    isInitialized: false
                ))
            }
        }
    }
    
    private func findInCache(address: String) -> (uuid: UUID, batteryLevel: [KeyValue_t])? {
        guard let plist = self.cache,
              let deviceCache = plist.object(forKey: "DeviceCache") as? [String: [String: Any]],
              let coreCache = plist.object(forKey: "CoreBluetoothCache") as? [String: [String: Any]] else {
            return nil
        }
        
        guard let uuid = coreCache.compactMap({ (key, dict) -> UUID? in
            guard let field = dict.first(where: { $0.key == "DeviceAddress" }),
                  let value = field.value as? String,
                  value == address else {
                return nil
            }
            return UUID(uuidString: key)
        }).first else {
            return nil
        }
        
        var batteryLevel: [KeyValue_t] = []
        if let d = deviceCache.first(where: { $0.key == address }) {
            d.value.forEach { (key, value) in
                guard let value = value as? Int, key == "BatteryPercentCase" || key == "BatteryPercentLeft" || key == "BatteryPercentRight" else {
                    return
                }
                
                batteryLevel.append(KeyValue_t(key: key, value: "\(value)"))
            }
        }
        
        return (uuid, batteryLevel)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOff {
            self.manager.stopScan()
        } else if central.state == .poweredOn {
            self.manager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let idx = self.devices.firstIndex(where: { $0.uuid == peripheral.identifier }) else {
            return
        }
        
        if self.devices[idx].RSSI == nil {
            self.devices[idx].RSSI = Int(truncating: RSSI)
        }
        
        if self.devices[idx].peripheral == nil {
            self.devices[idx].peripheral = peripheral
        }
        
        if peripheral.state == .disconnected {
            central.connect(peripheral, options: nil)
        } else if peripheral.state == .connected && !self.devices[idx].isInitialized {
            peripheral.delegate = self
            peripheral.discoverServices([batteryServiceUUID])
            self.devices[idx].isInitialized = true
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("didDiscoverServices: ", error!)
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == self.batteryServiceUUID }) else {
            print("battery service not found, skipping")
            return
        }
        
        peripheral.discoverCharacteristics([self.batteryCharacteristicsUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("didDiscoverCharacteristicsFor: ", error!)
            return
        }
        
        guard let batteryCharacteristics = service.characteristics?.first(where: { $0.uuid == self.batteryCharacteristicsUUID }) else {
            print("characteristics not found")
            return
        }
        
        self.characteristicsDict[peripheral.identifier] = batteryCharacteristics
        peripheral.readValue(for: batteryCharacteristics)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("didUpdateValueFor: ", error!)
            return
        }
        
        if let batteryLevel = characteristic.value?[0], let idx = self.devices.firstIndex(where: { $0.uuid == peripheral.identifier }) {
            self.devices[idx].batteryLevel = [KeyValue_t(key: "battery", value: "\(batteryLevel)")]
        }
    }
}
