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
import AppKit
import Kit
import CoreBluetooth
import IOBluetooth

internal struct bleDevice {
    var name: String?
    var address: String
    var uuid: UUID?
    var batteryLevel: [KeyValue_t]
    var vendorId: Int? = nil
    var productId: Int? = nil
}

private struct ioDevice {
    var name: String
    var address: String
    var rssi: Int8
    var isConnected: Bool
    var isPaired: Bool
}

internal class DevicesReader: Reader<[BLEDevice]>, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var devices: [BLEDevice] = []
    private var devicesToRemove: [UUID] = []
    private var manager: CBCentralManager?
    
    private var characteristicsDict: [UUID: CBCharacteristic] = [:]
    private var bleLevels: [UUID: KeyValue_t] = [:]
    private let stateQueue = DispatchQueue(label: "eu.exelban.Stats.Bluetooth.DevicesReader")
    
    private var profilerCache: (ts: Date, value: ([bleDevice], [String]))? = nil
    private var pmsetCache: (ts: Date, value: [bleDevice])? = nil
    private let profilerTTL: TimeInterval = 30
    private let pmsetTTL: TimeInterval = 10
    
    static let batteryServiceUUID = CBUUID(string: "0x180F")
    static let batteryCharacteristicsUUID = CBUUID(string: "0x2A19")
    
    init(callback: @escaping (T?) -> Void = {_ in }) {
        super.init(.bluetooth, callback: callback)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    public override func start() {
        super.start()
        self.stateQueue.sync {
            if self.manager == nil {
                self.manager = CBCentralManager(delegate: self, queue: nil)
            }
        }
    }
    
    public override func stop() {
        super.stop()
        self.releaseManager()
    }
    
    public override func terminate() {
        self.releaseManager()
    }
    
    private func releaseManager() {
        self.stateQueue.sync {
            guard let manager = self.manager else { return }
            if manager.isScanning {
                manager.stopScan()
            }
            manager.delegate = nil
            self.manager = nil
            self.characteristicsDict = [:]
            for i in self.devices.indices {
                self.devices[i].peripheral = nil
                self.devices[i].isPeripheralInitialized = false
            }
        }
    }
    
    private func startScan(_ central: CBCentralManager) {
        guard self.active, central.state == .poweredOn, !central.isScanning else { return }
        central.scanForPeripherals(withServices: [DevicesReader.batteryServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    @objc private func willSleep() {
        guard let manager = self.manager, manager.isScanning else { return }
        manager.stopScan()
    }
    
    @objc private func didWake() {
        guard let manager = self.manager else { return }
        self.startScan(manager)
    }
    
    public override func read() {
        let hid = self.HIDDevices()
        let SPB = self.profilerDevices()
        var list = self.cacheDevices()
        let pmsetLevels = self.pmsetAccessoryLevels()
        
        hid.forEach { v in
            if let idx = list.firstIndex(where: { $0.address == v.address }) {
                list[idx].batteryLevel = v.batteryLevel
                list[idx].vendorId = v.vendorId ?? list[idx].vendorId
                list[idx].productId = v.productId ?? list[idx].productId
            } else {
                list.append(v)
            }
        }
        SPB.0.forEach { v in
            if !list.contains(where: {$0.address == v.address}) {
                list.append(v)
            }
        }
        
        let pairedDevices: [ioDevice] = IOBluetoothDevice.pairedDevices()?.compactMap({
            if let device = $0 as? IOBluetoothDevice, device.isPaired() || device.isConnected() {
                return ioDevice(
                    name: device.nameOrAddress,
                    address: device.addressString,
                    rssi: device.rssi(),
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired()
                )
            }
            return nil
        }) ?? []
        
        let snapshot: [BLEDevice] = self.stateQueue.sync {
            self.devices = self.devices.filter { (d: BLEDevice) in
                pairedDevices.contains(where: { $0.address == d.address })
            }
            
            pairedDevices.forEach { (device: ioDevice) in
                guard let data = list.first(where: { $0.address == device.address }) else {
                    return
                }
                
                let hasHID = hid.contains(where: { $0.address == device.address })
                let rssi = device.rssi == 127 ? (hasHID ? 100 : nil) : Int(device.rssi)
                if let idx = self.devices.firstIndex(where: { $0.address == data.address }) {
                    self.devices[idx].RSSI = rssi
                    self.devices[idx].batteryLevel = data.batteryLevel
                    self.devices[idx].isPaired = device.isPaired
                    self.devices[idx].isConnected = device.isConnected || hasHID
                    if self.devices[idx].vendorId == nil { self.devices[idx].vendorId = data.vendorId }
                    if self.devices[idx].productId == nil { self.devices[idx].productId = data.productId }
                    
                    return
                }
                
                self.devices.append(BLEDevice(
                    address: data.address,
                    name: data.name ?? device.name,
                    uuid: data.uuid,
                    RSSI: rssi,
                    batteryLevel: data.batteryLevel,
                    isConnected: device.isConnected || hasHID,
                    isPaired: device.isPaired,
                    vendorId: data.vendorId,
                    productId: data.productId
                ))
            }
            
            let peripherals = self.manager?.retrievePeripherals(withIdentifiers: self.devices.compactMap({ $0.uuid })) ?? []
            peripherals.forEach { (p: CBPeripheral) in
                guard let idx = self.devices.firstIndex(where: { $0.uuid == p.identifier }) else {
                    return
                }
                
                if self.devices[idx].peripheral == nil {
                    self.devices[idx].peripheral = p
                }
                
                if p.state == .disconnected {
                    if let manager = self.manager, manager.state == .poweredOn {
                        manager.connect(p, options: nil)
                    }
                } else if p.state == .disconnecting {
                    self.devicesToRemove.append(p.identifier)
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
            
            if !self.devicesToRemove.isEmpty {
                self.devices = self.devices.filter { (d: BLEDevice) -> Bool in
                    if let uuid = d.uuid, self.devicesToRemove.contains(uuid) {
                        return false
                    }
                    return true
                }
                self.devicesToRemove = []
            }
            if !SPB.1.isEmpty {
                self.devices = self.devices.filter { (d: BLEDevice) in
                    !SPB.1.contains(d.address) || d.isConnected
                }
            }
            
            var matchedDevices: Set<String> = []
            pmsetLevels.forEach { p in
                if let idx = DevicesReader.accessoryDeviceIndex(p, devices: self.devices, hidDevices: hid, excluding: matchedDevices) {
                    if !p.batteryLevel.isEmpty {
                        self.devices[idx].batteryLevel = p.batteryLevel
                    }
                    self.devices[idx].isConnected = true
                    if self.devices[idx].RSSI == nil { self.devices[idx].RSSI = 100 }
                    matchedDevices.insert(self.devices[idx].address)
                    return
                }
                
                self.devices.append(BLEDevice(
                    address: p.address,
                    name: p.name ?? "",
                    uuid: p.uuid,
                    RSSI: 100,
                    batteryLevel: p.batteryLevel,
                    isConnected: true,
                    isPaired: false,
                    vendorId: p.vendorId,
                    productId: p.productId
                ))
                matchedDevices.insert(p.address)
            }
            
            return self.devices.filter({ $0.RSSI != nil })
        }
        self.callback(snapshot)
    }
    
    internal static func accessoryDeviceIndex(_ accessory: bleDevice, devices: [BLEDevice], hidDevices: [bleDevice], excluding: Set<String> = []) -> Int? {
        func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ":", with: "-").lowercased()
        }
        
        let candidates = devices.indices.filter({ !excluding.contains(devices[$0].address) })
        let address = normalized(accessory.address)
        if !address.isEmpty, let idx = candidates.first(where: { normalized(devices[$0].address) == address }) {
            return idx
        }
        
        let name = normalized(accessory.name ?? "")
        if !name.isEmpty {
            let hidAddresses = Set(hidDevices.filter({ normalized($0.name ?? "") == name }).map({ normalized($0.address) }))
            if hidAddresses.count > 1 { return nil }
            let hidMatches = candidates.filter({ hidAddresses.contains(normalized(devices[$0].address)) })
            if hidMatches.count == 1 { return hidMatches[0] }

            let nameMatches = candidates.filter({ normalized(devices[$0].name) == name })
            if nameMatches.count == 1 { return nameMatches[0] }
        }

        if let vendorId = accessory.vendorId, let productId = accessory.productId {
            let matches = candidates.filter({ devices[$0].vendorId == vendorId && devices[$0].productId == productId })
            if matches.count == 1 { return matches[0] }
        }
        
        return nil
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
            
            let vendorId = d.object(forKey: "VendorID") as? Int
            let productId = d.object(forKey: "ProductID") as? Int
            address = address.replacingOccurrences(of: ":", with: "-").lowercased()
            list.append(bleDevice(name: name, address: address, uuid: nil, batteryLevel: [KeyValue_t(key: "battery", value: "\(batteryPercent)")], vendorId: vendorId, productId: productId))
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
    
    // MARK: - system_profiler
    
    private func profilerDevices() -> ([bleDevice], [String]) {
        if let cache = self.stateQueue.sync(execute: { self.profilerCache }), Date().timeIntervalSince(cache.ts) < self.profilerTTL {
            return cache.value
        }
        let value = self.fetchProfilerDevices()
        self.stateQueue.sync { self.profilerCache = (Date(), value) }
        return value
    }
    
    private func pmsetAccessoryLevels() -> [bleDevice] {
        if let cache = self.stateQueue.sync(execute: { self.pmsetCache }), Date().timeIntervalSince(cache.ts) < self.pmsetTTL {
            return cache.value
        }
        let value = self.fetchPmsetAccessoryLevels()
        self.stateQueue.sync { self.pmsetCache = (Date(), value) }
        return value
    }
    
    private func fetchProfilerDevices() -> ([bleDevice], [String]) {
        guard let res = process(path: "/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"], timeout: 10) else {
            return ([], [])
        }
        
        var list: [bleDevice] = []
        var notConnected: [String] = []
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(res.utf8), options: []) as? [String: Any] {
                guard let arr = json["SPBluetoothDataType"] as? [[String: Any]], let data = arr.first else {
                    return (list, notConnected)
                }
                
                if let rawList = data["device_connected"] as? [[String: [String: Any]]], let devices = rawList.first {
                    for obj in devices {
                        var batteryLevel: [KeyValue_t] = []
                        
                        for key in ["device_batteryLevelCase", "device_batteryLevelLeft", "device_batteryLevelRight", "Left Battery Level", "Right Battery Level", "device_batteryLevelMain"] {
                            if let pair = obj.value.first(where: { $0.key == key }) {
                                batteryLevel.append(KeyValue_t(key: key, value: (pair.value as? String)?.replacingOccurrences(of: "%", with: "") ?? "-1"))
                            }
                        }
                        
                        let address = obj.value["device_address"] as? String ?? ""
                        list.append(bleDevice(
                            name: obj.key,
                            address: address.replacingOccurrences(of: ":", with: "-").lowercased(),
                            batteryLevel: batteryLevel
                        ))
                    }
                }
                if let rawList = data["device_not_connected"] as? [[String: [String: String]]] {
                    for device in rawList {
                        for d in device.values {
                            if let addr = d["device_address"] {
                                notConnected.append(addr.replacingOccurrences(of: ":", with: "-").lowercased())
                            }
                        }
                    }
                }
            }
        } catch let err as NSError {
            error("error to parse system_profiler SPBluetoothDataType: \(err.localizedDescription)")
            return (list, notConnected)
        }
        
        return (list, notConnected)
    }
    
    // MARK: - CBCentralManager
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && self.active {
            self.startScan(central)
        } else if central.isScanning {
            central.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.stateQueue.sync {
            self.devicesToRemove.append(peripheral.identifier)
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
        
        self.stateQueue.sync {
            self.characteristicsDict[peripheral.identifier] = batteryCharacteristics
        }
        peripheral.readValue(for: batteryCharacteristics)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            error_msg("didUpdateValueFor: \(error!)")
            return
        }
        
        if let batteryLevel = characteristic.value?.first {
            self.stateQueue.sync {
                self.bleLevels[peripheral.identifier] = KeyValue_t(key: "battery", value: "\(batteryLevel)")
            }
        }
    }
    
    // MARK: - PMSET data
    private func fetchPmsetAccessoryLevels() -> [bleDevice] {
        guard let res = process(path: "/usr/bin/pmset", arguments: ["-g", "accps", "-xml"], timeout: 10) else { return [] }
        
        let plists = res.components(separatedBy: "<?xml")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .compactMap { chunk -> [String: Any]? in
                let xml = "<?xml" + chunk
                guard let data = xml.data(using: .utf8),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                    return nil
                }
                return plist
            }
        
        struct PmsetEntry {
            let name: String
            let capacity: Int
            let accessoryIdentifier: String
            let partIdentifier: String?
            let groupIdentifier: String?
            let category: String?
            let isCharging: Bool
            let vendorId: Int?
            let productId: Int?
            let combinedParts: [[String: Any]]?
        }
        
        var entries: [PmsetEntry] = []
        for dict in plists {
            guard let name = dict["Name"] as? String,
                  let capacity = dict["Current Capacity"] as? Int,
                  let accessoryId = dict["Accessory Identifier"] as? String else { continue }
            
            let isCharging: Bool
            if let charging = dict["Is Charging"] as? Bool {
                isCharging = charging
            } else if let state = dict["Power Source State"] as? String {
                isCharging = state == "AC Power"
            } else {
                isCharging = false
            }
            
            entries.append(PmsetEntry(
                name: name,
                capacity: capacity,
                accessoryIdentifier: accessoryId,
                partIdentifier: dict["Part Identifier"] as? String,
                groupIdentifier: dict["Group Identifier"] as? String,
                category: dict["Accessory Category"] as? String,
                isCharging: isCharging,
                vendorId: dict["Vendor ID"] as? Int,
                productId: dict["Product ID"] as? Int,
                combinedParts: dict["Combined Parts"] as? [[String: Any]]
            ))
        }
        
        var grouped: [String: [PmsetEntry]] = [:]
        var standalone: [PmsetEntry] = []
        for entry in entries {
            if let groupId = entry.groupIdentifier {
                grouped[groupId, default: []].append(entry)
            } else {
                standalone.append(entry)
            }
        }
        
        var out: [bleDevice] = []
        
        for entry in standalone {
            let state = entry.isCharging ? "charging" : "discharging"
            out.append(bleDevice(
                name: entry.name,
                address: entry.accessoryIdentifier,
                uuid: nil,
                batteryLevel: [KeyValue_t(key: "battery", value: "\(entry.capacity)", additional: state)],
                vendorId: entry.vendorId,
                productId: entry.productId
            ))
        }
        
        for (_, group) in grouped {
            let combinedEntry = group.first(where: { $0.partIdentifier == "Combined" })
            let caseEntry = group.first(where: { $0.partIdentifier == "Case" || $0.category == "Audio Battery Case" })
            let displayName = combinedEntry?.name ?? group.first(where: { !($0.category ?? "").contains("Case") })?.name ?? group.first?.name ?? ""
            let accessoryId = combinedEntry?.accessoryIdentifier ?? group.first?.accessoryIdentifier ?? ""
            
            var kv: [KeyValue_t] = []
            
            if let c = caseEntry {
                let state = c.isCharging ? "charging" : "discharging"
                kv.append(KeyValue_t(key: "case", value: "\(c.capacity)", additional: state))
            }
            
            if let parts = combinedEntry?.combinedParts {
                for part in parts {
                    guard let partId = part["Part Identifier"] as? String,
                          let cap = part["Current Capacity"] as? Int else { continue }
                    let charging = (part["Is Charging"] as? Bool) ?? false
                    let state = charging ? "charging" : "discharging"
                    kv.append(KeyValue_t(key: partId.lowercased(), value: "\(cap)", additional: state))
                }
            }
            
            if kv.isEmpty, let e = combinedEntry ?? group.first {
                let state = e.isCharging ? "charging" : "discharging"
                kv.append(KeyValue_t(key: "battery", value: "\(e.capacity)", additional: state))
            }
            
            let vendorId = combinedEntry?.vendorId ?? group.first?.vendorId
            let productId = combinedEntry?.productId ?? group.first?.productId
            out.append(bleDevice(
                name: displayName,
                address: accessoryId,
                uuid: nil,
                batteryLevel: kv,
                vendorId: vendorId,
                productId: productId
            ))
        }
        
        return out
    }
}
