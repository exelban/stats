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
    public var name: String? = nil
    public var physicalCores: Int8? = nil
    public var logicalCores: Int8? = nil
}

public struct dimm_s {
    public var bank: Int? = nil
    public var channel: String? = nil
    public var type: String? = nil
    public var size: String? = nil
    public var speed: String? = nil
}

public struct ram_s {
    public var dimms: [dimm_s] = []
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
    public var model: model_s = model_s(name: LocalizedString("Unknown"), year: Calendar.current.component(.year, from: Date()), type: .unknown)
    public var modelIdentifier: String? = nil
    public var serialNumber: String? = nil
    public var bootDate: Date? = nil
    
    public var os: os_s? = nil
    public var info: info_s = info_s()
}

public class SystemKit {
    public static let shared = SystemKit()
    
    public var device: device_s = device_s()
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SystemKit")
    
    public init() {
        if let modelName = self.modelName() {
            if let modelInfo = deviceDict[modelName] {
                self.device.model = modelInfo
                self.device.model.icon = self.getIcon(type: self.device.model.type)
            } else {
                os_log(.error, log: self.log, "unknown device %s", modelName)
            }
        }
        
        let (modelID, serialNumber) = self.modelAndSerialNumber()
        if modelID != nil {
            self.device.modelIdentifier = modelID
        }
        if serialNumber != nil {
            self.device.serialNumber = serialNumber
        }
        self.device.bootDate = self.bootDate()
        
        let procInfo = ProcessInfo()
        let systemVersion = procInfo.operatingSystemVersion
        
        var build = LocalizedString("Unknown")
        let buildArr = procInfo.operatingSystemVersionString.split(separator: "(")
        if buildArr.indices.contains(1) {
            build = buildArr[1].replacingOccurrences(of: "Build ", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        let version = systemVersion.majorVersion > 10 ? "\(systemVersion.majorVersion)" : "\(systemVersion.majorVersion).\(systemVersion.minorVersion)"
        self.device.os = os_s(name: osDict[version] ?? LocalizedString("Unknown"), version: systemVersion, build: build)
        
        self.device.info.cpu = self.getCPUInfo()
        self.device.info.ram = self.getRamInfo()
        self.device.info.gpu = self.getGPUInfo()
        self.device.info.disk = self.getDiskInfo()
    }
    
    public func modelName() -> String? {
        var mib = [CTL_HW, HW_MODEL]
        var size = MemoryLayout<io_name_t>.size
        
        let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        defer {
            pointer.deallocate()
        }
        let result = sysctl(&mib, u_int(mib.count), pointer, &size, nil, 0)
        
        if result == KERN_SUCCESS {
            return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
        }
        
        os_log(.error, log: self.log, "error call sysctl(): %s", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    func modelAndSerialNumber() -> (String?, String?) {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        var modelIdentifier: String?
        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }
        
        var serialNumber: String?
        if let serialString = IORegistryEntryCreateCFProperty(service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String {
            serialNumber = serialString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        IOObjectRelease(service)
        return (modelIdentifier, serialNumber)
    }
    
    func bootDate() -> Date? {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size
        
        let result = sysctl(&mib, UInt32(mib.count), &bootTime, &bootTimeSize, nil, 0)
        if result == KERN_SUCCESS {
            return Date(timeIntervalSince1970: Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000.0)
        }
        
        os_log(.error, log: self.log, "error get boot time: %s", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    private func getCPUInfo() -> cpu_s? {
        var cpu = cpu_s()
        
        var sizeOfName = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &sizeOfName, nil, 0)
        var nameCharts = [CChar](repeating: 0,  count: sizeOfName)
        sysctlbyname("machdep.cpu.brand_string", &nameCharts, &sizeOfName, nil, 0)
        var name = String(cString: nameCharts)
        if name != "" {
            name = name.replacingOccurrences(of: "(TM)", with: "")
            name = name.replacingOccurrences(of: "(R)", with: "")
            name = name.replacingOccurrences(of: "CPU", with: "")
            name = name.replacingOccurrences(of: "@", with: "")
            
            cpu.name = name.condenseWhitespace()
        }
        
        var size = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostInfo = host_basic_info_t.allocate(capacity: 1)
        defer {
            hostInfo.deallocate()
        }
              
        let result = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_info(mach_host_self(), HOST_BASIC_INFO, $0, &size)
        }
        
        if result != KERN_SUCCESS {
            os_log(.error, log: self.log, "read cores number: %s", (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        let data = hostInfo.move()
        cpu.physicalCores = Int8(data.physical_cpu)
        cpu.logicalCores = Int8(data.logical_cpu)
        
        return cpu
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
                            guard let model = dict.object(forKey: "model") as? Data else {
                                continue
                            }
                            let modelName = String(data: model, encoding: .ascii)!.replacingOccurrences(of: "\0", with: "")
                            gpu.append(gpu_s(name: modelName))
                        }
                    }
                }
                
                IOObjectRelease(device)
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
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPMemoryDataType", "-json"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
        } catch let error {
            os_log(.error, log: log, "system_profiler SPMemoryDataType: %s", "\(error.localizedDescription)")
            return nil
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        
        if output.isEmpty {
            return nil
        }
        
        let data = Data(output.utf8)
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                var ram: ram_s = ram_s()
                
                if let obj = json["SPMemoryDataType"] as? [[String:Any]], obj.count > 0 {
                    if let items = obj[0]["_items"] as? [[String: Any]], items.count > 0 {
                        for i in 0..<items.count {
                            let item = items[i]
                            
                            if item["dimm_size"] as? String == "empty" {
                                continue
                            }
                            
                            var dimm: dimm_s = dimm_s()
                            dimm.type = item["dimm_type"] as? String
                            dimm.speed = item["dimm_speed"] as? String
                            dimm.size = item["dimm_size"] as? String
                            
                            if let nameValue = item["_name"] as? String {
                                let arr = nameValue.split(separator: "/")
                                if arr.indices.contains(0) {
                                    dimm.bank = Int(arr[0].filter("0123456789.".contains))
                                }
                                if arr.indices.contains(1) && arr[1].contains("Channel") {
                                    dimm.channel = arr[1].split(separator: "-")[0].replacingOccurrences(of: "Channel", with: "")
                                }
                            }
                            
                            ram.dimms.append(dimm)
                        }
                    }
                }
                
                return ram
            }
        } catch let error as NSError {
            os_log(.error, log: self.log, "error to parse system_profiler SPMemoryDataType: %s", error.localizedDescription)
            return nil
        }
        
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
        case .macPro:
            icon = NSImage(named: NSImage.Name("macPro"))!
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
    "Macmini6,1": model_s(name: "Mac mini (Late 2012)", year: 2012, type: .macMini),
    "Macmini6,2": model_s(name: "Mac mini (Late 2012)", year: 2012, type: .macMini),
    "Macmini7,1": model_s(name: "Mac mini (Late 2014)", year: 2014, type: .macMini),
    "Macmini8,1": model_s(name: "Mac mini (Late 2018)", year: 2018, type: .macMini),
    "Macmini9,1": model_s(name: "Mac mini (M1, 2020)", year: 2020, type: .macMini),
    
    // Mac Pro
    "MacPro5,1": model_s(name: "Mac Pro (2012)", year: 2010, type: .macPro),
    "MacPro6,1": model_s(name: "Mac Pro (Late 2013)", year: 2016, type: .macPro),
    "MacPro7,1": model_s(name: "Mac Pro (2019)", year: 2019, type: .macPro),
    
    // iMac
    "iMac13,2": model_s(name: "iMac 27-Inch (Late 2012)", year: 2012, type: .imac),
    "iMac14,2": model_s(name: "iMac 27-Inch (Late 2013)", year: 2013, type: .imac),
    "iMac15,1": model_s(name: "iMac 27-Inch (5K, Late 2014)", year: 2014, type: .imac),
    "iMac17,1": model_s(name: "iMac 27-Inch (5K, Late 2015)", year: 2015, type: .imac),
    "iMac18,3": model_s(name: "iMac 27-Inch (5K, Mid 2017)", year: 2017, type: .imac),
    "iMac19,1": model_s(name: "iMac 27-Inch (5K, 2019)", year: 2019, type: .imac),
    
    // iMac Pro
    "iMacPro1,1": model_s(name: "iMac Pro (5K, Late 2017)", year: 2017, type: .imacpro),
    
    // MacBook
    "MacBook8,1": model_s(name: "MacBook (Early 2015)", year: 2015, type: .macbook),
    "MacBook9,1": model_s(name: "MacBook (Early 2016)", year: 2016, type: .macbook),
    "MacBook10,1": model_s(name: "MacBook (Early 2017)", year: 2017, type: .macbook),
    
    // MacBook Air
    "MacBookAir5,1": model_s(name: "MacBook Air 11\" (Mid 2012)", year: 2012, type: .macbookAir),
    "MacBookAir5,2": model_s(name: "MacBook Air 13\" (Mid 2012)", year: 2012, type: .macbookAir),
    "MacBookAir6,1": model_s(name: "MacBook Air 11\" (Early 2014)", year: 2014, type: .macbookAir),
    "MacBookAir6,2": model_s(name: "MacBook Air 13\" (Early 2014)", year: 2014, type: .macbookAir),
    "MacBookAir7,1": model_s(name: "MacBook Air 11\" (Early 2015)", year: 2015, type: .macbookAir),
    "MacBookAir7,2": model_s(name: "MacBook Air 13\" (Early 2015)", year: 2015, type: .macbookAir),
    "MacBookAir8,1": model_s(name: "MacBook Air 13\" (2018)", year: 2018, type: .macbookAir),
    "MacBookAir8,2": model_s(name: "MacBook Air 13\" (2019)", year: 2019, type: .macbookAir),
    "MacBookAir9,1": model_s(name: "MacBook Air 13\" (2020)", year: 2020, type: .macbookAir),
    "MacBookAir10,1": model_s(name: "MacBook Air 13\" (M1, 2020)", year: 2020, type: .macbookAir),
    
    // MacBook Pro
    "MacBookPro9,1": model_s(name: "MacBook Pro 15\" (Mid 2012)", year: 2012, type: .macbookPro),
    "MacBookPro9,2": model_s(name: "MacBook Pro 13\" (Mid 2012)", year: 2012, type: .macbookPro),
    "MacBookPro10,1": model_s(name: "MacBook Pro 15\" (Retina, Mid 2012)", year: 2012, type: .macbookPro),
    "MacBookPro10,2": model_s(name: "MacBook Pro 13\" (Retina, Late 2012)", year: 2012, type: .macbookPro),
    "MacBookPro11,1": model_s(name: "MacBook Pro 13\" (Retina, Mid 2014)", year: 2014, type: .macbookPro),
    "MacBookPro11,2": model_s(name: "MacBook Pro 15\" (Retina, Mid 2014)", year: 2014, type: .macbookPro),
    "MacBookPro11,3": model_s(name: "MacBook Pro 15\" (Retina, Mid 2014)", year: 2014, type: .macbookPro),
    "MacBookPro11,4": model_s(name: "MacBook Pro 15\" (Retina, Mid 2015)", year: 2015, type: .macbookPro),
    "MacBookPro11,5": model_s(name: "MacBook Pro 15\" (Retina, Mid 2015)", year: 2015, type: .macbookPro),
    "MacBookPro12,1": model_s(name: "MacBook Pro 13\" (Mid 2015)", year: 2015, type: .macbookPro),
    "MacBookPro13,1": model_s(name: "MacBook Pro 13\" (Late 2016)", year: 2016, type: .macbookPro),
    "MacBookPro13,2": model_s(name: "MacBook Pro 13\" (Late 2016)", year: 2016, type: .macbookPro),
    "MacBookPro13,3": model_s(name: "MacBook Pro 15\" (Late 2016)", year: 2016, type: .macbookPro),
    "MacBookPro14,1": model_s(name: "MacBook Pro 13\" (Mid 2017)", year: 2017, type: .macbookPro),
    "MacBookPro14,2": model_s(name: "MacBook Pro 13\" (Mid 2017)", year: 2017, type: .macbookPro),
    "MacBookPro14,3": model_s(name: "MacBook Pro 15\" (Mid 2017)", year: 2017, type: .macbookPro),
    "MacBookPro15,1": model_s(name: "MacBook Pro 15\" (Mid 2018)", year: 2018, type: .macbookPro),
    "MacBookPro15,2": model_s(name: "MacBook Pro 13\" (Mid 2019)", year: 2019, type: .macbookPro),
    "MacBookPro15,3": model_s(name: "MacBook Pro 15\" (Mid 2019)", year: 2019, type: .macbookPro),
    "MacBookPro15,4": model_s(name: "MacBook Pro 13\" (Mid 2019)", year: 2019, type: .macbookPro),
    "MacBookPro16,1": model_s(name: "MacBook Pro 16\" (Late 2019)", year: 2019, type: .macbookPro),
    "MacBookPro16,2": model_s(name: "MacBook Pro 13\" (Mid 2020)", year: 2019, type: .macbookPro),
    "MacBookPro16,3": model_s(name: "MacBook Pro 13\" (Mid 2020)", year: 2020, type: .macbookPro),
    "MacBookPro17,1": model_s(name: "MacBook Pro 13\" (M1, 2020)", year: 2020, type: .macbookPro),
]

let osDict: [String: String] = [
    "10.14": "Mojave",
    "10.15": "Catalina",
    "11": "Big Sur",
]
