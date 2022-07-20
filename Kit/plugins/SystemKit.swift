//
//  SystemKit.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 13/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public enum deviceType: Int {
    case unknown = -1
    case macMini = 1
    case macPro = 2
    case imac = 3
    case imacpro = 4
    case macbook = 5
    case macbookAir = 6
    case macbookPro = 7
    case macStudio = 8
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
    public var name: String? = nil
    public var vendor: String? = nil
    public var vram: String? = nil
    public var cores: Int? = nil
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
    public var model: model_s = model_s(name: localizedString("Unknown"), year: Calendar.current.component(.year, from: Date()), type: .unknown)
    public var modelIdentifier: String? = nil
    public var serialNumber: String? = nil
    public var bootDate: Date? = nil
    
    public var os: os_s? = nil
    public var info: info_s = info_s()
}

public class SystemKit {
    public static let shared = SystemKit()
    
    public var device: device_s = device_s()
    private let log: NextLog = NextLog.shared.copy(category: "SystemKit")
    
    public init() {
        if let modelName = self.modelName() {
            if let modelInfo = deviceDict[modelName] {
                self.device.model = modelInfo
                self.device.model.icon = self.getIcon(type: self.device.model.type, year: self.device.model.year)
            } else {
                error("unknown device \(modelName)")
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
        
        var build = localizedString("Unknown")
        let buildArr = procInfo.operatingSystemVersionString.split(separator: "(")
        if buildArr.indices.contains(1) {
            build = buildArr[1].replacingOccurrences(of: "Build ", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        let version = systemVersion.majorVersion > 10 ? "\(systemVersion.majorVersion)" : "\(systemVersion.majorVersion).\(systemVersion.minorVersion)"
        self.device.os = os_s(name: osDict[version] ?? localizedString("Unknown"), version: systemVersion, build: build)
        
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
        
        error("error call sysctl(): \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")")
        return nil
    }
    
    func modelAndSerialNumber() -> (String?, String?) {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        var modelIdentifier: String?
        if let property = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0), let value = property.takeUnretainedValue() as? Data {
            modelIdentifier = String(data: value, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }
        
        var serialNumber: String?
        if let property = IORegistryEntryCreateCFProperty(service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0), let value = property.takeUnretainedValue() as? String {
            serialNumber = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
        
        error("error get boot time: \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")")
        return nil
    }
    
    private func getCPUInfo() -> cpu_s? {
        var cpu = cpu_s()
        
        var sizeOfName = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &sizeOfName, nil, 0)
        var nameCharts = [CChar](repeating: 0, count: sizeOfName)
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
            error("read cores number: \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")")
            return nil
        }
        
        let data = hostInfo.move()
        cpu.physicalCores = Int8(data.physical_cpu)
        cpu.logicalCores = Int8(data.logical_cpu)
        
        return cpu
    }
    
    private func getGPUInfo() -> [gpu_s]? {
        guard let res = process(path: "/usr/sbin/system_profiler", arguments: ["SPDisplaysDataType", "-json"]) else {
            return nil
        }
        
        var list: [gpu_s] = []
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(res.utf8), options: []) as? [String: Any] {
                if let arr = json["SPDisplaysDataType"] as? [[String: Any]] {
                    for obj in arr {
                        var gpu: gpu_s = gpu_s()
                        
                        gpu.name = obj["sppci_model"] as? String
                        gpu.vendor = obj["spdisplays_vendor"] as? String
                        gpu.cores = Int(obj["sppci_cores"] as? String ?? "")
                        
                        if let vram = obj["spdisplays_vram_shared"] as? String {
                            gpu.vram = vram
                        } else if let vram = obj["spdisplays_vram"] as? String {
                            gpu.vram = vram
                        }
                        
                        list.append(gpu)
                    }
                }
            }
        } catch let err as NSError {
            error("error to parse system_profiler SPDisplaysDataType: \(err.localizedDescription)")
            return nil
        }
        
        return list
    }
    
    private func getDiskInfo() -> disk_s? {
        var disk: DADisk? = nil
        
        let keys: [URLResourceKey] = [.volumeNameKey]
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys)!
        if let session = DASessionCreate(kCFAllocatorDefault) {
            for url in paths where url.pathComponents.count == 1 {
                disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL)
            }
        }
        
