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

// swiftlint:disable control_statement
extension CWPHYMode: CustomStringConvertible {
    public var description: String {
        switch(self) {
        case .mode11a:  return "802.11a"
        case .mode11ac: return "802.11ac"
        case .mode11b:  return "802.11b"
        case .mode11g:  return "802.11g"
        case .mode11n:  return "802.11n"
        case .mode11ax: return "802.11ax"
        case .modeNone: return "none"
        @unknown default: return "unknown"
        }
    }
}

extension CWInterfaceMode: CustomStringConvertible {
    public var description: String {
        switch(self) {
        case .hostAP:       return "AP"
        case .IBSS:         return "Adhoc"
        case .station:      return "Station"
        case .none:         return "none"
        @unknown default:   return "unknown"
        }
    }
}

extension CWSecurity: CustomStringConvertible {
    public var description: String {
        switch(self) {
        case .none:               return "none"
        case .WEP:                return "WEP"
        case .wpaPersonal:        return "WPA Personal"
        case .wpaPersonalMixed:   return "WPA Personal Mixed"
        case .wpa2Personal:       return "WPA2 Personal"
        case .personal:           return "Personal"
        case .dynamicWEP:         return "Dynamic WEP"
        case .wpaEnterprise:      return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA Enterprise Mixed"
        case .wpa2Enterprise:     return "WPA2 Enterprise"
        case .enterprise:         return "Enterprise"
        case .unknown:            return "unknown"
        case .wpa3Personal:       return "WPA3 Personal"
        case .wpa3Enterprise:     return "WPA3 Enterprise"
        case .wpa3Transition:     return "WPA3 Transition"
        default:                  return "unknown"
        }
    }
}

extension CWChannelBand: CustomStringConvertible {
    public var description: String {
        switch(self) {
        case .band2GHz:     return "2 GHz"
        case .band5GHz:     return "5 GHz"
        case .band6GHz:     return "6 GHz"
        case .bandUnknown:  return "unknown"
        @unknown default:   return "unknown"
        }
    }
}

extension CWChannelWidth: CustomStringConvertible {
    public var description: String {
        switch(self) {
        case .width20MHz:   return "20 MHz"
        case .width40MHz:   return "40 MHz"
        case .width80MHz:   return "80 MHz"
        case .width160MHz:  return "160 MHz"
        case .widthUnknown: return "unknown"
        @unknown default:   return "unknown"
        }
    }
}
// swiftlint:enable control_statement

extension CWChannel {
    override public var description: String {
        return "\(channelNumber) (\(channelBand), \(channelWidth))"
    }
}

internal class UsageReader: Reader<Network_Usage> {
    private var reachability: Reachability = Reachability(start: true)
    private let variablesQueue = DispatchQueue(label: "eu.exelban.NetworkUsageReader")
    private var _usage: Network_Usage = Network_Usage()
    public var usage: Network_Usage {
        get { self.variablesQueue.sync { self._usage } }
        set { self.variablesQueue.sync { self._usage = newValue } }
    }
    
