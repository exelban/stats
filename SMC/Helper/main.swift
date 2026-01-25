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
import Darwin

// Async-signal-safe flag for emergency Ftst reset
nonisolated(unsafe) var gEmergencyFtstReset: Int32 = 0

let helper = Helper()
helper.run()

class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {
    static var shared: Helper?
    
    private let listener: NSXPCListener
    
    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    
    private var smc: String? = nil
    
    // Ftst state tracking
    private var ftstUnlocked: Bool = false
    private var ftstLastActivity: Date?
    private let ftstInactivityTimeout: TimeInterval = 60 // 1 minute of inactivity
    private let ftstPidFile = "/tmp/stats-ftst-unlock.pid"
    private var ftstWatchdogRunning = false
    
    override init() {
        self.listener = NSXPCListener(machServiceName: "eu.exelban.Stats.SMC.Helper")
        super.init()
        self.listener.delegate = self
        Helper.shared = self
        
        setupSignalHandlers()
        checkStaleFtstState()
    }
    
    private func setupSignalHandlers() {
        // Use async-signal-safe pattern: set flag, let atexit do cleanup
        signal(SIGTERM) { _ in
            gEmergencyFtstReset = 1
            exit(0)
        }
        signal(SIGINT) { _ in
            gEmergencyFtstReset = 1
            exit(0)
        }
        
        // atexit is safe for complex operations
        atexit {
            if gEmergencyFtstReset == 1 || Helper.shared?.ftstUnlocked == true {
                Helper.shared?.emergencyFtstReset()
            }
        }
    }
    
    private func checkStaleFtstState() {
        // Check for stale PID file from previous crash
        if FileManager.default.fileExists(atPath: ftstPidFile) {
            NSLog("Found stale Ftst PID file - previous crash detected, resetting Ftst")
            emergencyFtstReset()
        }
    }
    
    private func emergencyFtstReset() {
        // Try to find SMC tool if path not set
        var smcPath = self.smc
        if smcPath == nil {
            // Common locations
            let possiblePaths = [
                "/Applications/Stats.app/Contents/Resources/smc",
                Bundle.main.path(forResource: "smc", ofType: nil)
            ].compactMap { $0 }
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    smcPath = path
                    break
                }
            }
        }
        
        if let smc = smcPath {
            let result = syncShell("\(smc) lock")
            NSLog("Emergency Ftst reset: \(result.output ?? "no output")")
        } else {
            NSLog("Emergency Ftst reset: SMC tool not found, skipping")
        }
        
        try? FileManager.default.removeItem(atPath: ftstPidFile)
        ftstUnlocked = false
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
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        do {
            let isValid = try CodesignCheck.codeSigningMatches(pid: newConnection.processIdentifier)
            if !isValid {
                NSLog("invalid connection, dropping")
                return false
            }
        } catch {
            NSLog("error checking code signing: \(error)")
            return false
        }
        
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: newConnection) {
                self.connections.remove(at: connectionIndex)
            }
            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }
        
        self.connections.append(newConnection)
        newConnection.resume()
        
        return true
    }
    
    private func uninstallHelper() {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.qualityOfService = QualityOfService.userInitiated
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
        
        if let error = result.error, !error.isEmpty {
            NSLog("error set fan mode: \(error)")
            completion(nil)
            return
        }
        
        completion(result.output)
    }
    
    func setFanSpeed(id: Int, value: Int, completion: (String?) -> Void) {
        guard let smc = self.smc else {
            completion("missing smc tool")
            return
        }
        
        // Reset inactivity timer
        ftstLastActivity = Date()
        
        let result = syncShell("\(smc) fan \(id) -v \(value)")
        
        if let error = result.error, !error.isEmpty {
            NSLog("error set fan speed: \(error)")
            completion(nil)
            return
        }
        
        completion(result.output)
    }
    
    // MARK: - Ftst Unlock (Apple Silicon)
    
    func setFtstUnlock(completion: (Bool, String?) -> Void) {
        guard let smc = self.smc else {
            completion(false, "missing smc tool")
            return
        }
        
        let result = syncShell("\(smc) unlock")
        let success = result.error == nil || result.error?.isEmpty == true
        
        if success {
            ftstUnlocked = true
            ftstLastActivity = Date()
            
            // Write PID file for crash recovery
            do {
                try "\(getpid())".write(toFile: ftstPidFile, atomically: true, encoding: .utf8)
            } catch {
                NSLog("Failed to write Ftst PID file: \(error)")
            }
            
            // Start inactivity watchdog
            startFtstWatchdog()
            
            // Start orphan detection
            startOrphanDetection()
            
            NSLog("Ftst unlock successful")
        } else {
            NSLog("Ftst unlock failed: \(result.error ?? "unknown error")")
        }
        
        completion(success, result.output)
    }
    
    func setFtstLock(completion: (Bool, String?) -> Void) {
        guard let smc = self.smc else {
            completion(false, "missing smc tool")
            return
        }
        
        let result = syncShell("\(smc) lock")
        
        ftstUnlocked = false
        ftstLastActivity = nil
        
        // Remove PID file
        try? FileManager.default.removeItem(atPath: ftstPidFile)
        
        let success = result.error == nil || result.error?.isEmpty == true
        NSLog("Ftst lock: \(success ? "successful" : "failed")")
        
        completion(success, result.output)
    }
    
    func getFtstStatus(completion: (Bool, Int, String?) -> Void) {
        guard let smc = self.smc else {
            completion(false, -1, "missing smc tool")
            return
        }
        
        let result = syncShell("\(smc) ftst")
        completion(ftstUnlocked, ftstUnlocked ? 1 : 0, result.output)
    }
    
    private func startFtstWatchdog() {
        guard !ftstWatchdogRunning else { return }
        ftstWatchdogRunning = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while self?.ftstUnlocked == true {
                sleep(10) // Check every 10 seconds
                
                guard let self = self else { break }
                
                if let lastActivity = self.ftstLastActivity,
                   Date().timeIntervalSince(lastActivity) > self.ftstInactivityTimeout {
                    NSLog("Ftst auto-lock: inactivity timeout (\(self.ftstInactivityTimeout)s)")
                    self.setFtstLock { _, _ in }
                    break
                }
            }
            self?.ftstWatchdogRunning = false
        }
    }
    
    private func startOrphanDetection() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while self?.ftstUnlocked == true {
                sleep(30) // Check every 30 seconds
                
                guard let self = self else { break }
                
                // Check if main app is still running using pgrep (works without AppKit)
                let result = syncShell("pgrep -f 'Stats.app' 2>/dev/null")
                let statsRunning = !(result.output?.isEmpty ?? true)
                
                if !statsRunning {
                    NSLog("Main app terminated while Ftst unlocked - resetting")
                    self.setFtstLock { _, _ in }
                    break
                }
            }
        }
    }
    
    func powermetrics(_ samplers: [String], completion: @escaping (String?) -> Void) {
        let result = syncShell("powermetrics -n 1 -s \(samplers.joined(separator: ",")) --sample-rate 1000")
        if let error = result.error, !error.isEmpty {
            NSLog("error call powermetrics: \(error)")
            completion(nil)
            return
        }
        completion(result.output)
    }
    
    public func syncShell(_ args: String) -> (output: String?, error: String?) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        
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
            return (nil, "syncShell: \(err.localizedDescription)")
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)
        let error = String(data: errorData, encoding: .utf8)
        
        return (output, error)
    }
    
    func uninstall() {
        let process = Process()
        process.launchPath = "/Library/PrivilegedHelperTools/eu.exelban.Stats.SMC.Helper"
        process.qualityOfService = QualityOfService.userInitiated
        process.arguments = ["uninstall", String(getpid())]
        process.launch()
        exit(0)
    }
}

