//
//  DiskReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

class DiskReader: Reader {
    public var value: Observable<[Double]>!
    public var available: Bool = true
    public var availableAdditional: Bool = false
    public var updateInterval: Int = 0
    
    private var timer: Repeater?
    
    init() {
        self.value = Observable([])
        if self.available {
            self.read()
        }
    }
    
    func start() {
        read()
        if self.timer != nil && self.timer!.state.isRunning == false {
            self.timer!.start()
        }
    }
    
    func stop() {
        self.timer?.pause()
    }
    
    @objc func read() {
        let total = totalDiskSpaceInBytes()
        let free = freeDiskSpaceInBytes()
        let usedSpace = total - free
        
        DispatchQueue.main.async(execute: {
            self.value << [(Double(usedSpace) / Double(total))]
        })
    }
    
    func totalDiskSpaceInBytes() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value
            return space!
        } catch {
            return 0
        }
    }
    
    func freeDiskSpaceInBytes() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
            return freeSpace!
        } catch {
            return 0
        }
    }
    
    func setInterval(value: Int) {
        if value == 0 {
            return
        }
        
        self.updateInterval = value
        self.timer?.reset(.seconds(Double(value)))
    }
}
