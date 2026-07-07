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
import Kit
import IOKit.storage
import CoreServices

let kIONVMeSMARTUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                                  0xAA, 0x0F, 0xA6, 0xF9,
                                                                  0xC2, 0xD6, 0x45, 0x7F,
                                                                  0xB1, 0x0B, 0x59, 0xA1,
                                                                  0x32, 0x53, 0x29, 0x2F
)
let kIONVMeSMARTInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                             0xCC, 0xD1, 0xDB, 0x19,
                                                             0xFD, 0x9A, 0x4D, 0xAF,
                                                             0xBF, 0x95, 0x12, 0x45,
                                                             0x4B, 0x23, 0x0A, 0xB6
)
let kIOCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0xC2, 0x44, 0xE8, 0x58,
                                                            0x10, 0x9C, 0x11, 0xD4,
                                                            0x91, 0xD4, 0x00, 0x50,
                                                            0xE4, 0xC6, 0x42, 0x6F
)
let kIOATASMARTUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                                 0x24, 0x51, 0x4B, 0x7A,
                                                                 0x28, 0x04, 0x11, 0xD6,
                                                                 0x8A, 0x02, 0x00, 0x30,
                                                                 0x65, 0x70, 0x48, 0x66
)
let kIOATASMARTInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0x08, 0xAB, 0xE2, 0x1C,
                                                            0x20, 0xD4, 0x11, 0xD6,
                                                            0x8D, 0xF6, 0x00, 0x03,
                                                            0x93, 0x5A, 0x76, 0xB2
)

internal class CapacityReader: Reader<Disks> {
    internal var list: Disks = Disks()
    
    private var SMART: Bool {
        Store.shared.bool(key: "\(ModuleType.disk.stringValue)_SMART", defaultValue: true)
    }
    private var ATASMART: Bool {
        Store.shared.bool(key: "\(ModuleType.disk.stringValue)_ATASMART", defaultValue: false)
    }
    
    private var purgableSpace: [URL: (Date, Int64)] = [:]
    private var smartTotals: [String: (read: Int64, written: Int64)] = [:]
    private var smartEnableAttempted: Set<String> = []
    