// https://github.com/duanefields/VirtualKVM/blob/master/VirtualKVM/CodesignCheck.swift
let kSecCSDefaultFlags = 0

enum CodesignCheckError: Error {
    case message(String)
}

struct CodesignCheck {
    public static func codeSigningMatches(pid: pid_t) throws -> Bool {
        return try self.codeSigningCertificatesForSelf() == self.codeSigningCertificates(forPID: pid)
    }
    
    private static func codeSigningCertificatesForSelf() throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCodeSelf() else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }
    
    private static func codeSigningCertificates(forPID pid: pid_t) throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCode(forPID: pid) else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }
    
    private static func executeSecFunction(_ secFunction: () -> (OSStatus) ) throws {
        let osStatus = secFunction()
        guard osStatus == errSecSuccess else {
            throw CodesignCheckError.message(String(describing: SecCopyErrorMessageString(osStatus, nil)))
        }
    }
    
    private static func secStaticCodeSelf() throws -> SecStaticCode? {
        var secCodeSelf: SecCode?
        try executeSecFunction { SecCodeCopySelf(SecCSFlags(rawValue: 0), &secCodeSelf) }
        guard let secCode = secCodeSelf else {
            throw CodesignCheckError.message("SecCode returned empty from SecCodeCopySelf")
        }
        return try secStaticCode(forSecCode: secCode)
    }
    
    private static func secStaticCode(forPID pid: pid_t) throws -> SecStaticCode? {
        var secCodePID: SecCode?
        try executeSecFunction { SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &secCodePID) }
        guard let secCode = secCodePID else {
            throw CodesignCheckError.message("SecCode returned empty from SecCodeCopyGuestWithAttributes")
        }
        return try secStaticCode(forSecCode: secCode)
    }
    
    private static func secStaticCode(forSecCode secCode: SecCode) throws -> SecStaticCode? {
        var secStaticCodeCopy: SecStaticCode?
        try executeSecFunction { SecCodeCopyStaticCode(secCode, [], &secStaticCodeCopy) }
        guard let secStaticCode = secStaticCodeCopy else {
            throw CodesignCheckError.message("SecStaticCode returned empty from SecCodeCopyStaticCode")
        }
        return secStaticCode
    }
    
    private static func isValid(secStaticCode: SecStaticCode) throws {
        try executeSecFunction { SecStaticCodeCheckValidity(secStaticCode, SecCSFlags(rawValue: kSecCSDoNotValidateResources | kSecCSCheckNestedCode), nil) }
    }
    
    private static func secCodeInfo(forStaticCode secStaticCode: SecStaticCode) throws -> [String: Any]? {
        try isValid(secStaticCode: secStaticCode)
        var secCodeInfoCFDict: CFDictionary?
        try executeSecFunction { SecCodeCopySigningInformation(secStaticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &secCodeInfoCFDict) }
        guard let secCodeInfo = secCodeInfoCFDict as? [String: Any] else {
            throw CodesignCheckError.message("CFDictionary returned empty from SecCodeCopySigningInformation")
        }
        return secCodeInfo
    }
    
    private static func codeSigningCertificates(forStaticCode secStaticCode: SecStaticCode) throws -> [SecCertificate] {
        guard
            let secCodeInfo = try secCodeInfo(forStaticCode: secStaticCode),
            let secCertificates = secCodeInfo[kSecCodeInfoCertificates as String] as? [SecCertificate] else { return [] }
        return secCertificates
    }
}
