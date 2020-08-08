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

internal class CapacityReader: Reader<DiskList> {
    private var disks: DiskList = DiskList()
    public var store: UnsafePointer<Store>? = nil
    
    public override func read() {
        let keys: [URLResourceKey] = [.volumeNameKey]
        let removableState = store?.pointee.bool(key: "Disk_removable", defaultValue: false) ?? false
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)!
        
        if let session = DASessionCreate(kCFAllocatorDefault) {
            for url in paths {
                if url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                    if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                        if let diskName = DADiskGetBSDName(disk) {
                            let BSDName: String = String(cString: diskName)
                            
                            if let d: diskInfo = self.disks.getDiskByBSDName(BSDName) {
                                if let idx = self.disks.list.firstIndex(where: { $0.mediaBSDName == BSDName }) {
                                    if d.removable && !removableState {
                                        self.disks.list.remove(at: idx)
                                        continue
                                    }
                                    
                                    if let path = self.disks.list[idx].path {
                                        self.disks.list[idx].freeSize = freeDiskSpaceInBytes(path.absoluteString)
                                    }
                                }
                                continue
                            }
                            
                            if let d = getDisk(disk, removableState: removableState) {
                                self.disks.list.append(d)
                                self.disks.list.sort{ $1.removable }
                            }
                        }
                    }
                }
            }
        }
        
        self.callback(self.disks)
    }
    
    private func getDisk(_ disk: DADisk, removableState: Bool) -> diskInfo? {
        var d: diskInfo = diskInfo()
        
        if let bsdName = DADiskGetBSDName(disk) {
            d.mediaBSDName = String(cString: bsdName)
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
                
                if let mediaName = dict[kDADiskDescriptionMediaNameKey as String] {
                    d.name = mediaName as! String
                }
                if let mediaSize = dict[kDADiskDescriptionMediaSizeKey as String] {
                    d.totalSize = Int64(truncating: mediaSize as! NSNumber)
                }
                if let deviceModel = dict[kDADiskDescriptionDeviceModelKey as String] {
                    d.model = (deviceModel as! String).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let deviceProtocol = dict[kDADiskDescriptionDeviceProtocolKey as String] {
                    d.connection = deviceProtocol as! String
                }
                if let volumePath = dict[kDADiskDescriptionVolumePathKey as String] {
                    let url = volumePath as? NSURL
                    if url != nil {
                        if url!.pathComponents!.count > 1 && url!.pathComponents![1] == "Volumes" {
                            let lastPath: String = (url?.lastPathComponent)!
                            if lastPath != "" {
                                d.name = lastPath
                                d.path = URL(string: "/Volumes/\(lastPath)")
                            }
                        } else if url!.pathComponents!.count == 1 {
                            d.path = URL(string: "/")
                            d.root = true
                        }
                    }
                }
                if let volumeKind = dict[kDADiskDescriptionVolumeKindKey as String] {
                    d.fileSystem = volumeKind as! String
                }
            }
        }
        
        if d.path != nil {
            d.freeSize = freeDiskSpaceInBytes(d.path!.absoluteString)
        }
        
        return d.name == "Recovery" ? nil : d
    }
    
    private func freeDiskSpaceInBytes(_ path: String) -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
            return freeSpace!
        } catch {
            return 0
        }
    }
}

// https://gist.github.com/kainjow/0e7650cc797a52261e0f4ba851477c2f
internal class IOReader: Reader<IO> {
    public var stats: IO = IO()
    
    public override func read() {
        let initialNumPids = proc_listallpids(nil, 0)
        let buffer = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(initialNumPids))
        defer {
            buffer.deallocate()
        }
        
        let bufferLength = initialNumPids * Int32(MemoryLayout<pid_t>.size)
        let numPids = proc_listallpids(buffer, bufferLength)
        
        var read: Int = 0
        var write: Int = 0
        for i in 0..<numPids {
            let pid = buffer[Int(i)]
            var usage = rusage_info_current()
            let result = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }
            
            if result == kIOReturnSuccess {
                read += Int(usage.ri_diskio_bytesread)
                write += Int(usage.ri_diskio_byteswritten)
            }
        }
        
        if self.stats.read != 0 && self.stats.write != 0 {
            self.stats.read = read - self.stats.read
            self.stats.write = write - self.stats.write
        }
        
        self.callback(self.stats)
        
        self.stats.read = read
        self.stats.write = write
    }
}