        if disk == nil {
            error("empty disk after fetching list")
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
        guard let res = process(path: "/usr/sbin/system_profiler", arguments: ["SPMemoryDataType", "-json"]) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(res.utf8), options: []) as? [String: Any] {
                var ram: ram_s = ram_s()
                
                if let obj = json["SPMemoryDataType"] as? [[String: Any]], !obj.isEmpty {
                    if let items = obj[0]["_items"] as? [[String: Any]] {
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
                    } else if let value = obj[0]["SPMemoryDataType"] as? String {
                        ram.dimms.append(dimm_s(bank: nil, channel: nil, type: nil, size: value, speed: nil))
                    }
                }
                
                return ram
            }
        } catch let err as NSError {
            error("error to parse system_profiler SPMemoryDataType: \(err.localizedDescription)")
            return nil
        }
        
        return nil
    }
    
    private func getIcon(type: deviceType, year: Int) -> NSImage {
        switch type {
        case .macMini:
            return NSImage(named: NSImage.Name("macMini"))!
        case .macStudio:
            return NSImage(named: NSImage.Name("macStudio"))!
        case .imacpro:
            return NSImage(named: NSImage.Name("imacPro"))!
        case .macPro:
            switch year {
            case 2019:
                return NSImage(named: NSImage.Name("macPro2019"))!
            default:
                return NSImage(named: NSImage.Name("macPro"))!
            }
        case .imac:
            return NSImage(named: NSImage.Name("imac"))!
        case .macbook, .macbookAir:
            return NSImage(named: NSImage.Name("macbookAir"))!
        case .macbookPro:
            return NSImage(named: NSImage.Name("macbookPro"))!
        default:
            return NSImage(named: NSImage.Name("imacPro"))!
        }
    }
}

