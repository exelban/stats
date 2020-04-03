//
//  DiskCapacityReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class DiskCapacityReader: Reader {
    public var name: String = "Capacity"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    public var callback: (Double) -> Void = {_ in}
    
    init(_ updater: @escaping (Double) -> Void) {
        self.callback = updater
        
        if self.available {
            DispatchQueue.global(qos: .default).async {
                self.read()
            }
        }
    }

    public func read() {
        if !self.enabled && self.initialized { return }
        self.initialized = true
        
        let total = totalDiskSpaceInBytes()
        let free = freeDiskSpaceInBytes()
        let usedSpace = total - free
        
        DispatchQueue.main.async(execute: {
            self.callback((Double(usedSpace) / Double(total)))
        })
    }
    
    private func totalDiskSpaceInBytes() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value
            return space!
        } catch {
            return 0
        }
    }
    
    private func freeDiskSpaceInBytes() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
            return freeSpace!
        } catch {
            return 0
        }
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
    }
}