    public override func read() {
        let keys: [URLResourceKey] = [.volumeNameKey]
        let removableState = Store.shared.bool(key: "Disk_removable", defaultValue: false)
        guard let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return
        }
        
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            error("cannot create main DASessionCreate()", log: self.log)
            return
        }
        
        var active: [String] = []
        for url in paths {
            if url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                    if let diskName = DADiskGetBSDName(disk) {
                        let BSDName: String = String(cString: diskName)
                        active.append(BSDName)
                        
                        if let d = self.list.first(where: { $0.BSDName == BSDName}), let idx = self.list.index(where: { $0.BSDName == BSDName}) {
                            if d.removable && !removableState {
                                self.list.remove(at: idx)
                                continue
                            }
                            
                            if let path = d.path {
                                self.list.updateFreeSize(idx, newValue: self.freeDiskSpaceInBytes(path))
                                self.list.updateSMARTData(idx, smart: self.getSMARTDetails(for: BSDName))
                            }
                            
                            continue
                        }
                        
                        if var d = driveDetails(disk, removableState: removableState) {
                            if let path = d.path {
                                d.free = self.freeDiskSpaceInBytes(path)
                                d.size = self.totalDiskSpaceInBytes(path)
                            }
                            d.smart = self.getSMARTDetails(for: BSDName)
                            guard d.size != 0 else { continue }
                            self.list.append(d)
                            self.list.sort()
                        }
                    }
                }
            }
        }
        
        active.difference(from: self.list.map{ $0.BSDName }).forEach { (BSDName: String) in
            if let idx = self.list.index(where: { $0.BSDName == BSDName }) {
                self.list.remove(at: idx)
            }
        }
        
        self.callback(self.list)
        
    }
    private func freeDiskSpaceInBytes(_ path: URL) -> Int64 {
        var path = path
        path.removeAllCachedResourceValues()
        
        var stat = statfs()
        if statfs(path.path, &stat) == 0 {
            var purgeable: Int64 = 0
            if self.purgableSpace[path] == nil {
                let value = CSDiskSpaceGetRecoveryEstimate(path as NSURL)
                purgeable = Int64(value)
                self.purgableSpace[path] = (Date(), purgeable)
            } else if let pair = self.purgableSpace[path] {
                let delta = Date().timeIntervalSince(pair.0)
                if delta > 30 {
                    let value = CSDiskSpaceGetRecoveryEstimate(path as NSURL)
                    purgeable = Int64(value)
                    self.purgableSpace[path] = (Date(), purgeable)
                } else {
                    purgeable = pair.1
                }
            }
            return (Int64(stat.f_bfree) * Int64(stat.f_bsize)) + Int64(purgeable)
        }
        
        do {
            let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage, capacity != 0 {
                return capacity
            }
        } catch let err {
            error("error retrieving free space #1: \(err.localizedDescription)", log: self.log)
        }
        
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: path.path)
            if let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value {
                return freeSpace
            }
        } catch let err {
            error("error retrieving free space: \(err.localizedDescription)", log: self.log)
        }
        
        return 0
    }
    
    private func totalDiskSpaceInBytes(_ path: URL) -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: path.path)
            if let totalSpace = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value {
                return totalSpace
            }
        } catch let err {
            error("error retrieving total space: \(err.localizedDescription)", log: self.log)
        }
        
        return 0
    }
    
    private func getSMARTDetails(for BSDName: String) -> smart_t? {
        guard self.SMART else { return nil }
        
        var disk = IOServiceGetMatchingService(kIOMainPortDefault, IOBSDNameMatching(kIOMainPortDefault, 0, BSDName.cString(using: .utf8)))
        guard disk != kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(disk) }
        
        var parent = disk
        while IOObjectConformsTo(disk, kIOBlockStorageDeviceClass) == 0 {
            let error = IORegistryEntryGetParentEntry(disk, kIOServicePlane, &parent)
            if error != kIOReturnSuccess || parent == kIOReturnSuccess { return nil }
            disk = parent
        }
        
        guard IOObjectConformsTo(disk, kIOBlockStorageDeviceClass) > 0 else { return nil }
        
        if let smart = self.getNVMeSMART(for: disk) { return smart }
        if self.ATASMART, let smart = self.getATASMART(for: disk, BSDName: BSDName) { return smart }
        return nil
    }
    
    private func getNVMeSMART(for disk: io_object_t) -> smart_t? {
        guard let raw = IORegistryEntryCreateCFProperty(disk, "NVMe SMART Capable" as CFString, kCFAllocatorDefault, 0),
              let val = raw.takeRetainedValue() as? Bool, val else {
            return nil
        }
        
        var pluginInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var smartInterface: UnsafeMutablePointer<UnsafeMutablePointer<IONVMeSMARTInterface>?>?
        var score: Int32  = 0
        
        var result = IOCreatePlugInInterfaceForService(disk, kIONVMeSMARTUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score)
        guard result == kIOReturnSuccess else { return nil }
        defer {
            if pluginInterface != nil {
                IODestroyPlugInInterface(pluginInterface)
            }
        }
        
        result = withUnsafeMutablePointer(to: &smartInterface) {
            $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) {
                pluginInterface?.pointee?.pointee.QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIONVMeSMARTInterfaceID), $0) ?? KERN_NOT_FOUND
            }
        }
        
        guard result == kIOReturnSuccess else { return nil }
        defer {
            if smartInterface != nil {
                _ = pluginInterface?.pointee?.pointee.Release(smartInterface)
            }
        }
        
        guard let smart = smartInterface?.pointee else { return nil }
        var smartData: nvme_smart_log = nvme_smart_log()
        guard smart.pointee.SMARTReadData(smartInterface, &smartData) == kIOReturnSuccess else { return nil }
        
        let temperatures: [UInt8] = [UInt8(smartData.temperature.1), UInt8(smartData.temperature.0)]
        var temperature: UInt16 = 0
        let data = NSData(bytes: temperatures, length: 2)
        data.getBytes(&temperature, length: 2)
        
        let dataUnitsRead = self.extractUInt128(smartData.data_units_read)
        let dataUnitsWritten = self.extractUInt128(smartData.data_units_written)
        let bytesPerDataUnit: Int64 = 512 * 1000
        
        let powerCycles = withUnsafeBytes(of: smartData.power_cycles) { $0.load(as: UInt32.self) }
        let powerOnHours = withUnsafeBytes(of: smartData.power_on_hours) { $0.load(as: UInt32.self) }
        
        return smart_t(
            temperature: Int(UInt16(bigEndian: temperature) - 273),
            life: 100 - Int(smartData.percent_used),
            totalRead: dataUnitsRead * bytesPerDataUnit,
            totalWritten: dataUnitsWritten * bytesPerDataUnit,
            powerCycles: Int(powerCycles),
            powerOnHours: Int(powerOnHours)
        )
    }
    
    private func getATASMART(for disk: io_object_t, BSDName: String) -> smart_t? {
        guard let raw = IORegistryEntryCreateCFProperty(disk, "SMART Capable" as CFString, kCFAllocatorDefault, 0),
              let val = raw.takeRetainedValue() as? Bool, val else {
            return nil
        }
        
        var pluginInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var smartInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOATASMARTInterface>?>?
        var score: Int32 = 0
        
        var result = IOCreatePlugInInterfaceForService(disk, kIOATASMARTUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score)
        guard result == kIOReturnSuccess else { return nil }
        defer {
            if pluginInterface != nil {
                IODestroyPlugInInterface(pluginInterface)
            }
        }
        
        result = withUnsafeMutablePointer(to: &smartInterface) {
            $0.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) {
                pluginInterface?.pointee?.pointee.QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOATASMARTInterfaceID), $0) ?? KERN_NOT_FOUND
            }
        }
        
        guard result == kIOReturnSuccess else { return nil }
        defer {
            if smartInterface != nil {
                _ = pluginInterface?.pointee?.pointee.Release(smartInterface)
            }
        }
        
        guard let smart = smartInterface?.pointee else { return nil }
        
        var smartData = ATASMARTData()
        var readResult = smart.pointee.SMARTReadData(smartInterface, &smartData)
        if readResult != kIOReturnSuccess && !self.smartEnableAttempted.contains(BSDName) {
            self.smartEnableAttempted.insert(BSDName)
            _ = smart.pointee.SMARTEnableDisableOperations(smartInterface, true)
            readResult = smart.pointee.SMARTReadData(smartInterface, &smartData)
        }
        guard readResult == kIOReturnSuccess else { return nil }
        
        var attributes: [Int: (current: Int, raw: [UInt8])] = [:]
        withUnsafeBytes(of: &smartData) { buffer in
            for i in 0..<30 {
                let offset = 2 + i * 12
                let id = Int(buffer[offset])
                if id == 0 { continue }
                let current = Int(buffer[offset + 3])
                var rawBytes: [UInt8] = []
                for j in 0..<6 {
                    rawBytes.append(buffer[offset + 5 + j])
                }
                attributes[id] = (current, rawBytes)
            }
        }
        
        func rawValue(_ id: Int, bytes count: Int = 6) -> UInt64? {
            guard let attribute = attributes[id] else { return nil }
            var value: UInt64 = 0
            for i in 0..<min(count, attribute.raw.count) {
                value |= UInt64(attribute.raw[i]) << (8 * i)
            }
            return value
        }
        
        var temperature = 0
        if let temp = rawValue(194, bytes: 1) ?? rawValue(190, bytes: 1) {
            temperature = Int(temp)
        }
        
        var life = 100
        for id in [231, 202, 177, 173, 169, 233] {
            if let attribute = attributes[id] {
                life = min(max(attribute.current, 0), 100)
                break
            }
        }
        
        let bytesPerLBA: Int64 = 512
        
        var deviceRead: Int64?
        var deviceWritten: Int64?
        
        let pageCount = 8
        let logSize = 512 * pageCount
        var logBuffer = [UInt8](repeating: 0, count: logSize)
        let logResult = logBuffer.withUnsafeMutableBytes {
            smart.pointee.SMARTReadLogAtAddress(smartInterface, 0x04, $0.baseAddress, UInt32(logSize))
        }
        if logResult == kIOReturnSuccess {
            func deviceStatistic(page: Int, offset: Int) -> UInt64? {
                let base = page * 512 + offset
                guard base + 8 <= logBuffer.count else { return nil }
                var value: UInt64 = 0
                for i in 0..<8 {
                    value |= UInt64(logBuffer[base + i]) << (8 * i)
                }
                guard (value & (UInt64(1) << 63)) != 0, (value & (UInt64(1) << 62)) != 0 else { return nil }
                return value & 0x0000_FFFF_FFFF_FFFF
            }
            
            if let written = deviceStatistic(page: 1, offset: 0x18) {
                let (bytes, overflow) = Int64(written).multipliedReportingOverflow(by: bytesPerLBA)
                if !overflow {
                    deviceWritten = bytes
                }
            }
            if let read = deviceStatistic(page: 1, offset: 0x28) {
                let (bytes, overflow) = Int64(read).multipliedReportingOverflow(by: bytesPerLBA)
                if !overflow {
                    deviceRead = bytes
                }
            }
            if let used = deviceStatistic(page: 7, offset: 0x08) {
                life = max(0, 100 - Int(used & 0xFF))
            }
        }
        
        if deviceRead != nil || deviceWritten != nil {
            let cached = self.smartTotals[BSDName]
            self.smartTotals[BSDName] = (
                read: deviceRead ?? cached?.read ?? 0,
                written: deviceWritten ?? cached?.written ?? 0
            )
        }
        
        let totalRead = deviceRead ?? self.smartTotals[BSDName]?.read ?? Int64(rawValue(242) ?? 0) * bytesPerLBA
        let totalWritten = deviceWritten ?? self.smartTotals[BSDName]?.written ?? Int64(rawValue(241) ?? 0) * bytesPerLBA
        
        return smart_t(
            temperature: temperature,
            life: life,
            totalRead: totalRead,
            totalWritten: totalWritten,
            powerCycles: Int(rawValue(12, bytes: 4) ?? 0),
            powerOnHours: Int(rawValue(9, bytes: 4) ?? 0)
        )
    }
    
    private func extractUInt128(_ tuple: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> Int64 {
        let byteArray: [UInt8] = [
            tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7,
            tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15
        ]
        
        let uint64Value = byteArray.prefix(8).withUnsafeBytes { $0.load(as: UInt64.self) }
        let hasHigherBytes = byteArray.suffix(8).contains(where: { $0 != 0 })
        
        if hasHigherBytes || uint64Value > UInt64(Int64.max) {
            return Int64.max
        }
        
        return Int64(uint64Value)
    }
}

