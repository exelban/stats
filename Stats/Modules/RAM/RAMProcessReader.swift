//
//  RAMProcessReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class RAMProcessReader: Reader {
    public var name: String = "Process"
    public var enabled: Bool = false
    public var available: Bool = true
    public var optional: Bool = true
    public var initialized: Bool = false
    public var callback: ([TopProcess]) -> Void = {_ in}
    
    init(_ updater: @escaping ([TopProcess]) -> Void) {
        self.callback = updater

        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
    }
    
    func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        let task = Process()
        task.launchPath = "/usr/bin/top"
        task.arguments = ["-l", "1", "-o", "mem", "-n", "5", "-stats", "pid,command,mem"]
        
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
        
        var processes: [TopProcess] = []
        output.enumerateLines { (line, stop) -> () in
            if line.matches("^\\d+ + .+ +\\d+.\\d[M\\+\\-]+ *$") {
                var str = line.trimmingCharacters(in: .whitespaces)
                let pidString = str.findAndCrop(pattern: "^\\d+")
                let usageString = str.findAndCrop(pattern: " [0-9]+M(\\+|\\-)*$")
                var command = str.trimmingCharacters(in: .whitespaces)

                if let regex = try? NSRegularExpression(pattern: " (\\+|\\-)*$", options: .caseInsensitive) {
                    command = regex.stringByReplacingMatches(in: command, options: [], range: NSRange(location: 0, length:  command.count), withTemplate: "")
                }

                let pid = Int(pidString) ?? 0
                guard let usage = Double(usageString.filter("01234567890.".contains)) else {
                    return
                }
                let process = TopProcess(pid: pid, command: command, usage: usage * Double(1024 * 1024))
                processes.append(process)
            }
        }
        DispatchQueue.main.async(execute: {
            self.callback(processes)
        })
    }
    
    func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
}
