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
    public var updateInterval: Observable<Int> = Observable(0)
    public var available: Bool = true
    public var updateTimer: Timer!
    
    init() {
        self.value = Observable([])
        read()
        self.updateInterval.subscribe(observer: self) { (value, _) in
            self.stop()
            self.start()
        }
    }
    
    func start() {
        if updateTimer != nil {
            return
        }
        updateTimer = Timer.scheduledTimer(timeInterval: TimeInterval(self.updateInterval.value), target: self, selector: #selector(read), userInfo: nil, repeats: true)
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
        
        self.value << [(Double(usedSpace) / Double(total))]
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
