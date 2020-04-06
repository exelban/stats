//
//  DiskCapacityReader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

struct diskInfo {
    var ID: String = "";
    
    var name: String = "";
    var model: String = "";
    var path: URL?;
    var connection: String = "";
    var fileSystem: String = "";
    
    var totalSize: Int64 = 0;
    var freeSize: Int64 = 0;
    
    var mediaBSDName: String = "";
    var root: Bool = false;
}

struct disksList {
    var list: [diskInfo] = []
    
    func getDiskByBSDName(_ name: String) -> diskInfo? {
        let idx = self.list.firstIndex { $0.mediaBSDName == name }
        
        if idx == nil {
            return nil
        }
        
        return self.list[idx!]
    }
    
    func getDiskByName(_ name: String) -> diskInfo? {
        let idx = self.list.firstIndex { $0.name == name }
        
        if idx == nil {
            return nil
        }
        
        return self.list[idx!]
    }
    
    func getRootDisk() -> diskInfo? {
        let idx = self.list.firstIndex { $0.root }
        
        if idx == nil {
            return nil
        }
        
        return self.list[idx!]
    }
}

class DiskCapacityReader: Reader {
    public var name: String = "Capacity"
    public var enabled: Bool = true
    public var available: Bool = true
    public var optional: Bool = false
    public var initialized: Bool = false
    public var callback: (disksList) -> Void = {_ in}
    
    private var disks: disksList = disksList()
    
    init(_ updater: @escaping (disksList) -> Void) {
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
        
        let keys: [URLResourceKey] = [.volumeNameKey]
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)!
        if let session = DASessionCreate(kCFAllocatorDefault) {
            for url in paths {
                if url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                    if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                        let BSDName: String = String(cString: DADiskGetBSDName(disk)!)
                        
                        if let _: diskInfo = self.disks.getDiskByBSDName(BSDName) {
                            let idx = self.disks.list.firstIndex { $0.mediaBSDName == BSDName }
                            self.disks.list[idx!].freeSize = freeDiskSpaceInBytes(self.disks.list[idx!].path!.absoluteString)
                            continue
                        }
                        
                        if let d = getDisk(disk) {
                            self.disks.list.append(d)
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.async(execute: {
            self.callback(self.disks)
        })
    }
    
    public func toggleEnable(_ value: Bool) {
        self.enabled = value
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
