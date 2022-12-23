//
//  main.swift
//  Helper
//
//  Created by Serhiy Mytrovtsiy on 17/11/2022
//  Using Swift 5.0
//  Running on macOS 13.0
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

let helper = Helper()
helper.run()

class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {
    private let listener: NSXPCListener
    
    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    
    private var smc: String? = nil
    
    override init() {
        self.listener = NSXPCListener(machServiceName: "eu.exelban.Stats.SMC.Helper")
        super.init()
        self.listener.delegate = self
    }
    
    public func run() {
        let args = CommandLine.arguments.dropFirst()
        if !args.isEmpty && args.first == "uninstall" {
            NSLog("detected uninstall command")
            if let val = args.last, let pid: pid_t = Int32(val) {
                while kill(pid, 0) == 0 {
                    usleep(50000)
                }
            }
            self.uninstallHelper()
            exit(0)
        }
        
        self.listener.resume()
        while !self.shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: self.shouldQuitCheckInterval))
        }
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }
            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }
        
        self.connections.append(connection)
        connection.resume()
        
        return true
    }
    
    private func uninstallHelper() {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.qualityOfService = QualityOfService.utility
        process.arguments = ["unload", "/Library/LaunchDaemons/eu.exelban.Stats.SMC.Helper.plist"]
        process.launch()
        process.waitUntilExit()
        
        if process.terminationStatus != .zero {
            NSLog("termination code: \(process.terminationStatus)")
        }
        NSLog("unloaded from launchctl")
        
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: "/Library/LaunchDaemons/eu.exelban.Stats.SMC.Helper.plist"))
        } catch let err {
            NSLog("plist deletion: \(err)")
        }
        NSLog("property list deleted")
        
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: "/Library/PrivilegedHelperTools/eu.exelban.Stats.SMC.Helper"))
        } catch let err {
            NSLog("helper deletion: \(err)")
        }
        NSLog("smc helper deleted")
    }
}

extension Helper {
    func version(completion: (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }
    func setSMCPath(_ path: String) {
        self.smc = path
    }
    
    func setFanMode(id: Int, mode: Int, completion: (String?) -> Void) {
        guard let smc = self.smc else {
            completion("missing smc tool")
            return
        }
        let result = syncShell("\(smc) fan \(id) -m \(mode)")
        completion(result)
    }
    
    func setFanSpeed(id: Int, value: Int, completion: (String?) -> Void) {
        guard let smc = self.smc else {
            completion("missing smc tool")
            return
        }
        let result = syncShell("\(smc) fan \(id) -v \(value)")
        completion(result)
    }
    
    public func syncShell(_ args: String) -> String {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)!
    }
    
    func uninstall() {
        let process = Process()
        process.launchPath = "/Library/PrivilegedHelperTools/eu.exelban.Stats.SMC.Helper"
        process.qualityOfService = QualityOfService.utility
        process.arguments = ["uninstall", String(getpid())]
        process.launch()
        exit(0)
    }
}