internal class ActivityReader: Reader<Disks> {
    internal var list: Disks = Disks()
    
    override func setup() {
        self.setInterval(1)
    }
    
    public override func read() {
        let keys: [URLResourceKey] = [.volumeNameKey]
        let removableState = Store.shared.bool(key: "Disk_removable", defaultValue: false)
        guard let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys) else {
            return
        }
        
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            error("cannot create a DASessionCreate()", log: self.log)
            return
        }
        
        var active: [String] = []
        for url in paths {
            if url.pathComponents.count == 1 || (url.pathComponents.count > 1 && url.pathComponents[1] == "Volumes") {
                if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) {
                    if let diskName = DADiskGetBSDName(disk) {
                        let BSDName: String = String(cString: diskName)
                        active.append(BSDName)
                        
                        if let d = self.list.first(where: { $0.BSDName == BSDName}), let idx = self.list.index(where: { $0.BSDName == BSDName}) {
                            if d.removable && !removableState {
                                self.list.remove(at: idx)
                                continue
                            }
                            
                            self.driveStats(idx, d)
                            continue
                        }
                        
                        if let d = driveDetails(disk, removableState: removableState) {
                            self.list.append(d)
                            self.list.sort()
                        }
                    }
                }
            }
        }
        
        active.difference(from: self.list.map{ $0.BSDName }).forEach { (BSDName: String) in
            if let idx = self.list.index(where: { $0.BSDName == BSDName }) {
                self.list.remove(at: idx)
            }
        }
        
        self.callback(self.list)
    }
    
    private func driveStats(_ idx: Int, _ d: drive) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOBSDNameMatching(kIOMainPortDefault, 0, d.BSDName))
        if service == 0 { return }
        IOObjectRelease(service)
        
        guard let props = getIOProperties(d.parent) else { return }
        
        if let statistics = props.object(forKey: "Statistics") as? NSDictionary {
            let readBytes = statistics.object(forKey: "Bytes (Read)") as? Int64 ?? 0
            let writeBytes = statistics.object(forKey: "Bytes (Write)") as? Int64 ?? 0
            
            if d.activity.readBytes != 0 {
                self.list.updateRead(idx, newValue: readBytes - d.activity.readBytes)
            }
            if d.activity.writeBytes != 0 {
                self.list.updateWrite(idx, newValue: writeBytes - d.activity.writeBytes)
            }
            
            self.list.updateReadWrite(idx, read: readBytes, write: writeBytes)
        }
        
        return
    }
}

