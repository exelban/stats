//
//  NetworkInterfaceReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 22/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import CoreWLAN
import SystemConfiguration
import Reachability

struct NetworkInterface {
    var active: Bool
    
    var localIP: String?
    var publicIP: String?
    var countryCode: String?
    
    var networkType: String?
    var macAddress: String?
    var wifiName: String?
    
    var force: Bool = false
    
    init(
        active: Bool = false,
        localIP: String? = nil,
        publicIP: String? = nil,
        countryCode: String? = nil,
        networkType: String? = nil,
        macAddress: String? = nil,
        wifiName: String? = nil,
        force: Bool = false
    ) {
        self.active = active
        
        self.localIP = localIP
        self.publicIP = publicIP
        self.countryCode = countryCode
        
        self.networkType = networkType
        self.macAddress = macAddress
        self.wifiName = wifiName
        
        self.force = force
    }
}

class NetworkInterfaceReader: Reader {
    public var name: String = "Interface"
    public var enabled: Bool = false
    public var available: Bool = true
    public var optional: Bool = true
    public var initialized: Bool = false
    public var callback: (NetworkInterface) -> Void = {_ in}
    
    private var uploadValue: Int64 = 0
    private var downloadValue: Int64 = 0
    
    private var publicIP: String? = nil
    private var reachability: Reachability? = nil
    private var forceRead: Bool = false
    
    private var repeatCounter: Int8 = 0
    
    init(_ updater: @escaping (NetworkInterface) -> Void) {
        do {
            self.reachability = try Reachability()
        } catch let error {
            print("initialize Reachability \(error)")
        }
        self.callback = updater
        
        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
        
        if self.reachability != nil {
            self.reachability!.whenReachable = { reachability in
                self.repeatCounter = 0
                self.forceRead = true
                self.read()
            }
            self.reachability!.whenUnreachable = { _ in
                self.forceRead = true
                self.read()
            }

            do {
                try self.reachability!.startNotifier()
            } catch {
                print("Unable to start notifier")
            }
        }
    }
    
    public func read() {
        if (!self.enabled && self.initialized && !self.forceRead) || self.reachability == nil { return }
        self.initialized = true
  
        var result = NetworkInterface(active: false)
        result.force = self.forceRead
        if self.forceRead {
            self.forceRead = false
        }

        if self.reachability!.connection != .unavailable && isConnectedToNetwork() {
            if self.publicIP == nil {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3, execute: {
                    if self.repeatCounter < 5 {
                        self.publicIP = self.getPublicIP()
                        self.forceRead = true
                        self.read()
                        self.repeatCounter += 1
                    } else {
                        self.publicIP = "Unknown"
                    }
                })
            }

            result.active = true

            if self.reachability!.connection == .wifi && CWWiFiClient.shared().interface() != nil {
                result.networkType = "Wi-Fi"
                result.wifiName = CWWiFiClient.shared().interface()!.ssid()
                result.countryCode = CWWiFiClient.shared().interface()!.countryCode()
                result.macAddress = CWWiFiClient.shared().interface()!.hardwareAddress()
            } else {
                result.networkType = "Ethernet"
                result.macAddress = getMacAddress()
            }

            result.localIP = getLocalIP()
            result.publicIP = publicIP
        } else {
            self.publicIP = nil
        }

        DispatchQueue.main.async(execute: {
            self.callback(result)
        })
    }
    
    private func isWIFIActive() -> Bool {
        guard let interfaceNames = CWWiFiClient.interfaceNames() else {
            return false
        }

        for interfaceName in interfaceNames {
            let interface = CWWiFiClient.shared().interface(withName: interfaceName)

            if interface?.ssid() != nil {
                return true
            }
        }
        return false
    }
    
    // https://stackoverflow.com/questions/31835418/how-to-get-mac-address-from-os-x-with-swift
    private func getMacAddress() -> String? {
        var macAddressAsString : String?
        if let intfIterator = FindEthernetInterfaces() {
            if let macAddress = GetMACAddress(intfIterator) {
                macAddressAsString = macAddress.map( { String(format:"%02x", $0) } ).joined(separator: ":")
            }
            IOObjectRelease(intfIterator)
        }
        return macAddressAsString
    }
    
    private func FindEthernetInterfaces() -> io_iterator_t? {
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

    private func GetMACAddress(_ intfIterator : io_iterator_t) -> [UInt8]? {
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
            print("get public ip \(error)")
        }

        return address
    }
    
    private func getLocalIP() -> String {
        var address: String = ""

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "" }
        guard let firstAddr = ifaddr else { return "" }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                } else if name == "en1" {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(1), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
}
