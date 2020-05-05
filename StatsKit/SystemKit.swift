//
//  SystemKit.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 13/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import os.log

public enum deviceType: Int {
    case unknown = -1
    case macMini = 1
    case macPro = 2
    case imac = 3
    case imacpro = 4
    case macbook = 5
    case macbookAir = 6
    case macbookPro = 7
}

public struct model_s {
    public let name: String
    public let year: Int
    public let type: deviceType
    public var icon: NSImage = NSImage(named: NSImage.Name("imacPro"))!
}

public struct os_s {
    public let name: String
    public let version: OperatingSystemVersion
    public let build: String
}

public struct cpu_s {
    public let physicalCores: Int8
    public let logicalCores: Int8
}

public struct ram_s {
    public var active: Double
    public var inactive: Double
    public var wired: Double
    public var compressed: Double
    public var total: Double
    public var used: Double
}

public struct gpu_s {
    public let name: String
}

public struct disk_s {
    public let name: String
    public let model: String
    public let size: Int64
}

public struct info_s {
    public var cpu: cpu_s? = nil
    public var ram: ram_s? = nil
    public var gpu: [gpu_s]? = nil
    public var disk: disk_s? = nil
}

public struct device_s {
    public var model: model_s = model_s(name: "Unknown", year: 2020, type: .unknown)
    public var os: os_s? = nil
    public var info: info_s? = info_s()
}

public class SystemKit {
    public var device: device_s = device_s()
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SystemKit")
    
    public init() {
        if let modelName = self.modelName() {
            if let modelInfo = deviceDict[modelName] {
                self.device.model = modelInfo
            } else {
                os_log(.error, log: self.log, "unknown device %s", modelName)
            }
        }

        let procInfo = ProcessInfo()
        let systemVersion = procInfo.operatingSystemVersion
        let build = procInfo.operatingSystemVersionString.split(separator: "(")[1].replacingOccurrences(of: "Build ", with: "").replacingOccurrences(of: ")", with: "")

        self.device.os = os_s(name: osDict[systemVersion.minorVersion] ?? "Unknown", version: systemVersion, build: build)

        self.device.info?.cpu = self.getCPUInfo()
        self.device.info?.ram = self.getRamInfo()
        self.device.info?.gpu = self.getGPUInfo()
        self.device.info?.disk = self.getDiskInfo()
    }
    
