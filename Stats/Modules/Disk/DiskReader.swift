//
//  DiskReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

class DiskReader: Reader {
    var value: Observable<Double>!
    var available: Bool = true
    var updateTimer: Timer!
    
    init() {
        self.value = Observable(0)
        read()
    }
    
    func start() {
        if updateTimer != nil {
            return
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(read), userInfo: nil, repeats: true)
    }
    
    func stop() {
        if updateTimer == nil {
            return
        }
        updateTimer.invalidate()
        updateTimer = nil
    }
    
    @objc func read() {
        let total = totalDiskSpaceInBytes()
        let free = freeDiskSpaceInBytes()
        let usedSpace = total - free
        
        self.value << (Double(usedSpace) / Double(total))
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
}