    private var primaryInterface: String {
        get {
            if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString), let name = global["PrimaryInterface"] as? String {
                return name
            }
            return ""
        }
    }
    
    private var interfaceID: String {
        get { Store.shared.string(key: "Network_interface", defaultValue: self.primaryInterface) }
        set { Store.shared.set(key: "Network_interface", value: newValue) }
    }
    
    private var reader: String {
        get { Store.shared.string(key: "Network_reader", defaultValue: "interface") }
    }
    
    private var vpnConnection: Bool {
        if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any], let scopes = settings["__SCOPED__"] as? [String: Any] {
            return !scopes.filter({ $0.key.contains("tap") || $0.key.contains("tun") || $0.key.contains("ppp") || $0.key.contains("ipsec") || $0.key.contains("ipsec0")}).isEmpty
        }
        return false
    }
    
    private var VPNMode: Bool {
        get { Store.shared.bool(key: "Network_VPNMode", defaultValue: false) }
    }
    
    public override func setup() {
        self.reachability.reachable = {
            if self.active {
                self.getPublicIP()
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
                self.getPublicIP()
                self.getDetails()
            }
        }
    }
    
    public override func terminate() {
        self.reachability.stop()
    }
    
    public override func read() {
        self.getDetails()
        
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
        
        if self.vpnConnection && self.VPNMode {
            self.usage.bandwidth.upload /= 2
            self.usage.bandwidth.download /= 2
        }
        
        self.callback(self.usage)
        
        self.usage.bandwidth.upload = current.upload
        self.usage.bandwidth.download = current.download
    }
    
    private func readInterfaceBandwidth() -> Bandwidth {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        guard getifaddrs(&interfaceAddresses) == 0 else {
            return Bandwidth()
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
        
        return Bandwidth(upload: totalUpload, download: totalDownload)
    }
    
    private func readProcessBandwidth() -> Bandwidth {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-n", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        task.environment = [
            "NSUnbufferedIO": "YES",
            "LC_ALL": "en_US.UTF-8"
        ]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            inputPipe.fileHandleForWriting.closeFile()
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        task.standardInput = inputPipe
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let err {
            error("read bandwidth from processes: \(err)", log: self.log)
            return Bandwidth()
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        _ = String(decoding: errorData, as: UTF8.self)
        
        if output.isEmpty {
            return Bandwidth()
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
        
        return Bandwidth(upload: totalUpload, download: totalDownload)
    }
    
    public func getDetails() {
        guard self.interfaceID != "" else { return }
        
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface), bsdName as String == self.interfaceID,
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
        
        guard self.usage.interface != nil else { return }
        
        if self.usage.connectionType == .wifi {
            if let interface = CWWiFiClient.shared().interface(withName: self.interfaceID) {
                self.usage.wifiDetails.ssid = interface.ssid()
                self.usage.wifiDetails.bssid = interface.bssid()
                self.usage.wifiDetails.countryCode = interface.countryCode()
                
                self.usage.wifiDetails.RSSI = interface.rssiValue()
                self.usage.wifiDetails.noise = interface.noiseMeasurement()
                self.usage.wifiDetails.transmitRate = interface.transmitRate()
                
                self.usage.wifiDetails.standard = interface.activePHYMode().description
                self.usage.wifiDetails.mode = interface.interfaceMode().description
                self.usage.wifiDetails.security = interface.security().description
                
                if let ch = interface.wlanChannel() {
                    self.usage.wifiDetails.channel = ch.description
                    
                    self.usage.wifiDetails.channelBand = ch.channelBand.description
                    self.usage.wifiDetails.channelWidth = ch.channelWidth.description
                    self.usage.wifiDetails.channelNumber = ch.channelNumber.description
                }
            }
            
            if self.usage.wifiDetails.ssid == nil || self.usage.wifiDetails.ssid == "" {
                let networksetupResponse = syncShell("networksetup -getairportnetwork \(self.interfaceID)")
                if networksetupResponse.split(separator: "\n").count == 1 {
                    let arr = networksetupResponse.split(separator: ":")
                    if let ssid = arr.last {
                        self.usage.wifiDetails.ssid = ssid.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    }
                }
            }
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
        struct Addr_s: Decodable {
            let ipv4: String?
            let ipv6: String?
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let response = syncShell("curl -s -4 https://api.serhiy.io/v1/stats/ip")
            if !response.isEmpty, let data = response.data(using: .utf8),
               let addr = try? JSONDecoder().decode(Addr_s.self, from: data) {
                if let ip = addr.ipv4, self.isIPv4(ip) {
                    self.usage.raddr.v4 = ip
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let response = syncShell("curl -s -6 https://api.serhiy.io/v1/stats/ip")
            if !response.isEmpty, let data = response.data(using: .utf8),
               let addr = try? JSONDecoder().decode(Addr_s.self, from: data) {
                if let ip = addr.ipv6, !self.isIPv4(ip) {
                    self.usage.raddr.v6 = ip
                }
            }
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
        self.usage.total = Bandwidth()
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
    
    public override func read() {
        if self.numberOfProcesses == 0 {
            return
        }
        
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-n", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"]
        task.environment = [
            "NSUnbufferedIO": "YES",
            "LC_ALL": "en_US.UTF-8"
        ]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            inputPipe.fileHandleForWriting.closeFile()
            outputPipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        task.standardInput = inputPipe
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
                process.pid = Int(pid) ?? 0
            }
            if let app = NSRunningApplication(processIdentifier: pid_t(process.pid) ) {
                process.name = app.localizedName ?? nameArray.dropLast().joined(separator: ".")
            } else {
                process.name = nameArray.dropLast().joined(separator: ".")
            }
            
            if process.name == "" {
                process.name = "\(process.pid)"
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
                    
                    processes.append(Network_Process(pid: p.pid, name: p.name, time: time, download: download, upload: upload))
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

internal class ConnectivityReaderWrapper {
    weak var reader: ConnectivityReader?
    
    init(_ reader: ConnectivityReader) {
        self.reader = reader
    }
}

// inspired by https://github.com/samiyr/SwiftyPing
internal class ConnectivityReader: Reader<Network_Connectivity> {
    private let variablesQueue = DispatchQueue(label: "eu.exelban.ConnectivityReaderQueue")
    
    private let identifier = UInt16.random(in: 0..<UInt16.max)
    private var fingerprint: UUID = UUID()
    
    private var host: String {
        Store.shared.string(key: "Network_ICMPHost", defaultValue: "1.1.1.1")
    }
    private var lastHost: String = ""
    private var addr: Data? = nil
    private let timeout: TimeInterval = 5
    
    private var socket: CFSocket?
    private var socketSource: CFRunLoopSource?
    
    private var wrapper: Network_Connectivity = Network_Connectivity(status: false)
    
    private var _status: Bool? = nil
    private var status: Bool? {
        get {
            self.variablesQueue.sync { self._status }
        }
        set {
            self.variablesQueue.sync { self._status = newValue }
        }
    }
    
    private var _timeoutTimer: Timer?
    private var timeoutTimer: Timer? {
        get {
            self.variablesQueue.sync { self._timeoutTimer }
        }
        set {
            self.variablesQueue.sync { self._timeoutTimer = newValue }
        }
    }
    
    private var _isPinging: Bool = false
    private var isPinging: Bool {
        get {
            self.variablesQueue.sync { self._isPinging }
        }
        set {
            self.variablesQueue.sync { self._isPinging = newValue }
        }
    }
    
    private var _latency: Double? = nil
    private var latency: Double? {
        get {
            self.variablesQueue.sync { self._latency }
        }
        set {
            self.variablesQueue.sync { self._latency = newValue }
        }
    }
    
    var start: DispatchTime? = nil
    
    private struct ICMPHeader {
        public var type: UInt8
        public var code: UInt8
        public var checksum: UInt16
        public var identifier: UInt16
        public var sequenceNumber: UInt16
        public var payload: uuid_t
    }
    
    private struct IPHeader {
        public var versionAndHeaderLength: UInt8
        public var differentiatedServices: UInt8
        public var totalLength: UInt16
        public var identification: UInt16
        public var flagsAndFragmentOffset: UInt16
        public var timeToLive: UInt8
        public var `protocol`: UInt8
        public var headerChecksum: UInt16
        public var sourceAddress: (UInt8, UInt8, UInt8, UInt8)
        public var destinationAddress: (UInt8, UInt8, UInt8, UInt8)
    }
    
    override func setup() {
        self.interval = 1
        self.addr = self.resolve()
        self.openConn()
        self.read()
    }
    
    deinit {
        self.closeConn()
    }
    
    override func read() {
        guard !self.host.isEmpty else {
            if self.socket != nil {
                self.closeConn()
            }
            return
        }
        
        if self.socket == nil {
            self.setup()
        }
        
        if self.lastHost != self.host {
            self.addr = self.resolve()
        }
        
        guard !self.isPinging && self.active, let socket = self.socket, let addr = self.addr, let data = self.request() else { return }
        self.isPinging = true
        
        let timer = Timer(timeInterval: self.timeout, target: self, selector: #selector(self.timeoutCallback), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        self.timeoutTimer = timer
        self.start = DispatchTime.now()
        
        let error = CFSocketSendData(socket, addr as CFData, data as CFData, self.timeout)
        if error != .success {
            self.socketCallback(data: nil, error: error)
        }
        
        if let v = self.status {
            self.wrapper.status = v
            if let l = self.latency {
                self.wrapper.latency = l
            }
            self.callback(self.wrapper)
        }
    }
    
    @objc private func timeoutCallback() {
        self.status = false
        self.isPinging = false
    }
    
    private func socketCallback(data: Data? = nil, error: CFSocketError? = nil) {
        guard let data = data, validateResponse(data) else { return }
        let end = DispatchTime.now()
        
        self.latency = Double(end.uptimeNanoseconds - (self.start?.uptimeNanoseconds ?? 0)) / 1_000_000
        self.status = error == nil
        self.isPinging = false
        self.timeoutTimer?.invalidate()
        self.timeoutTimer = nil
    }
    
    // MARK: - helpers
    
    private func validateResponse(_ data: Data) -> Bool {
        guard data.count >= MemoryLayout<ICMPHeader>.size + MemoryLayout<IPHeader>.size,
              let headerOffset = icmpHeaderOffset(of: data) else { return false }
        
        let payloadSize = data.count - headerOffset - MemoryLayout<ICMPHeader>.size
        let icmpHeader = data.withUnsafeBytes({ $0.load(fromByteOffset: headerOffset, as: ICMPHeader.self) })
        let payload = data.subdata(in: (data.count - payloadSize)..<data.count)
        let uuid = UUID(uuid: icmpHeader.payload)
        
        guard uuid == self.fingerprint else { return false }
        guard icmpHeader.checksum == computeChecksum(header: icmpHeader, additionalPayload: [UInt8](payload)) else { return false }
        guard icmpHeader.type == 0 else { return false }
        guard icmpHeader.code == 0 else { return false }
        
        return true
    }
    
    private func request() -> Data? {
        var header = ICMPHeader(
            type: 8,
            code: 0,
            checksum: 0,
            identifier: CFSwapInt16HostToBig(self.identifier),
            sequenceNumber: CFSwapInt16HostToBig(0),
            payload: self.fingerprint.uuid
        )
        
        let delta = MemoryLayout<uuid_t>.size - MemoryLayout<uuid_t>.size
        var additional = [UInt8]()
        if delta > 0 {
            additional = (0..<delta).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        }
        
        guard let checksum = computeChecksum(header: header, additionalPayload: additional) else { return nil }
        header.checksum = checksum
        
        return Data(bytes: &header, count: MemoryLayout<ICMPHeader>.size) + Data(additional)
    }
    
    private func computeChecksum(header: ICMPHeader, additionalPayload: [UInt8]) -> UInt16? {
        let typecode = Data([header.type, header.code]).withUnsafeBytes { $0.load(as: UInt16.self) }
        var sum = UInt64(typecode) + UInt64(header.identifier) + UInt64(header.sequenceNumber)
        let payload = convert(payload: header.payload) + additionalPayload
        guard payload.count % 2 == 0 else { return nil }
        
        var i = 0
        while i < payload.count {
            guard payload.indices.contains(i + 1) else { return nil }
            sum += Data([payload[i], payload[i + 1]]).withUnsafeBytes { UInt64($0.load(as: UInt16.self)) }
            i += 2
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xffff) + (sum >> 16)
        }
        guard sum < UInt16.max else { return nil }
        
        return ~UInt16(sum)
    }
    
    private func convert(payload: uuid_t) -> [UInt8] {
        let p = payload
        return [p.0, p.1, p.2, p.3, p.4, p.5, p.6, p.7, p.8, p.9, p.10, p.11, p.12, p.13, p.14, p.15].map { UInt8($0) }
    }
    
    private func icmpHeaderOffset(of packet: Data) -> Int? {
        if packet.count >= MemoryLayout<IPHeader>.size + MemoryLayout<ICMPHeader>.size {
            let ipHeader = packet.withUnsafeBytes({ $0.load(as: IPHeader.self) })
            if ipHeader.versionAndHeaderLength & 0xF0 == 0x40 && ipHeader.protocol == IPPROTO_ICMP {
                let headerLength = Int(ipHeader.versionAndHeaderLength) & 0x0F * MemoryLayout<UInt32>.size
                if packet.count >= headerLength + MemoryLayout<ICMPHeader>.size {
                    return headerLength
                }
            }
        }
        return nil
    }
    
    private func openConn() {
        let info = ConnectivityReaderWrapper(self)
        let unmanagedSocketInfo = Unmanaged.passRetained(info)
        var context = CFSocketContext(version: 0, info: unmanagedSocketInfo.toOpaque(), retain: nil, release: nil, copyDescription: nil)
        self.socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_DGRAM, IPPROTO_ICMP, CFSocketCallBackType.dataCallBack.rawValue, { _, callBackType, _, data, info in
            guard let info = info, let data = data else { return }
            if (callBackType as CFSocketCallBackType) == CFSocketCallBackType.dataCallBack {
                let cfdata = Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue()
                let wrapper = Unmanaged<ConnectivityReaderWrapper>.fromOpaque(info).takeUnretainedValue()
                wrapper.reader?.socketCallback(data: cfdata as Data)
            }
        }, &context)
        let handle = CFSocketGetNative(self.socket)
        var value: Int32 = 1
        let err = setsockopt(handle, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout.size(ofValue: value)))
        guard err == 0 else { return }
        self.socketSource = CFSocketCreateRunLoopSource(nil, self.socket, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), self.socketSource, .commonModes)
    }
    
    private func closeConn() {
        if let source = self.socketSource {
            CFRunLoopSourceInvalidate(source)
            self.socketSource = nil
        }
        if let socket = self.socket {
            CFSocketInvalidate(socket)
            self.socket = nil
        }
        self.timeoutTimer?.invalidate()
        self.timeoutTimer = nil
    }
    
    private func resolve() -> Data? {
        self.lastHost = self.host
        var streamError = CFStreamError()
        let cfhost = CFHostCreateWithName(nil, self.host as CFString).takeRetainedValue()
        let status = CFHostStartInfoResolution(cfhost, .addresses, &streamError)
        guard status else { return nil }
        var success: DarwinBoolean = false
        guard let addresses = CFHostGetAddressing(cfhost, &success)?.takeUnretainedValue() as? [Data] else {
            return nil
        }
        var data: Data?
        for address in addresses {
            let addrin = address.socketAddress
            if address.count >= MemoryLayout<sockaddr>.size && addrin.sa_family == UInt8(AF_INET) {
                data = address
                break
            }
        }
        guard let data = data, !data.isEmpty else { return nil }
        return data
    }
}
