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
}