    public func modelName() -> String? {
        var mib  = [CTL_HW, HW_MODEL]
        var size = MemoryLayout<io_name_t>.size
        
        let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        defer {
            pointer.deallocate()
        }
        let result = sysctl(&mib, u_int(mib.count), pointer, &size, nil, 0)
        
        if result == KERN_SUCCESS {
            return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
        }

        os_log(.error, log: self.log, "error call sysctl(): %v", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    private func getCPUInfo() -> cpu_s? {
        var size     = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostInfo = host_basic_info_t.allocate(capacity: 1)
        defer {
            hostInfo.deallocate()
        }
              
        let result = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_info(mach_host_self(), HOST_BASIC_INFO, $0, &size)
        }
        
        if result == KERN_SUCCESS {
            let data = hostInfo.move()
            return cpu_s(physicalCores: Int8(data.physical_cpu), logicalCores: Int8(data.logical_cpu))
        }
        
        os_log(.error, log: self.log, "hostInfo.withMemoryRebound(): %v", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    private func getGPUInfo() -> [gpu_s]? {
        var gpu: [gpu_s] = []
        var iterator: io_iterator_t = 0
        var device: io_object_t = 1
        
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &iterator)
        if result == kIOReturnSuccess {

            while device != 0 {
                device = IOIteratorNext(iterator)
                var serviceDictionary: Unmanaged<CFMutableDictionary>?
                
                if (IORegistryEntryCreateCFProperties(device, &serviceDictionary, kCFAllocatorDefault, 0) != kIOReturnSuccess) {
                    IOObjectRelease(device)
                    continue
                }
                
                if let props = serviceDictionary {
                    let dict = props.takeRetainedValue() as NSDictionary
                    
                    if let d = dict.object(forKey: "IOName") as? String {
                        if d == "display" {
                            let model = dict.object(forKey: "model") as! Data
                            let modelName = String(data: model, encoding: .ascii)!.replacingOccurrences(of: "\0", with: "")
                            gpu.append(gpu_s(name: modelName))
                        }
                    }
                }
            }
        }
        
        return gpu
    }
    
    private func getDiskInfo() -> disk_s? {
        var disk: DADisk? = nil
        
        let keys: [URLResourceKey] = [.volumeNameKey]
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)!
        if let session = DASessionCreate(kCFAllocatorDefault) {
            for url in paths {
                if url.pathComponents.count == 1 {
                    disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL)
                }
            }
        }
        
        if disk == nil {
            os_log(.error, log: self.log, "empty disk after fetching list")
            return nil
        }
        
        if let diskDescription = DADiskCopyDescription(disk!) {
            if let dict = diskDescription as? [String: AnyObject] {
                if let removable = dict[kDADiskDescriptionMediaRemovableKey as String] {
                    if removable as! Bool {
                        return nil
                    }
                }

                var name: String = ""
                var model: String = ""
                var size: Int64 = 0
                
                if let mediaName = dict[kDADiskDescriptionMediaNameKey as String] {
                    name = mediaName as! String
                }
                if let deviceModel = dict[kDADiskDescriptionDeviceModelKey as String] {
                    model = (deviceModel as! String).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let mediaSize = dict[kDADiskDescriptionMediaSizeKey as String] {
                    size = Int64(truncating: mediaSize as! NSNumber)
                }
                
                return disk_s(name: name, model: model, size: size)
            }
        }
        
        return nil
    }
    
    public func getRamInfo() -> ram_s? {
        var vmStats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        var totalSize: Double = 0
        
        var result: kern_return_t = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            totalSize = Double(vmStats.max_mem)
        } else {
            os_log(.error, log: self.log, "host_basic_info(): %v", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        var pageSize: vm_size_t = 0
        result = withUnsafeMutablePointer(to: &pageSize) { (size) -> kern_return_t in
            host_page_size(mach_host_self(), size)
        }
        
        var stats = vm_statistics64()
        count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let active = Double(stats.active_count) * Double(PAGE_SIZE)
            let inactive = Double(stats.inactive_count) * Double(PAGE_SIZE)
            let wired = Double(stats.wire_count) * Double(PAGE_SIZE)
            let compressed = Double(stats.compressor_page_count) * Double(PAGE_SIZE)
            
            return ram_s(
                active: active,
                inactive: inactive,
                wired: wired,
                compressed: compressed,
                total: totalSize,
                used: active + wired + compressed
            )
        }
        
        os_log(.error, log: self.log, "host_statistics64(): %v", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    private func getIcon(type: deviceType) -> NSImage {
        var icon: NSImage = NSImage()
        
        switch type {
        case .macMini:
            icon = NSImage(named: NSImage.Name("macMini"))!
            break
        case .imacpro:
            icon = NSImage(named: NSImage.Name("imacPro"))!
            break
        case .imac:
            icon = NSImage(named: NSImage.Name("imac"))!
            break
        case .macbook, .macbookAir:
            icon = NSImage(named: NSImage.Name("macbookAir"))!
            break
        case .macbookPro:
            icon = NSImage(named: NSImage.Name("macbookPro"))!
            break
        default:
            icon = NSImage(named: NSImage.Name("imacPro"))!
            break
        }
        
        return icon
    }
}

let deviceDict: [String: model_s] = [
    // Mac Mini
    "MacMini6,1": model_s(name: "Mac mini (Late 2012)", year: 2012, type: .macMini),
    "Macmini6,2": model_s(name: "Mac mini (Late 2012)", year: 2012, type: .macMini),
    "Macmini7,1": model_s(name: "Mac mini (Late 2014)", year: 2012, type: .macMini),
    "Macmini8,1": model_s(name: "Mac mini (Late 2018)", year: 2012, type: .macMini),
    
    // Mac Pro
    "MacPro6,1": model_s(name: "Mac Pro (Late 2013)", year: 2012, type: .macPro),
    "MacPro7,1": model_s(name: "Mac Pro (2019)", year: 2012, type: .macPro),
    
    // iMac
    "iMac13,2": model_s(name: "iMac 27-Inch (Late 2012)", year: 2012, type: .imac),
    "iMac14,2": model_s(name: "iMac 27-Inch (Late 2013)", year: 2012, type: .imac),
    "iMac15,1": model_s(name: "iMac 27-Inch (5K, Late 2014)", year: 2012, type: .imac),
    "iMac17,1": model_s(name: "iMac 27-Inch (5K, Late 2015)", year: 2012, type: .imac),
    "iMac18,3": model_s(name: "iMac 27-Inch (5K, Mid-2017)", year: 2012, type: .imac),
    "iMac19,1": model_s(name: "iMac 27-Inch (5K, 2019)", year: 2012, type: .imac),
    
    // iMac Pro
    "iMacPro1,1": model_s(name: "iMac Pro (5K, Late 2017)", year: 2017, type: .imacpro),
    
    // MacBook
    // MacBook Air
    // MacBook Pro
]

let osDict: [Int: String] = [
    13: "High Sierra",
    14: "Mojave",
    15: "Catalina",
]
