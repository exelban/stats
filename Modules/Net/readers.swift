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
    typealias BandwidthUsage = (upload: Int64, download: Int64)
    
    public var store: UnsafePointer<Store>? = nil
    
    private var reachability: Reachability? = nil
    private var usage: Network_Usage = Network_Usage()
    
    private var shouldReportSelectedInterfaceBandwidthOnly = true
    
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
            if self.active {
                self.getDetails()
            }
        }
        self.reachability!.whenUnreachable = { _ in
            if self.active {
                self.usage.reset()
                self.callback(self.usage)
            }
        }
    }
    
    public override func read() {
        let currentUsage: BandwidthUsage
        if shouldReportSelectedInterfaceBandwidthOnly {
            currentUsage = interfaceBandwidthUsage()
        self.usage.totalUpload += self.usage.upload
        self.usage.totalDownload += self.usage.download
        
        } else {
            currentUsage = allProcessesBandwidthUsage()
        }
        
        self.usage.upload = max(currentUsage.upload - self.usage.upload, 0)
        self.usage.download = max(currentUsage.download - self.usage.download, 0)
        
        self.callback(self.usage)
        
        self.usage.upload = currentUsage.upload
        self.usage.download = currentUsage.download
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
    
    private func interfaceBandwidthUsage() -> BandwidthUsage {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        guard getifaddrs(&interfaceAddresses) == 0 else {
            return (0, 0)
        }
        
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
                totalUpload += info.upload
                totalDownload += info.download
            }
        }
        freeifaddrs(interfaceAddresses)
        
        return (totalUpload, totalDownload)
    }
    
    private func allProcessesBandwidthUsage() -> BandwidthUsage {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let error {
            print(error)
            return (0, 0)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        _ = String(decoding: errorData, as: UTF8.self)
        
        if output.isEmpty {
            return (0, 0)
        }

        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        var firstLine = false
        output.enumerateLines { (line, _) -> () in
            if !firstLine {
                firstLine = true
                return
            }
            
            let parsedLine = line.split(separator: ",")
            guard parsedLine.count >= 3 else {
                return
            }
            
            if let download = Int(parsedLine[1]) {
                totalDownload += Int64(download)
            }
            if let upload = Int(parsedLine[2]) {
                totalUpload += Int64(upload)
            }
        }
        
        return (totalUpload, totalDownload)
    }
    
}

public class ProcessReader: Reader<[Network_Process]> {
    private let store: UnsafePointer<Store>
    private let title: String
    private var previous: [Network_Process] = []
    
    private var numberOfProcesses: Int {
        get {
            return self.store.pointee.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    
    init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        super.init()
    }
    
    public override func setup() {
        self.popup = true
    }
    
    public override func read() {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let error {
            print(error)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        _ = String(decoding: errorData, as: UTF8.self)
        
        if output.isEmpty {
            return
        }

        var list: [Network_Process] = []
        var firstLine = false
        output.enumerateLines { (line, _) -> () in
            if !firstLine {
                firstLine = true
                return
            }
            
            let parsedLine = line.split(separator: ",")
            guard parsedLine.count >= 3 else {
                return
            }
            
            var process = Network_Process()
            process.time = Date()
            
            let nameArray = parsedLine[0].split(separator: ".")
            if let pid = nameArray.last {
                process.pid = String(pid)
            }
            if let app = NSRunningApplication(processIdentifier: pid_t(process.pid) ?? 0) {
                process.name = app.localizedName ?? nameArray.dropLast().joined(separator: ".")
                process.icon = app.icon
            } else {
                process.name = nameArray.dropLast().joined(separator: ".")
            }
            
            if let download = Int(parsedLine[1]) {
                process.download = download
            }
            if let upload = Int(parsedLine[2]) {
                process.upload = upload
            }
            
            list.append(process)
        }
        
        var processes: [Network_Process] = []
        if self.previous.count == 0 {
            self.previous = list
            processes = list
        } else {
            self.previous.forEach { (pp: Network_Process) in
                if let i = list.firstIndex(where: { $0.pid == pp.pid }) {
                    let p = list[i]
                    
                    var download = p.download - pp.download
                    var upload = p.upload - pp.upload
                    let time = download == 0 && upload == 0 ? pp.time : Date()
                    list[i].time = time
                    
                    if download < 0 {
                        download = 0
                    }
                    if upload < 0 {
                        upload = 0
                    }
                    
                    processes.append(Network_Process(time: time, name: p.name, pid: p.pid, download: download, upload:  upload, icon: p.icon))
                }
            }
            self.previous = list
        }
        
        processes.sort {
            if $0.download != $1.download {
                return $0.download < $1.download
            } else if $0.upload < $1.upload {
                return $0.upload < $1.upload
            } else {
                return $0.time < $1.time
            }
        }
        
        self.callback(processes.suffix(self.numberOfProcesses).reversed())
    }
}
