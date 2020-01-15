//
//  NetworkReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkReader: Reader {
    public var name: String = "Network"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    public var callback: ([Double]) -> Void = {_ in}
    
    private var uploadValue: Int64 = 0
    private var downloadValue: Int64 = 0
    
    init(_ updater: @escaping ([Double]) -> Void) {
        self.callback = updater
        
        if self.available {
            self.read()
        }
    }
    
    public func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil

        var upload: Int64 = 0
        var download: Int64 = 0
        guard getifaddrs(&interfaceAddresses) == 0 else { return }

        var pointer = interfaceAddresses
        while pointer != nil {
            guard let info = getDataUsageInfo(from: pointer!) else {
                pointer = pointer!.pointee.ifa_next
                continue
            }
            pointer = pointer!.pointee.ifa_next
            upload += info[0]
            download += info[1]
        }
        freeifaddrs(interfaceAddresses)
        
        let lastUpload = self.uploadValue
        let lastDownload = self.downloadValue

        if lastUpload != 0 && lastDownload != 0 {
            DispatchQueue.main.async(execute: {
                self.callback([Double(download - lastDownload), Double(upload - lastUpload)])
            })
        }

        self.uploadValue = upload
        self.downloadValue = download
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
    
    private func getDataUsageInfo(from infoPointer: UnsafeMutablePointer<ifaddrs>) -> [Int64]? {
        let pointer = infoPointer

        let name: String! = String(cString: infoPointer.pointee.ifa_name)
        let addr = pointer.pointee.ifa_addr.pointee
        guard addr.sa_family == UInt8(AF_LINK) else { return nil }
        var networkData: UnsafeMutablePointer<if_data>? = nil
        
        if name.hasPrefix("en") {
            networkData = unsafeBitCast(pointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
            return [Int64(networkData?.pointee.ifi_obytes ?? 0), Int64(networkData?.pointee.ifi_ibytes ?? 0)] // upload, download
        }
        
        return nil
    }
}
