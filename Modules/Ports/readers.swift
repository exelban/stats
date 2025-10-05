//
//  readers.swift
//  Ports
//
//  Created by Dogukan Akin on 05/10/2025.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public struct PortInfo: Codable {
    let port: Int
    let pid: Int
    let processName: String
    let `protocol`: String
    let state: String
}

internal class PortsReader: Reader<[PortInfo]> {
    private let title: String = "Ports"
    
    public override func setup() {
        self.popup = true
        self.setInterval(Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: 3))
    }
    
    public override func read() {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        
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
            error("lsof(): \(err.localizedDescription)", log: self.log)
            return
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)
        guard let output, !output.isEmpty else { return }
        
        var ports: [PortInfo] = []
        var seenPorts: Set<Int> = []
        
        output.enumerateLines { (line, _) in
            // Skip header line
            if line.hasPrefix("COMMAND") {
                return
            }
            
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 9 {
                let processName = String(components[0])
                let pidString = String(components[1])
                let proto = String(components[7])
                
                // Extract port from address (format: *:PORT or IP:PORT)
                let address = String(components[8])
                if let colonIndex = address.lastIndex(of: ":") {
                    let portString = String(address[address.index(after: colonIndex)...])
                    if let port = Int(portString), let pid = Int(pidString) {
                        // Only add unique ports
                        if !seenPorts.contains(port) {
                            seenPorts.insert(port)
                            ports.append(PortInfo(
                                port: port,
                                pid: pid,
                                processName: processName,
                                protocol: proto,
                                state: "LISTEN"
                            ))
                        }
                    }
                }
            }
        }
        
        // Sort by port number
        ports.sort { $0.port < $1.port }
        self.callback(ports)
    }
    
    public func killProcess(pid: Int) -> Bool {
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", "\(pid)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
