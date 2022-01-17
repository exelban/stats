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

private struct bleDevice {
    var name: String?
    var address: String
    var uuid: UUID?
    var batteryLevel: [KeyValue_t]
}

internal class DevicesReader: Reader<[BLEDevice]>, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var devices: [BLEDevice] = []
    private var manager: CBCentralManager!
    
    private var characteristicsDict: [UUID: CBCharacteristic] = [:]
    private var bleLevels: [UUID: KeyValue_t] = [:]
    
    static let batteryServiceUUID = CBUUID(string: "0x180F")
    static let batteryCharacteristicsUUID = CBUUID(string: "0x2A19")
    
    init() {
        super.init()
        self.manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public override func read() {
        let hid = self.HIDDevices()
        var list = self.cacheDevices()
        
        hid.forEach { v in
            if !list.contains(where: {$0.address == v.address}) {
                list.append(v)
            }
        }
        
        IOBluetoothDevice.pairedDevices()?.forEach({ pd in
            guard let device = pd as? IOBluetoothDevice, device.isPaired() || device.isConnected(),
                  let data = list.first(where: { $0.address == device.addressString }) else {
                return
            }
            
            let d = BLEDevice(
                address: data.address,
                name: data.name ?? device.nameOrAddress,
                uuid: data.uuid,
                RSSI: device.rawRSSI() == 127 ? nil : Int(device.rawRSSI()),
                batteryLevel: data.batteryLevel,
                isConnected: device.isConnected(),
                isPaired: device.isPaired()
            )
            
            if let idx = self.devices.firstIndex(where: { $0.address == data.address }) {
                self.devices[idx].RSSI = d.RSSI
                self.devices[idx].batteryLevel = d.batteryLevel
                self.devices[idx].isPaired = d.isPaired
                self.devices[idx].isConnected = d.isConnected
                return
            }
            
            self.devices.append(d)
        })
        
        self.manager.retrievePeripherals(withIdentifiers: self.devices.compactMap({ $0.uuid })).forEach { (p: CBPeripheral) in
            guard let idx = self.devices.firstIndex(where: { $0.uuid == p.identifier }) else {
                return
            }
            
            if self.devices[idx].peripheral == nil {
                self.devices[idx].peripheral = p
            }
            
            if p.state == .disconnected {
                if self.manager.isScanning {
                    self.manager.connect(p, options: nil)
                }
            } else if p.state == .connected && !self.devices[idx].isPeripheralInitialized {
                p.delegate = self
                p.discoverServices([DevicesReader.batteryServiceUUID])
                self.devices[idx].isPeripheralInitialized = true
            }
        }
        
        for (i, d) in self.devices.enumerated() {
            if let uuid = d.uuid, let val = self.bleLevels[uuid] {
                self.devices[i].batteryLevel = [val]
            }
        }
        
        self.callback(self.devices.filter({ $0.RSSI != nil }))
    }
    
    // MARK: - HIDDevices (connected ble peripherals to the mac: keyboard, mouse etc...)
    
    private func HIDDevices() -> [bleDevice] {
        guard let ioDevices = fetchIOService("AppleDeviceManagementHIDEventService") else {
            return []
        }
        
        var list: [bleDevice] = []
        ioDevices.filter{ $0.object(forKey: "BluetoothDevice") as? Bool == true }.forEach { (d: NSDictionary) in
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
            
            list.append(bleDevice(name: name, address: address, uuid: nil, batteryLevel: [KeyValue_t(key: "battery", value: "\(batteryPercent)")]))
        }
        
        return list
    }
    
    // MARK: - Cache
    
    private func cacheDevices() -> [bleDevice] {
        guard let cache = UserDefaults(suiteName: "/Library/Preferences/com.apple.Bluetooth"),
              let deviceCache = cache.object(forKey: "DeviceCache") as? [String: [String: Any]],
              let pairedDevices = cache.object(forKey: "PairedDevices") as? [String],
              let coreCache = cache.object(forKey: "CoreBluetoothCache") as? [String: [String: Any]] else {
            return []
        }
        
        var list: [bleDevice] = []
        deviceCache.filter({ pairedDevices.contains($0.key) }).forEach { (address: String, dict: [String: Any]) in
            let name = dict.first{ $0.key == "Name" }?.value as? String
            var uuid: UUID? = nil
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
            
            coreCache.forEach { (key: String, dict: [String: Any]) in
                guard let field = dict.first(where: { $0.key == "DeviceAddress" }),
                        let value = field.value as? String,
                        value == address else {
                    return
                }
                uuid = UUID(uuidString: key)
            }
            
            list.append(bleDevice(name: name, address: address, uuid: uuid, batteryLevel: batteryLevel))
        }
        
        return list
    }
    
    // MARK: - CBCentralManager
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOff {
            central.stopScan()
        } else if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    // MARK: - CBPeripheral
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            error_msg("didDiscoverServices: \(error!)")
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == DevicesReader.batteryServiceUUID }) else {
            error_msg("battery service not found, skipping")
            return
        }
        
        peripheral.discoverCharacteristics([DevicesReader.batteryCharacteristicsUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {}
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            error_msg("didDiscoverCharacteristicsFor: \(error!)")
            return
        }
        
        guard let batteryCharacteristics = service.characteristics?.first(where: { $0.uuid == DevicesReader.batteryCharacteristicsUUID }) else {
            error_msg("characteristics not found")
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
        
        if let batteryLevel = characteristic.value?[0] {
            self.bleLevels[peripheral.identifier] = KeyValue_t(key: "battery", value: "\(batteryLevel)")
        }
    }
}
