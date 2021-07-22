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
    
    private var peripherals: [CBPeripheral] = []
    public var devices: [BLEDevice] = []
    private var characteristicsDict: [UUID: CBCharacteristic] = [:]
    
    private let batteryServiceUUID = CBUUID(string: "0x180F")
    private let batteryCharacteristicsUUID = CBUUID(string: "0x2A19")
    
    private let batteryKeys: [String] = [
        "BatteryPercent",
        "BatteryPercentCase",
        "BatteryPercentLeft",
        "BatteryPercentRight"
    ]
    
    override init() {
        super.init()
        self.manager = CBCentralManager.init(delegate: self, queue: nil)
    }
    
    public func read() {
        guard let dict = UserDefaults(suiteName: "/Library/Preferences/com.apple.Bluetooth") else {
            return
        }
        
        IOBluetoothDevice.pairedDevices().forEach { (d) in
            guard let device = d as? IOBluetoothDevice, device.isPaired() || device.isConnected(),
                  let cache = self.findInCache(dict, address: device.addressString) else {
                return
            }
            
            let rssi = device.rawRSSI() == 127 ? nil : Int(device.rawRSSI())
            
            if let idx = self.devices.firstIndex(where: { $0.uuid == cache.uuid }) {
                self.devices[idx].RSSI = rssi
                if cache.batteryLevel.isEmpty {
                    self.devices[idx].batteryLevel = cache.batteryLevel
                }
                self.devices[idx].isConnected = device.isConnected()
                self.devices[idx].isPaired = device.isPaired()
            } else {
                self.devices.append(BLEDevice(
                    uuid: cache.uuid,
                    name: device.nameOrAddress,
                    RSSI: rssi,
                    batteryLevel: cache.batteryLevel,
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired(),
                    isInitialized: false
                ))
            }
        }
    }
    
    private func findInCache(_ cache: UserDefaults, address: String) -> (uuid: UUID, batteryLevel: [KeyValue_t])? {
        guard let deviceCache = cache.object(forKey: "DeviceCache") as? [String: [String: Any]],
              let coreCache = cache.object(forKey: "CoreBluetoothCache") as? [String: [String: Any]] else {
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
            for key in self.batteryKeys {
                if let pair = d.value.first(where: { $0.key == key }) {
                    var percentage: Int = 0
                    switch pair.value {
                    case let value as Int:
                        percentage = value
                    case let value as Double:
                        percentage = Int(value*100)
                    default: continue
                    }
                    
                    batteryLevel.append(KeyValue_t(key: key, value: "\(percentage)"))
                }
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
            error_msg("didDiscoverServices: \(error!)")
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == self.batteryServiceUUID }) else {
            print("battery service not found, skipping")
            return
        }
        
        peripheral.discoverCharacteristics([self.batteryCharacteristicsUUID], for: service)
        
        debug("\(peripheral.identifier): discover bluetooth services")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            error_msg("didDiscoverCharacteristicsFor: \(error!)")
            return
        }
        
        guard let batteryCharacteristics = service.characteristics?.first(where: { $0.uuid == self.batteryCharacteristicsUUID }) else {
            print("characteristics not found")
            return
        }
        
        self.characteristicsDict[peripheral.identifier] = batteryCharacteristics
        peripheral.readValue(for: batteryCharacteristics)
        
        debug("\(peripheral.identifier): discover battery service")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            error_msg("didUpdateValueFor: \(error!)")
            return
        }
        
        if let batteryLevel = characteristic.value?[0], let idx = self.devices.firstIndex(where: { $0.uuid == peripheral.identifier }) {
            self.devices[idx].batteryLevel = [KeyValue_t(key: "battery", value: "\(batteryLevel)")]
        }
        
        debug("\(peripheral.identifier): receive battery update")
    }
}