private func driveDetails(_ disk: DADisk, removableState: Bool) -> drive? {
    var d: drive = drive()
    
    if let bsdName = DADiskGetBSDName(disk) {
        d.BSDName = String(cString: bsdName)
    }
    
    if let diskDescription = DADiskCopyDescription(disk) {
        if let dict = diskDescription as? [String: AnyObject] {
            if let removable = dict[kDADiskDescriptionMediaRemovableKey as String] as? Bool {
                if removable {
                    if !removableState {
                        return nil
                    }
                    d.removable = true
                }
            }
            
            if let mediaUUID = dict[kDADiskDescriptionMediaUUIDKey as String], CFGetTypeID(mediaUUID) == CFUUIDGetTypeID() {
                d.uuid = CFUUIDCreateString(kCFAllocatorDefault, (mediaUUID as! CFUUID)) as String
            }
            if let mediaName = dict[kDADiskDescriptionVolumeNameKey as String] as? String {
                d.mediaName = mediaName
                if d.mediaName == "Recovery" {
                    return nil
                }
            }
            if d.mediaName == "" {
                if let mediaName = dict[kDADiskDescriptionMediaNameKey as String] as? String {
                    d.mediaName = mediaName
                    if d.mediaName == "Recovery" {
                        return nil
                    }
                }
            }
            if let deviceModel = dict[kDADiskDescriptionDeviceModelKey as String] as? String {
                d.model = deviceModel.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let deviceProtocol = dict[kDADiskDescriptionDeviceProtocolKey as String] as? String {
                d.connectionType = deviceProtocol
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
            if let volumeKind = dict[kDADiskDescriptionVolumeKindKey as String] as? String {
                d.fileSystem = volumeKind
            }
        }
    }
    
    if d.path == nil {
        return nil
    }
    if d.uuid == "" || d.uuid == "00000000-0000-0000-0000-000000000000" {
        d.uuid = d.BSDName
    }
    
    let partitionLevel = d.BSDName.filter { "0"..."9" ~= $0 }.count
    if let parent = getDeviceIOParent(DADiskCopyIOMedia(disk), level: Int(partitionLevel)) {
        d.parent = parent
    }
    
    return d
}

// https://opensource.apple.com/source/bless/bless-152/libbless/APFS/BLAPFSUtilities.c.auto.html
public func getDeviceIOParent(_ obj: io_registry_entry_t, level: Int) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0
    
    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }
    
    for _ in 1...level where IORegistryEntryGetParentEntry(parent, kIOServicePlane, &parent) != KERN_SUCCESS {
        IOObjectRelease(parent)
        return nil
    }
    
    return parent
}

