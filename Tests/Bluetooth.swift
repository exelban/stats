//
//  Bluetooth.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 04/10/2026.
//  Using Swift 6.0.
//  Running on macOS 27.0.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import Cocoa
import Kit

@testable import Bluetooth

class BluetoothTests: XCTestCase {
    private func device(address: String, name: String, vendorId: Int? = nil, productId: Int? = nil) -> BLEDevice {
        BLEDevice(address: address, name: name, uuid: nil, RSSI: 100, batteryLevel: [], isConnected: true, isPaired: true, vendorId: vendorId, productId: productId)
    }
    
    func testChargingKeyboardMatchesHIDAddress() {
        let keyboard = self.device(address: "90-9c-4a-b4-19-38", name: "AuM3 Keyboard")
        let accessory = bleDevice(name: "Magic Keyboard with Touch ID", address: "usb-keyboard", batteryLevel: [])
        let hid = bleDevice(name: accessory.name, address: keyboard.address, batteryLevel: [])
        
        XCTAssertEqual(DevicesReader.accessoryDeviceIndex(accessory, devices: [keyboard], hidDevices: [hid]), 0)
    }
    
    func testAddressMatchTakesPriorityOverName() {
        let first = self.device(address: "90-9c-4a-b4-19-38", name: "Keyboard")
        let second = self.device(address: "90-9c-4a-b4-19-39", name: "Keyboard")
        let accessory = bleDevice(name: "Keyboard", address: "90:9C:4A:B4:19:39", batteryLevel: [])
        
        XCTAssertEqual(DevicesReader.accessoryDeviceIndex(accessory, devices: [first, second], hidDevices: []), 1)
    }
    
    func testAmbiguousHIDNamesDoNotMergeKeyboards() {
        let first = self.device(address: "first", name: "First Keyboard")
        let second = self.device(address: "second", name: "Second Keyboard")
        let accessory = bleDevice(name: "Magic Keyboard", address: "usb-keyboard", batteryLevel: [])
        let hid = [
            bleDevice(name: accessory.name, address: first.address, batteryLevel: []),
            bleDevice(name: accessory.name, address: second.address, batteryLevel: [])
        ]
        
        XCTAssertNil(DevicesReader.accessoryDeviceIndex(accessory, devices: [first, second], hidDevices: hid))
        XCTAssertNil(DevicesReader.accessoryDeviceIndex(accessory, devices: [first], hidDevices: hid))
    }
    
    func testVendorAndProductMatchRequiresOneDevice() {
        let first = self.device(address: "first", name: "First Keyboard", vendorId: 1452, productId: 666)
        let second = self.device(address: "second", name: "Second Keyboard", vendorId: 1452, productId: 666)
        let accessory = bleDevice(name: "Magic Keyboard", address: "usb-keyboard", batteryLevel: [], vendorId: 1452, productId: 666)
        
        XCTAssertEqual(DevicesReader.accessoryDeviceIndex(accessory, devices: [first], hidDevices: []), 0)
        XCTAssertNil(DevicesReader.accessoryDeviceIndex(accessory, devices: [first, second], hidDevices: []))
    }
    
    func testAccessoryCannotReuseMatchedDevice() {
        let keyboard = self.device(address: "keyboard", name: "Keyboard", vendorId: 1452, productId: 666)
        let accessory = bleDevice(name: "Keyboard", address: keyboard.address, batteryLevel: [], vendorId: 1452, productId: 666)
        
        XCTAssertNil(DevicesReader.accessoryDeviceIndex(accessory, devices: [keyboard], hidDevices: [], excluding: [keyboard.address]))
    }
    
    func testSimilarNamesDoNotMergeDifferentDevices() {
        let keyboard = self.device(address: "keyboard", name: "Keyboard")
        let accessory = bleDevice(name: "Second Keyboard", address: "second", batteryLevel: [])
        
        XCTAssertNil(DevicesReader.accessoryDeviceIndex(accessory, devices: [keyboard], hidDevices: []))
    }
    
    func testDeviceReplacementAtSameCount() {
        let popup = Popup()
        let settings = Settings()
        let notifications = Notifications(.bluetooth)
        let transitions = [["bluetooth", "mouse"], ["usb", "mouse"], ["bluetooth", "mouse"], ["mouse"], [], ["usb"]]
        
        func controlIds(_ view: NSView) -> [String] {
            var ids: [String] = []
            if let control = view as? NSControl, let id = control.identifier {
                ids.append(id.rawValue)
            }
            view.subviews.forEach { ids.append(contentsOf: controlIds($0)) }
            return ids
        }
        
        for addresses in transitions {
            let list = addresses.map({ self.device(address: $0, name: $0) })
            popup.batteryCallback(list)
            settings.setList(list)
            notifications.callback(list)
            
            let rows = popup.subviews.compactMap({ $0 as? BLEView })
            XCTAssertEqual(rows.count, addresses.count)
            XCTAssertEqual(Set(rows.map({ $0.address })), Set(addresses))
            
            for view in [settings as NSView, notifications as NSView] {
                let sections = view.subviews.compactMap({ $0 as? PreferencesSection })
                XCTAssertEqual(sections.count, 1)
                guard let section = sections.first else { continue }
                let ids = controlIds(section)
                XCTAssertEqual(ids.count, addresses.count)
                XCTAssertEqual(Set(ids), Set(addresses))
                XCTAssertEqual(section.isHidden, addresses.isEmpty)
            }
        }
    }
}
