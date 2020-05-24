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
import ModuleKit
import SystemConfiguration

internal class UsageReader: Reader<NetworkUsage> {
    private var usage: NetworkUsage = NetworkUsage()
    
    private var ifID: String? {
        guard let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) else {
            return nil
        }
        return global["PrimaryInterface"] as? String
    }
    
    public override func setup() {
    }
    
    public override func read() {
        var ifAddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifAddr) == 0 else { return }
        
        var pointer = ifAddr
        var upload: Int64 = 0
        var download: Int64 = 0
        while pointer != nil {
            defer { pointer = pointer?.pointee.ifa_next }
            if let info = getBytesInfo(self.ifID!, pointer!) {
                upload += info.upload
                download += info.download
            }
            if let ip = getIPAddress(self.ifID!, pointer!) {
                if usage.laddr != ip {
                    usage.upload = 0
                    usage.download = 0
                }
                usage.laddr = ip
            }
        }
        freeifaddrs(ifAddr)
        
        if usage.upload != 0 && usage.download != 0 {
            usage.upload = upload - usage.upload
            usage.download = download - usage.download
        }
        self.callback(usage)
        usage.upload = upload
        usage.download = download
    }
    
    private func getBytesInfo(_ id: String, _ pointer: UnsafeMutablePointer<ifaddrs>) -> (upload: Int64, download: Int64)? {
        let name = String(cString: pointer.pointee.ifa_name)
        if name == id {
            let addr = pointer.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_LINK) else {
                return nil
            }
            
            var data: UnsafeMutablePointer<if_data>? = nil
            data = unsafeBitCast(pointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
            
            return (upload: Int64(data?.pointee.ifi_obytes ?? 0), download: Int64(data?.pointee.ifi_ibytes ?? 0))
        }
        
        return nil
    }
    
    private func getIPAddress(_ id: String, _ pointer: UnsafeMutablePointer<ifaddrs>) -> String? {
        let name = String(cString: pointer.pointee.ifa_name)
        if name == id {
            var addr = pointer.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_INET) else {
                return nil
            }
            
            var ip = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(&addr, socklen_t(addr.sa_len), &ip, socklen_t(ip.count), nil, socklen_t(0), NI_NUMERICHOST)
            
            return String(cString: ip)
        }
        
        return nil
    }
}
