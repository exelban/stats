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

class CapacityReader: Reader<DiskList> {
    private var disks: DiskList = DiskList()
    
    public override func setup() {
        self.interval = 10000
    }
    
    public override func read() {
        let keys: [URLResourceKey] = [.volumeNameKey]
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)!
        if let session = DASessionCreate(kCFAllocatorDefault) {
            for url in paths {
                if url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                    if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                        let BSDName: String = String(cString: DADiskGetBSDName(disk)!)
                        
                        if let _: diskInfo = self.disks.getDiskByBSDName(BSDName) {
                            if let idx = self.disks.list.firstIndex(where: { $0.mediaBSDName == BSDName }) {
                                if let path = self.disks.list[idx].path {
                                    self.disks.list[idx].freeSize = freeDiskSpaceInBytes(path.absoluteString)
                                }
                            }
                            continue
                        }
                        
                        if let d = getDisk(disk) {
                            self.disks.list.append(d)
                        }
                    }
                }
            }
        }
        
        self.callback(self.disks)
    }
    
    private func getDisk(_ disk: DADisk) -> diskInfo? {
        var d: diskInfo = diskInfo()
        
        if let bsdName = DADiskGetBSDName(disk) {
            d.mediaBSDName = String(cString: bsdName)
        }
        
        if let diskDescription = DADiskCopyDescription(disk) {
            if let dict = diskDescription as? [String: AnyObject] {
                if let removable = dict[kDADiskDescriptionMediaRemovableKey as String] {
                    if removable as! Bool {
                        return nil
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
        
        return d
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
