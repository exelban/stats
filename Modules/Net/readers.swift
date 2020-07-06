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

struct ipResponse: Decodable {
    var ip: String
    var country: String
    var cc: String
}

internal class UsageReader: Reader<Network_Usage> {
    public var store: UnsafePointer<Store>? = nil
    
    private var reachability: Reachability? = nil
    private var usage: Network_Usage = Network_Usage()
    
    private var primaryInterface: String {
        get {
            if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString), let name = global["PrimaryInterface"] as? String {
                return name
            }
            return ""
        }
    }
    
    private var interfaceID: String {
        get {
            return self.store?.pointee.string(key: "Network_interface", defaultValue: self.primaryInterface) ?? self.primaryInterface
        }
        set {
            self.store?.pointee.set(key: "Network_interface", value: newValue)
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
            self.getDetails()
        }
        self.reachability!.whenUnreachable = { _ in
            self.usage.reset()
            self.callback(self.usage)
        }
    }
    
    public override func read() {
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
            
            if let ip = getLocalIP(pointer!), self.usage.laddr != ip {
                self.usage.laddr = ip
            }
            
            if let info = getBytesInfo(pointer!) {
                upload += info.upload
                download += info.download
            }
        }
        freeifaddrs(interfaceAddresses)
        
        if self.usage.upload != 0 && self.usage.download != 0 {
            self.usage.upload = upload - self.usage.upload
            self.usage.download = download - self.usage.download
        }
        
        if self.usage.upload < 0 {
            self.usage.upload = 0
        }
        if self.usage.download < 0 {
            self.usage.download = 0
        }
        
        self.callback(self.usage)
        
        self.usage.upload = upload
        self.usage.download = download
    }
    
    public func getDetails() {
        self.usage.reset()
        
        DispatchQueue.global(qos: .background).async {
            self.getPublicIP()
        }
        
        if self.interfaceID != "" {
            for interface in SCNetworkInterfaceCopyAll() as NSArray {
                if  let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
                    bsdName as String == self.interfaceID,
                    let type = SCNetworkInterfaceGetInterfaceType(interface as! SCNetworkInterface),
                    let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface),
                    let address = SCNetworkInterfaceGetHardwareAddressString(interface as! SCNetworkInterface) {
                    self.usage.interface = Network_interface(displayName: displayName as String, BSDName: bsdName as String, address: address as String)
                    
                    switch type {
                    case kSCNetworkInterfaceTypeEthernet:
                        self.usage.connectionType = .ethernet
                    case kSCNetworkInterfaceTypeIEEE80211, kSCNetworkInterfaceTypeWWAN:
                        self.usage.connectionType = .wifi
                    case kSCNetworkInterfaceTypeBluetooth:
                        self.usage.connectionType = .bluetooth
                    default:
                        self.usage.connectionType = .other
                    }
                }
            }
        }
        
        if let interface = CWWiFiClient.shared().interface(), self.usage.connectionType == .wifi {
            self.usage.ssid = interface.ssid()
            self.usage.countryCode = interface.countryCode()
        }
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
    
    private func getPublicIP() {
        let url = URL(string: "https://api.myip.com")
        var address: String? = nil
        
        do {
            if let url = url {
                address = try String(contentsOf: url)
                
                if address != nil {
                    let jsonData = address!.data(using: .utf8)
                    let response: ipResponse = try JSONDecoder().decode(ipResponse.self, from: jsonData!)
                    
                    self.usage.countryCode = response.cc
                    self.usage.raddr = response.ip
                }
            }
        } catch let error {
            os_log(.error, log: log, "get public ip %s", "\(error)")
        }
    }
    
    private func getBytesInfo(_ pointer: UnsafeMutablePointer<ifaddrs>) -> (upload: Int64, download: Int64)? {
        let addr = pointer.pointee.ifa_addr.pointee
        
        guard addr.sa_family == UInt8(AF_LINK) else {
            return nil
        }
        
        let data: UnsafeMutablePointer<if_data>? = unsafeBitCast(pointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
        return (upload: Int64(data?.pointee.ifi_obytes ?? 0), download: Int64(data?.pointee.ifi_ibytes ?? 0))
    }
}