let deviceDict: [String: model_s] = [
    // Mac Mini
    "Macmini6,1": model_s(name: "Mac mini", year: 2012, type: .macMini),
    "Macmini6,2": model_s(name: "Mac mini", year: 2012, type: .macMini),
    "Macmini7,1": model_s(name: "Mac mini", year: 2014, type: .macMini),
    "Macmini8,1": model_s(name: "Mac mini", year: 2018, type: .macMini),
    "Macmini9,1": model_s(name: "Mac mini (M1)", year: 2020, type: .macMini),
    
    // Mac Studio
    "Mac13,1": model_s(name: "Mac Studio (M1 Max)", year: 2022, type: .macStudio),
    "Mac13,2": model_s(name: "Mac Studio (M1 Ultra)", year: 2022, type: .macStudio),
    
    // Mac Pro
    "MacPro5,1": model_s(name: "Mac Pro", year: 2010, type: .macPro),
    "MacPro6,1": model_s(name: "Mac Pro", year: 2016, type: .macPro),
    "MacPro7,1": model_s(name: "Mac Pro", year: 2019, type: .macPro),
    
    // iMac
    "iMac12,1": model_s(name: "iMac 27-Inch", year: 2011, type: .imac),
    "iMac13,1": model_s(name: "iMac 21.5-Inch", year: 2012, type: .imac),
    "iMac13,2": model_s(name: "iMac 27-Inch", year: 2012, type: .imac),
    "iMac14,2": model_s(name: "iMac 27-Inch", year: 2013, type: .imac),
    "iMac15,1": model_s(name: "iMac 27-Inch", year: 2014, type: .imac),
    "iMac17,1": model_s(name: "iMac 27-Inch", year: 2015, type: .imac),
    "iMac18,1": model_s(name: "iMac 21.5-Inch", year: 2017, type: .imac),
    "iMac18,2": model_s(name: "iMac 21.5-Inch", year: 2017, type: .imac),
    "iMac18,3": model_s(name: "iMac 27-Inch", year: 2017, type: .imac),
    "iMac19,1": model_s(name: "iMac 27-Inch", year: 2019, type: .imac),
    "iMac20,1": model_s(name: "iMac 27-Inch", year: 2020, type: .imac),
    "iMac20,2": model_s(name: "iMac 27-Inch", year: 2020, type: .imac),
    "iMac21,1": model_s(name: "iMac 24-Inch (M1)", year: 2021, type: .imac),
    "iMac21,2": model_s(name: "iMac 24-Inch (M1)", year: 2021, type: .imac),
    
    // iMac Pro
    "iMacPro1,1": model_s(name: "iMac Pro", year: 2017, type: .imacpro),
    
    // MacBook
    "MacBook8,1": model_s(name: "MacBook", year: 2015, type: .macbook),
    "MacBook9,1": model_s(name: "MacBook", year: 2016, type: .macbook),
    "MacBook10,1": model_s(name: "MacBook", year: 2017, type: .macbook),
    
    // MacBook Air
    "MacBookAir5,1": model_s(name: "MacBook Air 11\"", year: 2012, type: .macbookAir),
    "MacBookAir5,2": model_s(name: "MacBook Air 13\"", year: 2012, type: .macbookAir),
    "MacBookAir6,1": model_s(name: "MacBook Air 11\"", year: 2014, type: .macbookAir),
    "MacBookAir6,2": model_s(name: "MacBook Air 13\"", year: 2014, type: .macbookAir),
    "MacBookAir7,1": model_s(name: "MacBook Air 11\"", year: 2015, type: .macbookAir),
    "MacBookAir7,2": model_s(name: "MacBook Air 13\"", year: 2015, type: .macbookAir),
    "MacBookAir8,1": model_s(name: "MacBook Air 13\"", year: 2018, type: .macbookAir),
    "MacBookAir8,2": model_s(name: "MacBook Air 13\"", year: 2019, type: .macbookAir),
    "MacBookAir9,1": model_s(name: "MacBook Air 13\"", year: 2020, type: .macbookAir),
    "MacBookAir10,1": model_s(name: "MacBook Air 13\" (M1)", year: 2020, type: .macbookAir),
    "Mac14,2": model_s(name: "MacBook Air 13\" (M2)", year: 2022, type: .macbookAir),
    
    // MacBook Pro
    "MacBookPro9,1": model_s(name: "MacBook Pro 15\"", year: 2012, type: .macbookPro),
    "MacBookPro9,2": model_s(name: "MacBook Pro 13\"", year: 2012, type: .macbookPro),
    "MacBookPro10,1": model_s(name: "MacBook Pro 15\"", year: 2012, type: .macbookPro),
    "MacBookPro10,2": model_s(name: "MacBook Pro 13\"", year: 2012, type: .macbookPro),
    "MacBookPro11,1": model_s(name: "MacBook Pro 13\"", year: 2014, type: .macbookPro),
    "MacBookPro11,2": model_s(name: "MacBook Pro 15\"", year: 2014, type: .macbookPro),
    "MacBookPro11,3": model_s(name: "MacBook Pro 15\"", year: 2014, type: .macbookPro),
    "MacBookPro11,4": model_s(name: "MacBook Pro 15\"", year: 2015, type: .macbookPro),
    "MacBookPro11,5": model_s(name: "MacBook Pro 15\"", year: 2015, type: .macbookPro),
    "MacBookPro12,1": model_s(name: "MacBook Pro 13\"", year: 2015, type: .macbookPro),
    "MacBookPro13,1": model_s(name: "MacBook Pro 13\"", year: 2016, type: .macbookPro),
    "MacBookPro13,2": model_s(name: "MacBook Pro 13\"", year: 2016, type: .macbookPro),
    "MacBookPro13,3": model_s(name: "MacBook Pro 15\"", year: 2016, type: .macbookPro),
    "MacBookPro14,1": model_s(name: "MacBook Pro 13\"", year: 2017, type: .macbookPro),
    "MacBookPro14,2": model_s(name: "MacBook Pro 13\"", year: 2017, type: .macbookPro),
    "MacBookPro14,3": model_s(name: "MacBook Pro 15\"", year: 2017, type: .macbookPro),
    "MacBookPro15,1": model_s(name: "MacBook Pro 15\"", year: 2018, type: .macbookPro),
    "MacBookPro15,2": model_s(name: "MacBook Pro 13\"", year: 2019, type: .macbookPro),
    "MacBookPro15,3": model_s(name: "MacBook Pro 15\"", year: 2019, type: .macbookPro),
    "MacBookPro15,4": model_s(name: "MacBook Pro 13\"", year: 2019, type: .macbookPro),
    "MacBookPro16,1": model_s(name: "MacBook Pro 16\"", year: 2019, type: .macbookPro),
    "MacBookPro16,2": model_s(name: "MacBook Pro 13\"", year: 2019, type: .macbookPro),
    "MacBookPro16,3": model_s(name: "MacBook Pro 13\"", year: 2020, type: .macbookPro),
    "MacBookPro17,1": model_s(name: "MacBook Pro 13\" (M1)", year: 2020, type: .macbookPro),
    "MacBookPro18,1": model_s(name: "MacBook Pro 16\" (M1 Pro)", year: 2021, type: .macbookPro),
    "MacBookPro18,2": model_s(name: "MacBook Pro 16\" (M1 Max)", year: 2021, type: .macbookPro),
    "MacBookPro18,3": model_s(name: "MacBook Pro 14\" (M1 Pro)", year: 2021, type: .macbookPro),
    "MacBookPro18,4": model_s(name: "MacBook Pro 14\" (M1 Max)", year: 2021, type: .macbookPro),
    "Mac14,7": model_s(name: "MacBook Pro 13\" (M2)", year: 2022, type: .macbookPro)
]

let osDict: [String: String] = [
    "10.13": "High Sierra",
    "10.14": "Mojave",
    "10.15": "Catalina",
    "11": "Big Sur",
    "12": "Monterey",
    "13": "Ventura"
]