struct io {
    var read: Int
    var write: Int
}

public class ProcessReader: Reader<[Disk_process]> {
    private let queue = DispatchQueue(label: "eu.exelban.Disk.processReader")
    
    private var _list: [Int32: io] = [:]
    private var list: [Int32: io] {
        get {
            self.queue.sync { self._list }
        }
        set {
            self.queue.sync { self._list = newValue }
        }
    }
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(ModuleType.disk.stringValue)_processes", defaultValue: 5)
    }
    
    public override func setup() {
        self.popup = true
        self.setInterval(1)
    }
    
    public override func read() {
        guard self.numberOfProcesses != 0, let output = runProcess(path: "/bin/ps", args: ["-Aceo pid,args", "-r"]) else { return }
        
        var snapshot = self.list
        var processes: [Disk_process] = []
        output.enumerateLines { (line, _) in
            let str = line.trimmingCharacters(in: .whitespaces)
            let pidFind = str.findAndCrop(pattern: "^\\d+")
            guard let pid = Int32(pidFind.cropped) else { return }
            let name = pidFind.remain.findAndCrop(pattern: "^[^ ]+").cropped
            
            var usage = rusage_info_current()
            let result = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: (rusage_info_t?.self), capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }
            guard result != -1 else { return }
            
            let bytesRead = Int(clamping: usage.ri_diskio_bytesread)
            let bytesWritten = Int(clamping: usage.ri_diskio_byteswritten)
            
            if snapshot[pid] == nil {
                snapshot[pid] = io(read: bytesRead, write: bytesWritten)
            }
            
            if let v = snapshot[pid] {
                let read = bytesRead - v.read
                let write = bytesWritten - v.write
                if read != 0 || write != 0 {
                    processes.append(Disk_process(pid: Int(pid), name: name, read: read, write: write))
                }
            }
            
            snapshot[pid]?.read = bytesRead
            snapshot[pid]?.write = bytesWritten
        }
        self.list = snapshot
        
        processes.sort {
            let firstMax = max($0.read, $0.write)
            let secondMax = max($1.read, $1.write)
            let firstMin = min($0.read, $0.write)
            let secondMin = min($1.read, $1.write)
            
            if firstMax == secondMax && firstMin != secondMin { // max values are the same, min not. Sort by min values
                return firstMin < secondMin
            }
            return firstMax < secondMax // max values are not the same, sort by max value
        }
        
        self.callback(processes.suffix(self.numberOfProcesses).reversed())
    }
}

private func runProcess(path: String, args: [String] = []) -> String? {
    let task = Process()
    task.launchPath = path
    task.arguments = args
    
    let outputPipe = Pipe()
    defer {
        outputPipe.fileHandleForReading.closeFile()
    }
    task.standardOutput = outputPipe
    
    do {
        try task.run()
    } catch {
        return nil
    }
    
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: outputData, encoding: .utf8)
}
