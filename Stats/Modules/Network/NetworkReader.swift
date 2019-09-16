//
//  NetworkReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 24.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkReader: Reader {
    public var value: Observable<[Double]>!
    public var updateInterval: Observable<Int> = Observable(0)
    public var available: Bool = true
    public var availableAdditional: Bool = false
    public var updateTimer: Timer!
    
    private var netProcess: Process = Process()
    private var pipe: Pipe = Pipe()
    
    init() {
        self.value = Observable([])
        netProcess.launchPath = "/usr/bin/env"
        netProcess.arguments = ["netstat", "-w1", "-l", "en0"]
        netProcess.standardOutput = pipe
    }
    
    func start() {
        if netProcess.isRunning {
            return
        }
        self.pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: self.pipe.fileHandleForReading , queue: nil) { _ -> Void in
            defer {
                self.pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
            }

            let output = self.pipe.fileHandleForReading.availableData
            if output.isEmpty {
                return
            }

            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
            let arr = outputString.condenseWhitespace().split(separator: " ")

            if !arr.isEmpty && Int64(arr[0]) != nil {
                guard let download = Int64(arr[2]), let upload = Int64(arr[5]) else {
                    return
                }
                self.value << [Double(download), Double(upload)]
            }
        }
        
        do {
            try netProcess.run()
        } catch let error {
            print(error)
        }
    }
    
    func stop() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSFileHandleDataAvailable, object: nil)
    }
    
    func read() {}
}
