//
//  readers.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit
import SystemConfiguration
import Reachability
import os.log
import CoreWLAN

internal class UsageReader: Reader<Network_Usage> {
    public var store: UnsafePointer<Store>? = nil
    private var reachability: Reachability? = nil
    private var usage: Network_Usage = Network_Usage()
    
    private var primaryInterface: String {
        get {
            if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString), let name = global["PrimaryInterface"] as? String {
                return name
            }
            return "eth0"
        }
    }
    
    private var interfaceID: String {
        get {
            return self.store?.pointee.string(key: "network_interface", defaultValue: self.primaryInterface) ?? self.primaryInterface
        }
        set {
            self.store?.pointee.set(key: "network_interface", value: newValue)
        }
    }
    
    public override func setup() {
        do {
            self.reachability = try Reachability()
            try self.reachability!.startNotifier()
        } catch let error {
            os_log(.error, log: log, "initialize Reachability error %s", "\(error)")
        }
        
        self.reachability!.whenReachable = { _ in
            self.usage.reset()  
            self.readInformation()
        }
        self.reachability!.whenUnreachable = { _ in
            self.usage.reset()
            self.callback(self.usage)
        }
    }
    
    public override func read() {
        guard self.reachability?.connection != .unavailable else {
            if self.usage.active {
                self.usage.reset()
                self.callback(self.usage)
            }
            return
        }
        
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        var upload: Int64 = 0
        var download: Int64 = 0
        guard getifaddrs(&interfaceAddresses) == 0 else { return }
        
        var pointer = interfaceAddresses
        while pointer != nil {
            defer { pointer = pointer?.pointee.ifa_next }
            
            if String(cString: pointer!.pointee.ifa_name) != self.interfaceID {
                continue
            }
            
            if let info = getBytesInfo(pointer!) {
                upload += info.upload
                download += info.download
            }
            
            if let ip = getLocalIP(pointer!), self.usage.laddr != ip {
                self.usage.laddr = ip
            }
        }
        freeifaddrs(interfaceAddresses)
        
        if self.usage.upload != 0 && self.usage.download != 0 {
            self.usage.upload = upload - self.usage.upload
            self.usage.download = download - self.usage.download
        }
        
        self.callback(self.usage)
        self.usage.upload = upload
        self.usage.download = download
    }
    
    private func readInformation() {
        guard self.reachability != nil && self.reachability!.connection != .unavailable else { return }
        
        self.usage.active = true
        DispatchQueue.global(qos: .background).async {
            self.usage.paddr = self.getPublicIP()
        }
        
        if self.reachability!.connection == .wifi {
            self.usage.connectionType = .wifi
            if let interface = CWWiFiClient.shared().interface() {
                self.usage.networkName = interface.ssid()
                self.usage.countryCode = interface.countryCode()
                self.usage.iaddr = interface.hardwareAddress()
            }
        } else {
            self.usage.connectionType = .ethernet
            self.usage.iaddr = getMacAddress()
        }
    }
    
    private func getDataUsageInfo(from infoPointer: UnsafeMutablePointer<ifaddrs>) -> (upload: Int64, download: Int64)? {
        let pointer = infoPointer
        
        let addr = pointer.pointee.ifa_addr.pointee
        guard addr.sa_family == UInt8(AF_LINK) else { return nil }
        var networkData: UnsafeMutablePointer<if_data>? = nil
        
        networkData = unsafeBitCast(pointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
        return (upload: Int64(networkData?.pointee.ifi_obytes ?? 0), download: Int64(networkData?.pointee.ifi_ibytes ?? 0))
    }
    
    private func getBytesInfo(_ pointer: UnsafeMutablePointer<ifaddrs>) -> (upload: Int64, download: Int64)? {
        let addr = pointer.pointee.ifa_addr.pointee
        
        guard addr.sa_family == UInt8(AF_LINK) else {
            return nil
        }
        
        let data: UnsafeMutablePointer<if_data>? = unsafeBitCast(pointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
        return (upload: Int64(data?.pointee.ifi_obytes ?? 0), download: Int64(data?.pointee.ifi_ibytes ?? 0))
    }
    
    private func getLocalIP(_ pointer: UnsafeMutablePointer<ifaddrs>) -> String? {
        var addr = pointer.pointee.ifa_addr.pointee
        
        guard addr.sa_family == UInt8(AF_INET) else {
            return nil
        }
        
        var ip = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(&addr, socklen_t(addr.sa_len), &ip, socklen_t(ip.count), nil, socklen_t(0), NI_NUMERICHOST)
        
        return String(cString: ip)
    }
    
    private func getPublicIP() -> String? {
        let url = URL(string: "https://api.ipify.org")
        var address: String? = nil
        
        do {
            if let url = url {
                address = try String(contentsOf: url)
                if address!.contains("<") {
                    address = nil
                }
            }
        } catch let error {
            os_log(.error, log: log, "get public ip %s", "\(error)")
        }
        
        return address
    }
    
    // https://stackoverflow.com/questions/31835418/how-to-get-mac-address-from-os-x-with-swift
    private func getMacAddress() -> String? {
        var macAddressAsString : String?
        if let intfIterator = findEthernetInterfaces() {
            if let macAddress = getMACAddress(intfIterator) {
                macAddressAsString = macAddress.map( { String(format:"%02x", $0) } ).joined(separator: ":")
            }
            IOObjectRelease(intfIterator)
        }
        return macAddressAsString
    }
    
    private func findEthernetInterfaces() -> io_iterator_t? {
        let matchingDictUM = IOServiceMatching("IOEthernetInterface");
        if matchingDictUM == nil {
            return nil
        }
        
        let matchingDict = matchingDictUM! as NSMutableDictionary
        matchingDict["IOPropertyMatch"] = [ "IOPrimaryInterface" : true]
        
        var matchingServices : io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &matchingServices) != KERN_SUCCESS {
            return nil
        }
        
        return matchingServices
    }
    
    private func getMACAddress(_ intfIterator : io_iterator_t) -> [UInt8]? {
        var macAddress : [UInt8]?
        var intfService = IOIteratorNext(intfIterator)
        
        while intfService != 0 {
            var controllerService : io_object_t = 0
            if IORegistryEntryGetParentEntry(intfService, kIOServicePlane, &controllerService) == KERN_SUCCESS {
                let dataUM = IORegistryEntryCreateCFProperty(controllerService, "IOMACAddress" as CFString, kCFAllocatorDefault, 0)
                if dataUM != nil {
                    let data = (dataUM!.takeRetainedValue() as! CFData) as Data
                    macAddress = [0, 0, 0, 0, 0, 0]
                    data.copyBytes(to: &macAddress!, count: macAddress!.count)
                }
                IOObjectRelease(controllerService)
            }
            
            IOObjectRelease(intfService)
            intfService = IOIteratorNext(intfIterator)
        }
        
        return macAddress
    }
}
