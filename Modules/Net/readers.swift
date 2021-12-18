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
import Kit
import SystemConfiguration
import CoreWLAN

struct ipResponse: Decodable {
    var ip: String
    var country: String
    var cc: String
}

internal class UsageReader: Reader<Network_Usage> {
    private var reachability: Reachability = Reachability(start: true)
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
            return Store.shared.string(key: "Network_interface", defaultValue: self.primaryInterface) 
        }
        set {
            Store.shared.set(key: "Network_interface", value: newValue)
        }
    }
    
    private var reader: String {
        get {
            return Store.shared.string(key: "Network_reader", defaultValue: "interface") 
        }
    }
    
    public override func setup() {
        self.reachability.reachable = {
            if self.active {
                self.getDetails()
            }
        }
        self.reachability.unreachable = {
            if self.active {
                self.usage.reset()
                self.callback(self.usage)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPublicIP), name: .refreshPublicIP, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetTotalNetworkUsage), name: .resetTotalNetworkUsage, object: nil)
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1) {
            if self.active {
                self.getDetails()
            }
        }
    }
    
    public override func terminate() {
        self.reachability.stop()
    }
    
    public override func read() {
        let current: Bandwidth = self.reader == "interface" ? self.readInterfaceBandwidth() : self.readProcessBandwidth()
        
        // allows to reset the value to 0 when first read
        if self.usage.bandwidth.upload != 0 {
            self.usage.bandwidth.upload = current.upload - self.usage.bandwidth.upload
        }
        if self.usage.bandwidth.download != 0 {
            self.usage.bandwidth.download = current.download - self.usage.bandwidth.download
        }
        
        self.usage.bandwidth.upload = max(self.usage.bandwidth.upload, 0) // prevent negative upload value
        self.usage.bandwidth.download = max(self.usage.bandwidth.download, 0) // prevent negative download value
        
        self.usage.total.upload += self.usage.bandwidth.upload
        self.usage.total.download += self.usage.bandwidth.download
        
        self.usage.status = self.reachability.isReachable
        
        self.callback(self.usage)
        
        self.usage.bandwidth.upload = current.upload
        self.usage.bandwidth.download = current.download
    }
    
    private func readInterfaceBandwidth() -> Bandwidth {
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
    
    private func readProcessBandwidth() -> Bandwidth {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let err {
            error("read bandwidth from processes: \(err)", log: self.log)
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
        output.enumerateLines { (line, _) -> Void in
            if !firstLine {
                firstLine = true
                return
            }
            
            let parsedLine = line.split(separator: ",")
            guard parsedLine.count >= 3 else {
                return
            }
            
            if let download = Int64(parsedLine[1]) {
                totalDownload += download
            }
            if let upload = Int64(parsedLine[2]) {
                totalUpload += upload
            }
        }
        
        return (totalUpload, totalDownload)
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
        do {
            if let url = URL(string: "https://api.ipify.org") {
                let value = try String(contentsOf: url)
                if !value.contains("<!DOCTYPE html>") && self.isIPv4(value) {
                    self.usage.raddr.v4 = value
                }
            }
        } catch let err {
            error("get public ipv4: \(err)", log: self.log)
        }
        
        do {
            if let url = URL(string: "https://api64.ipify.org") {
                let value = try String(contentsOf: url)
                if self.usage.raddr.v4 != value && !self.isIPv4(value) {
                    self.usage.raddr.v6 = value
                }
            }
        } catch let err {
            error("get public ipv6: \(err)", log: self.log)
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
    
    private func isIPv4(_ ip: String) -> Bool {
        let arr = ip.split(separator: ".").compactMap{ Int($0) }
        return arr.count == 4 && arr.filter{ $0 >= 0 && $0 < 256}.count == 4
    }
    
    @objc func refreshPublicIP() {
        self.usage.raddr.v4 = nil
        self.usage.raddr.v6 = nil
        
        DispatchQueue.global(qos: .background).async {
            self.getPublicIP()
        }
    }
    
    @objc func resetTotalNetworkUsage() {
        self.usage.total = (0, 0)
    }
}

public class ProcessReader: Reader<[Network_Process]> {
    private let title: String = "Network"
    private var previous: [Network_Process] = []
    
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    
    public override func setup() {
        self.popup = true
    }
    
    // swiftlint:disable function_body_length
    public override func read() {
        if self.numberOfProcesses == 0 {
            return
        }
        
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
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
        output.enumerateLines { (line, _) -> Void in
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
            
            if process.name == "" {
                process.name = process.pid
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
        if self.previous.isEmpty {
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
                    
                    processes.append(Network_Process(time: time, name: p.name, pid: p.pid, download: download, upload: upload, icon: p.icon))
                }
            }
            self.previous = list
        }
        
        processes.sort {
            let firstMax = max($0.download, $0.upload)
            let secondMax = max($1.download, $1.upload)
            let firstMin = min($0.download, $0.upload)
            let secondMin = min($1.download, $1.upload)
            
            if firstMax == secondMax && firstMin == secondMin { // download and upload values are the same, sort by time
                return $0.time < $1.time
            } else if firstMax == secondMax && firstMin != secondMin { // max values are the same, min not. Sort by min values
                return firstMin < secondMin
            }
            return firstMax < secondMax // max values are not the same, sort by max value
        }
        
        self.callback(processes.suffix(self.numberOfProcesses).reversed())
    }
}
