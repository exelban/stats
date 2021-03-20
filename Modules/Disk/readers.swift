//
//  readers.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 07/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit
import IOKit
import Darwin
import os.log

internal class CapacityReader: Reader<DiskList> {
    private var disks: DiskList = DiskList()
    
    public override func read() {
        let keys: [URLResourceKey] = [.volumeNameKey]
        let removableState = Store.shared.bool(key: "Disk_removable", defaultValue: false) 
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)!
        
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            os_log(.error, log: log, "cannot create a DASessionCreate()")
            return
        }
        
        var active: [String] = []
        for url in paths {
            if url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                    if let diskName = DADiskGetBSDName(disk) {
                        let BSDName: String = String(cString: diskName)
                        active.append(BSDName)
                        
                        if let d: drive = self.disks.getDiskByBSDName(BSDName) {
                            if let idx = self.disks.list.firstIndex(where: { $0.BSDName == BSDName }) {
                                if d.removable && !removableState {
                                    self.disks.list.remove(at: idx)
                                    continue
                                }
                                
                                if let path = self.disks.list[idx].path {
                                    self.disks.list[idx].free = self.freeDiskSpaceInBytes(path)
                                    self.driveStats(self.disks.list[idx].parent, &self.disks.list[idx].stats)
                                }
                            }
                            continue
                        }
                        
                        if let d = driveDetails(disk, removableState: removableState) {
                            self.disks.list.append(d)
                            self.disks.list.sort{ $1.removable }
                        }
                    }
                }
            }
        }
        
        if active.count < self.disks.list.count {
            let missingDisks = active.difference(from: self.disks.list.map{ $0.BSDName })
            
            missingDisks.forEach { (BSDName: String) in
                self.disks.removeDiskByBSDName(BSDName)
            }
        }
        
        self.callback(self.disks)
    }
    
    private func driveDetails(_ disk: DADisk, removableState: Bool) -> drive? {
        var d: drive = drive()
        
        if let bsdName = DADiskGetBSDName(disk) {
            d.BSDName = String(cString: bsdName)
        }
        
        if let diskDescription = DADiskCopyDescription(disk) {
            if let dict = diskDescription as? [String: AnyObject] {
                if let removable = dict[kDADiskDescriptionMediaRemovableKey as String] {
                    if removable as! Bool {
                        if !removableState {
                            return nil
                        }
                        d.removable = true
                    }
                }
                
                if let mediaName = dict[kDADiskDescriptionVolumeNameKey as String] {
                    d.mediaName = mediaName as! String
                    if d.mediaName == "Recovery" {
                        return nil
                    }
                }
                if d.mediaName == "" {
                    if let mediaName = dict[kDADiskDescriptionMediaNameKey as String] {
                        d.mediaName = mediaName as! String
                        if d.mediaName == "Recovery" {
                            return nil
                        }
                    }
                }
                if let mediaSize = dict[kDADiskDescriptionMediaSizeKey as String] {
                    d.size = Int64(truncating: mediaSize as! NSNumber)
                }
                if let deviceModel = dict[kDADiskDescriptionDeviceModelKey as String] {
                    d.model = (deviceModel as! String).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let deviceProtocol = dict[kDADiskDescriptionDeviceProtocolKey as String] {
                    d.connectionType = deviceProtocol as! String
                }
                if let volumePath = dict[kDADiskDescriptionVolumePathKey as String] {
                    if let url = volumePath as? NSURL {
                        d.path = url as URL
                        
                        if let components = url.pathComponents {
                            d.root = components.count == 1
                            
                            if components.count > 1 && components[1] == "Volumes" {
                                if let name: String = url.lastPathComponent, name != "" {
                                    d.mediaName = name
                                }
                            }
                        }
                    }
                }
                if let volumeKind = dict[kDADiskDescriptionVolumeKindKey as String] {
                    d.fileSystem = volumeKind as! String
                }
            }
        }
        
        if d.path == nil {
            return nil
        }
        
        if let path = d.path {
            d.free = freeDiskSpaceInBytes(path)
        }
        
        let partitionLevel = d.BSDName.filter { "0"..."9" ~= $0 }.count
        if let parent = self.getDeviceIOParent(DADiskCopyIOMedia(disk), level: Int(partitionLevel)) {
            d.parent = parent
            self.driveStats(parent, &d.stats)
        }
        
        return d
    }
    
    // https://opensource.apple.com/source/bless/bless-152/libbless/APFS/BLAPFSUtilities.c.auto.html
    public func getDeviceIOParent(_ obj: io_registry_entry_t, level: Int) -> io_registry_entry_t? {
        var parent: io_registry_entry_t = 0
        
        if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
            return nil
        }
        
        for _ in 1...level {
            if IORegistryEntryGetParentEntry(parent, kIOServicePlane, &parent) != KERN_SUCCESS {
                IOObjectRelease(parent)
                return nil
            }
        }
        
        return parent
    }
    
    private func driveStats(_ entry: io_registry_entry_t, _ diskStats: UnsafeMutablePointer<stats?>) {
        guard let props = getIOProperties(entry) else {
            return
        }
        
        if let statistics = props.object(forKey: "Statistics") as? NSDictionary {
            if diskStats.pointee == nil {
                diskStats.initialize(to: stats())
            }
            
            let readBytes = statistics.object(forKey: "Bytes (Read)") as? Int64 ?? 0
            let writeBytes = statistics.object(forKey: "Bytes (Write)") as? Int64 ?? 0
            
            if diskStats.pointee?.readBytes != 0 {
                diskStats.pointee?.read = readBytes - (diskStats.pointee?.readBytes ?? 0)
            }
            if diskStats.pointee?.writeBytes != 0 {
                diskStats.pointee?.write = writeBytes - (diskStats.pointee?.writeBytes ?? 0)
            }
            
            diskStats.pointee?.readBytes = readBytes
            diskStats.pointee?.writeBytes = writeBytes
            diskStats.pointee?.readOperations = statistics.object(forKey: "Operations (Read)") as? Int64 ?? 0
            diskStats.pointee?.writeOperations = statistics.object(forKey: "Operations (Read)") as? Int64 ?? 0
            diskStats.pointee?.readTime = statistics.object(forKey: "Total Time (Read)") as? Int64 ?? 0
            diskStats.pointee?.writeTime = statistics.object(forKey: "Total Time (Read)") as? Int64 ?? 0
        }
        
        return
    }
    
    private func freeDiskSpaceInBytes(_ path: URL) -> Int64 {
        do {
            if let url = URL(string: path.absoluteString) {
                let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let capacity = values.volumeAvailableCapacityForImportantUsage {
                    return capacity
                }
            }
        } catch {
            os_log(.error, log: log, "error retrieving free space #1: %s", "\(error.localizedDescription)")
        }
        
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: path.path)
            if let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value {
                return freeSpace
            }
        } catch {
            os_log(.error, log: log, "error retrieving free space #2: %s", "\(error.localizedDescription)")
        }
        
        return 0
    }
}
