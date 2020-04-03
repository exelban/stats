//
//  CPUProcessReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 13/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

struct TopProcess {
    var pid: Int = 0
    var command: String = ""
    var usage: Double = 0
}

class CPUProcessReader: Reader {
    public var name: String = "Process"
    public var enabled: Bool = false
    public var available: Bool = true
    public var optional: Bool = true
    public var initialized: Bool = false
    public var callback: ([TopProcess]) -> Void = {_ in}
    
    private var loadPrevious = host_cpu_load_info()
    
    init(_ updater: @escaping ([TopProcess]) -> Void) {
        self.callback = updater
        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
    
    public func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-Aceo pid,pcpu,comm", "-r"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let error {
            print(error)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        _ = String(decoding: errorData, as: UTF8.self)
        
        if output.isEmpty {
            return
        }
        
        var index = 0
        var processes: [TopProcess] = []
        output.enumerateLines { (line, stop) -> () in
            if index != 0 {
                var str = line.trimmingCharacters(in: .whitespaces)
                let pidString = str.findAndCrop(pattern: "^\\d+")
                let usageString = str.findAndCrop(pattern: "^[0-9]+\\.[0-9]* ")
                let command = str.trimmingCharacters(in: .whitespaces)

                let pid = Int(pidString) ?? 0
                let usage = Double(usageString) ?? 0
                
                processes.append(TopProcess(pid: pid, command: command, usage: usage))
            }
            
            if index == 5 { stop = true }
            index += 1
        }
        
        DispatchQueue.main.async(execute: {
            self.callback(processes)
        })
    }
}
