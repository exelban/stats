//
//  reader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 05/03/2026
//  Using Swift 6.0
//  Running on macOS 26.3
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//  

import Foundation
import Kit

internal class ClockReader: Reader<Date> {
    private let title: String = ModuleType.clock.stringValue
    
    private let queue = DispatchQueue(label: "eu.exelban.Stats.Clock.ntp.sync", qos: .default)
    private var _offset: TimeInterval = 0
    private var offset: TimeInterval {
        get { self.queue.sync { self._offset } }
        set { self.queue.sync { self._offset = newValue } }
    }
    private var now: Date { Date().addingTimeInterval(self.offset) }
    
    private var ntpSync: Bool {
        get { Store.shared.bool(key: "\(self.title)_ntpSync", defaultValue: false) }
        set { Store.shared.set(key: "\(self.title)_ntpSync", value: newValue) }
    }
    
    private var ntpServer: String {
        get { Store.shared.string(key: "\(self.title)_ntpServer", defaultValue: "pool.ntp.org") }
        set { Store.shared.set(key: "\(self.title)_ntpServer", value: newValue) }
    }
    
    public override func setup() {
        self.syncWithNTP()
    }
    
    public override func read() {
        let date = self.ntpSync ? self.now : Date()
        
        self.callback(date)
        
        if Calendar.current.component(.second, from: date) == 0 {
            self.syncWithNTP()
        }
    }
    
    private func syncWithNTP() {
        guard self.ntpSync else {
            self.offset = 0
            return
        }
        
        let server = self.ntpServer
        self.queue.async { [weak self] in
            guard let self else { return }
            guard let serverDate = self.requestTime(server: server) else { return }
            let newOffset = serverDate.timeIntervalSince(Date())
            self._offset = newOffset
            self.alignOffset = newOffset
        }
    }
    
    private func requestTime(server: String, timeout: TimeInterval = 2.0) -> Date? {
        let host = CFHostCreateWithName(nil, server as CFString).takeRetainedValue()
        var resolved: DarwinBoolean = false
        let started = CFHostStartInfoResolution(host, .addresses, nil)
        guard started else { return nil }
        
        guard
            let unmanaged = CFHostGetAddressing(host, &resolved),
            resolved.boolValue,
            let addresses = unmanaged.takeUnretainedValue() as? [Data],
            let first = addresses.first
        else { return nil }
        
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else { return nil }
        defer { close(socketFD) }
        
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addrStorage = sockaddr_storage()
        first.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            memcpy(&addrStorage, base, min(raw.count, MemoryLayout<sockaddr_storage>.size))
        }
        
        guard addrStorage.ss_family == sa_family_t(AF_INET) else { return nil }
        withUnsafeMutablePointer(to: &addrStorage) {
            $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { p in
                p.pointee.sin_port = in_port_t(123).bigEndian
            }
        }
        
        var packet = Data(count: 48)
        packet[0] = 0x1B
        let sent = packet.withUnsafeBytes { ptr in
            withUnsafePointer(to: &addrStorage) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(socketFD, ptr.baseAddress, ptr.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == 48 else { return nil }
        
        var recvBuf = Data(count: 48)
        let received = recvBuf.withUnsafeMutableBytes { ptr in
            recv(socketFD, ptr.baseAddress, ptr.count, 0)
        }
        guard received >= 48 else { return nil }
        
        let seconds1900: UInt32 = recvBuf.withUnsafeBytes { ptr in
            let b = ptr.bindMemory(to: UInt8.self)
            return (UInt32(b[40]) << 24) | (UInt32(b[41]) << 16) | (UInt32(b[42]) << 8) | UInt32(b[43])
        }
        
        return Date(timeIntervalSince1970: TimeInterval(seconds1900) - 2_208_988_800)
    }
}
