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

public enum Platform: String, Codable {
    case intel
    
    case m1
    case m1Pro
    case m1Max
    case m1Ultra
    
    case m2
    case m2Pro
    case m2Max
    case m2Ultra
    
    case m3
    case m3Pro
    case m3Max
    case m3Ultra
    
    case m4
    case m4Pro
    case m4Max
    case m4Ultra
    
    public static var apple: [Platform] {
        return [
            .m1, .m1Pro, .m1Max, .m1Ultra,
            .m2, .m2Pro, .m2Max, .m2Ultra,
            .m3, .m3Pro, .m3Max, .m3Ultra,
            .m4, .m4Pro, .m4Max, .m4Ultra
        ]
    }
    
    public static var m1Gen: [Platform] {
        return [.m1, .m1Pro, .m1Max, .m1Ultra]
    }
    public static var m2Gen: [Platform] {
        return [.m2, .m2Pro, .m2Max, .m2Ultra]
    }
    public static var m3Gen: [Platform] {
        return [.m3, .m3Pro, .m3Max, .m3Ultra]
    }
    public static var m4Gen: [Platform] {
        return [.m4, .m4Pro, .m4Max, .m4Ultra]
    }
    
    public static var all: [Platform] {
        return apple + [.intel]
    }
}

public enum deviceType: String {
    case unknown
    case macMini
    case macPro
    case iMac
    case iMacPro
    case macbook
    case macbookAir
    case macbookPro
    case macStudio
    
    public static var all: [deviceType] {
        return [.macMini, .macPro, .iMac, .iMacPro, .macbook, .macbookAir, .macbookPro, .macStudio]
    }
}

public enum coreType: Int {
    case unknown = -1
    case efficiency = 1
    case performance = 2
}

public struct model_s {
    public var id: String = ""
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

public struct core_s {
    public var id: Int32
    public var type: coreType
}

public struct cpu_s {
    public var name: String? = nil
    public var physicalCores: Int8? = nil
    public var logicalCores: Int8? = nil
    public var eCores: Int32? = nil
    public var pCores: Int32? = nil
    public var cores: [core_s]? = nil
    public var eCoreFrequencies: [Int32]? = nil
    public var pCoreFrequencies: [Int32]? = nil
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
    public var frequencies: [Int32]? = nil
}

public struct info_s {
    public var cpu: cpu_s? = nil
    public var ram: ram_s? = nil
    public var gpu: [gpu_s]? = nil
}

public struct device_s {
    public var model: model_s = model_s(name: localizedString("Unknown"), year: Calendar.current.component(.year, from: Date()), type: .unknown)
    public var serialNumber: String? = nil
    public var bootDate: Date? = nil
    
    public var os: os_s? = nil
    public var info: info_s = info_s()
    public var platform: Platform? = nil
}

public class SystemKit {
    public static let shared = SystemKit()
    
    public var device: device_s = device_s()
    
    public init() {
        let (modelID, serialNumber) = self.modelAndSerialNumber()
        if let serialNumber {
            self.device.serialNumber = serialNumber
        }
        if let modelName = modelID ?? self.getModelID(), let model = deviceDict[modelName] {
            self.device.model = model
            self.device.model.id = modelName
            self.device.model.icon = self.getIcon(type: self.device.model.type, year: self.device.model.year)
        } else if let model = self.getModel() {
            self.device.model = model
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
        
        if let name = self.device.info.cpu?.name?.lowercased() {
            if name.contains("intel") {
                self.device.platform = .intel
            } else if name.contains("m1") {
                if name.contains("pro") {
                    self.device.platform = .m1Pro
                } else if name.contains("max") {
                    self.device.platform = .m1Max
                } else if name.contains("ultra") {
                    self.device.platform = .m1Ultra
                } else {
                    self.device.platform = .m1
                }
            } else if name.contains("m2") {
                if name.contains("pro") {
                    self.device.platform = .m2Pro
                } else if name.contains("max") {
                    self.device.platform = .m2Max
                } else if name.contains("ultra") {
                    self.device.platform = .m2Ultra
                } else {
                    self.device.platform = .m2
                }
            } else if name.contains("m3") {
                if name.contains("pro") {
                    self.device.platform = .m3Pro
                } else if name.contains("max") {
                    self.device.platform = .m3Max
                } else if name.contains("ultra") {
                    self.device.platform = .m3Ultra
                } else {
                    self.device.platform = .m3
                }
            } else if name.contains("m4") {
                if name.contains("pro") {
                    self.device.platform = .m4Pro
                } else if name.contains("max") {
                    self.device.platform = .m4Max
                } else if name.contains("ultra") {
                    self.device.platform = .m4Ultra
                } else {
                    self.device.platform = .m4
                }
            }
        }
    }
    
    public func getModelID() -> String? {
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
        var nameChars = [CChar](repeating: 0, count: sizeOfName)
        sysctlbyname("machdep.cpu.brand_string", &nameChars, &sizeOfName, nil, 0)
        var name = String(cString: nameChars)
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
        
        if let cores = getCPUCores() {
            cpu.eCores = cores.0
            cpu.pCores = cores.1
            cpu.cores = cores.2
        }
        if let freq = getFrequencies() {
            cpu.eCoreFrequencies = freq.0
            cpu.pCoreFrequencies = freq.1
        }
        
        return cpu
    }
    
    func getCPUCores() -> (Int32?, Int32?, [core_s])? {
        var iterator: io_iterator_t = io_iterator_t()
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleARMPE"), &iterator)
        if result != kIOReturnSuccess {
            print("Error find AppleARMPE: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        var service: io_registry_entry_t = 1
        var list: [core_s] = []
        var pCores: Int32? = nil
        var eCores: Int32? = nil
        
        while service != 0 {
            service = IOIteratorNext(iterator)
            
            var entry: io_iterator_t = io_iterator_t()
            if IORegistryEntryGetChildIterator(service, kIOServicePlane, &entry) != kIOReturnSuccess {
                continue
            }
            var child: io_registry_entry_t = 1
            while child != 0 {
                child = IOIteratorNext(entry)
                guard child != 0 else {
                    continue
                }
                
                guard let name = getIOName(child),
                      let props = getIOProperties(child) else { continue }
                
                if name.matches("^cpu\\d") {
                    var type: coreType = .unknown
                    
                    if let rawType = props.object(forKey: "cluster-type") as? Data,
                       let typ = String(data: rawType, encoding: .utf8)?.trimmed {
                        switch typ {
                        case "E":
                            type = .efficiency
                        case "P":
                            type = .performance
                        default:
                            type = .unknown
                        }
                    }
                    
                    let rawCPUId = props.object(forKey: "cpu-id") as? Data
                    let id = rawCPUId?.withUnsafeBytes { pointer in
                        return pointer.load(as: Int32.self)
                    }
                    
                    list.append(core_s(id: id ?? -1, type: type))
                } else if name.trimmed == "cpus" {
                    eCores = (props.object(forKey: "e-core-count") as? Data)?.withUnsafeBytes { pointer in
                        return pointer.load(as: Int32.self)
                    }
                    pCores = (props.object(forKey: "p-core-count") as? Data)?.withUnsafeBytes { pointer in
                        return pointer.load(as: Int32.self)
                    }
                }
                
                IOObjectRelease(child)
            }
            IOObjectRelease(entry)
            IOObjectRelease(service)
        }
        IOObjectRelease(iterator)
        
        return (eCores, pCores, list)
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
                        
                        if let freq = getFrequencies() {
                            gpu.frequencies = freq.2
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
    
    private func getFrequencies() -> ([Int32], [Int32], [Int32])? {
        var iterator = io_iterator_t()
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleARMIODevice"), &iterator)
        if result != kIOReturnSuccess {
            print("Error find AppleARMIODevice: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        var eFreq: [Int32] = []
        var pFreq: [Int32] = []
        var gpuFreq: [Int32] = []
        
        while case let child = IOIteratorNext(iterator), child != 0 {
            defer { IOObjectRelease(child) }
            guard let name = getIOName(child), name == "pmgr", let props = getIOProperties(child) else { continue }
            
            if let data = props.value(forKey: "voltage-states1-sram") {
                eFreq = convertCFDataToArr(data as! CFData)
            }
            if let data = props.value(forKey: "voltage-states5-sram") {
                pFreq = convertCFDataToArr(data as! CFData)
            }
            if let data = props.value(forKey: "voltage-states9-sram") {
                gpuFreq = convertCFDataToArr(data as! CFData)
            }
        }
        
        return (eFreq, pFreq, gpuFreq)
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
            if year >= 2024 {
                return NSImage(named: NSImage.Name("macMini2024"))!
            }
            if year >= 2020 && year <= 2023 {
                return NSImage(named: NSImage.Name("macMini2020"))!
            }
            return NSImage(named: NSImage.Name("macMini"))!
        case .macStudio:
            return NSImage(named: NSImage.Name("macStudio"))!
        case .iMacPro:
            return NSImage(named: NSImage.Name("imacPro"))!
        case .macPro:
            switch year {
            case 2019:
                return NSImage(named: NSImage.Name("macPro2019"))!
            default:
                return NSImage(named: NSImage.Name("macPro"))!
            }
        case .iMac:
            return NSImage(named: NSImage.Name("imac"))!
        case .macbook:
            return NSImage(named: NSImage.Name("macbookAir"))!
        case .macbookAir:
            if year >= 2022 {
                return NSImage(named: NSImage.Name("macbookAir"))!
            }
            return NSImage(named: NSImage.Name("macbookAir4thGen"))!
        case .macbookPro:
            if year >= 2021 {
                return NSImage(named: NSImage.Name("macbookPro5thGen"))!
            }
            return NSImage(named: NSImage.Name("macbookPro"))!
        default:
            return NSImage(named: NSImage.Name("imacPro"))!
        }
    }
    
    private func getModel() -> model_s? {
        guard let res = process(path: "/usr/sbin/system_profiler", arguments: ["SPHardwareDataType", "-json"]) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(res.utf8), options: []) as? [String: Any],
               let obj = json["SPHardwareDataType"] as? [[String: Any]], !obj.isEmpty, let val = obj.first,
               let name = val["machine_name"] as? String, let model = val["machine_model"] as? String, let cpu = val["chip_type"] as? String {
                let year = Calendar.current.component(.year, from: Date())
                let type = deviceType.all.first{ $0.rawValue.lowercased() ==  name.lowercased().removingWhitespaces() } ?? .unknown
                return model_s(
                    id: model,
                    name: "\(name) (\(cpu.removedRegexMatches(pattern: "Apple ", replaceWith: "")))",
                    year: year,
                    type: type,
                    icon: self.getIcon(type: type, year: year)
                )
            }
        } catch let err as NSError {
            error("error to parse system_profiler SPHardwareDataType: \(err.localizedDescription)")
            return nil
        }
        
        return nil
    }
}

let deviceDict: [String: model_s] = [
    // Mac Mini
    "Macmini6,1": model_s(name: "Mac mini", year: 2012, type: .macMini),
    "Macmini6,2": model_s(name: "Mac mini", year: 2012, type: .macMini),
    "Macmini7,1": model_s(name: "Mac mini", year: 2014, type: .macMini),
    "Macmini8,1": model_s(name: "Mac mini", year: 2018, type: .macMini),
    "Macmini9,1": model_s(name: "Mac mini (M1)", year: 2020, type: .macMini),
    "Mac14,3": model_s(name: "Mac mini (M2)", year: 2023, type: .macMini),
    "Mac14,12": model_s(name: "Mac mini (M2 Pro)", year: 2023, type: .macMini),
    "Mac16,10": model_s(name: "Mac mini (M4)", year: 2024, type: .macMini),
    "Mac16,11": model_s(name: "Mac mini (M4 Pro)", year: 2024, type: .macMini),
    
    // Mac Studio
    "Mac13,1": model_s(name: "Mac Studio (M1 Max)", year: 2022, type: .macStudio),
    "Mac13,2": model_s(name: "Mac Studio (M1 Ultra)", year: 2022, type: .macStudio),
    "Mac14,13": model_s(name: "Mac Studio (M2 Max)", year: 2023, type: .macStudio),
    "Mac14,14": model_s(name: "Mac Studio (M2 Ultra)", year: 2023, type: .macStudio),
    
    // Mac Pro
    "MacPro5,1": model_s(name: "Mac Pro", year: 2010, type: .macPro),
    "MacPro6,1": model_s(name: "Mac Pro", year: 2016, type: .macPro),
    "MacPro7,1": model_s(name: "Mac Pro", year: 2019, type: .macPro),
    "Mac14,8": model_s(name: "Mac Pro (M2 Ultra)", year: 2023, type: .macPro),
    
    // iMac
    "iMac12,1": model_s(name: "iMac 27-Inch", year: 2011, type: .iMac),
    "iMac13,1": model_s(name: "iMac 21.5-Inch", year: 2012, type: .iMac),
    "iMac13,2": model_s(name: "iMac 27-Inch", year: 2012, type: .iMac),
    "iMac14,2": model_s(name: "iMac 27-Inch", year: 2013, type: .iMac),
    "iMac15,1": model_s(name: "iMac 27-Inch", year: 2014, type: .iMac),
    "iMac17,1": model_s(name: "iMac 27-Inch", year: 2015, type: .iMac),
    "iMac18,1": model_s(name: "iMac 21.5-Inch", year: 2017, type: .iMac),
    "iMac18,2": model_s(name: "iMac 21.5-Inch", year: 2017, type: .iMac),
    "iMac18,3": model_s(name: "iMac 27-Inch", year: 2017, type: .iMac),
    "iMac19,1": model_s(name: "iMac 27-Inch", year: 2019, type: .iMac),
    "iMac20,1": model_s(name: "iMac 27-Inch", year: 2020, type: .iMac),
    "iMac20,2": model_s(name: "iMac 27-Inch", year: 2020, type: .iMac),
    "iMac21,1": model_s(name: "iMac 24-Inch (M1)", year: 2021, type: .iMac),
    "iMac21,2": model_s(name: "iMac 24-Inch (M1)", year: 2021, type: .iMac),
    "Mac15,4": model_s(name: "iMac 24-Inch (M3, 8 CPU/8 GPU)", year: 2023, type: .iMac),
    "Mac15,5": model_s(name: "iMac 24-Inch (M3, 8 CPU/10 GPU)", year: 2023, type: .iMac),
    "Mac16,2": model_s(name: "iMac 24-Inch (M4, 8 CPU/8 GPU)", year: 2024, type: .iMac),
    "Mac16,3": model_s(name: "iMac 24-Inch (M4, 10 CPU/10 GPU)", year: 2024, type: .iMac),
    
    // iMac Pro
    "iMacPro1,1": model_s(name: "iMac Pro", year: 2017, type: .iMacPro),
    
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
    "Mac14,15": model_s(name: "MacBook Air 15\" (M2)", year: 2022, type: .macbookAir),
    
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
    "MacBookPro16,4": model_s(name: "MacBook Pro 16\"", year: 2019, type: .macbookPro),
    "MacBookPro17,1": model_s(name: "MacBook Pro 13\" (M1)", year: 2020, type: .macbookPro),
    "MacBookPro18,1": model_s(name: "MacBook Pro 16\" (M1 Pro)", year: 2021, type: .macbookPro),
    "MacBookPro18,2": model_s(name: "MacBook Pro 16\" (M1 Max)", year: 2021, type: .macbookPro),
    "MacBookPro18,3": model_s(name: "MacBook Pro 14\" (M1 Pro)", year: 2021, type: .macbookPro),
    "MacBookPro18,4": model_s(name: "MacBook Pro 14\" (M1 Max)", year: 2021, type: .macbookPro),
    "Mac14,7": model_s(name: "MacBook Pro 13\" (M2)", year: 2022, type: .macbookPro),
    "Mac14,5": model_s(name: "MacBook Pro 14\" (M2 Max)", year: 2023, type: .macbookPro),
    "Mac14,6": model_s(name: "MacBook Pro 16\" (M2 Max)", year: 2023, type: .macbookPro),
    "Mac14,9": model_s(name: "MacBook Pro 14\" (M2 Pro)", year: 2023, type: .macbookPro),
    "Mac14,10": model_s(name: "MacBook Pro 16\" (M2 Pro)", year: 2023, type: .macbookPro),
    "Mac15,3": model_s(name: "MacBook Pro 14\" (M3, 8 CPU/10 GPU)", year: 2023, type: .macbookPro),
    "Mac15,6": model_s(name: "MacBook Pro 14\" (M3 Pro)", year: 2023, type: .macbookPro),
    "Mac15,7": model_s(name: "MacBook Pro 16\" (M3 Pro, 12 CPU/18 GPU)", year: 2023, type: .macbookPro),
    "Mac15,8": model_s(name: "MacBook Pro 14\" (M3 Max, 16 CPU/40 GPU)", year: 2023, type: .macbookPro),
    "Mac15,9": model_s(name: "MacBook Pro 16\" (M3 Max, 16 CPU/40 GPU)", year: 2023, type: .macbookPro),
    "Mac15,10": model_s(name: "MacBook Pro 14\" (M3 Max, 14 CPU/30 GPU)", year: 2023, type: .macbookPro),
    "Mac16,1": model_s(name: "MacBook Pro 14\" (M4, 10 CPU/10 GPU)", year: 2024, type: .macbookPro),
    "Mac16,5": model_s(name: "MacBook Pro 16\" (M4 Max)", year: 2024, type: .macbookPro),
    "Mac16,6": model_s(name: "MacBook Pro 14\" (M4 Max, 16 CPU/40 GPU)", year: 2024, type: .macbookPro),
    "Mac16,7": model_s(name: "MacBook Pro 16\" (M4 Pro, 14 CPU/20 GPU)", year: 2024, type: .macbookPro),
    "Mac16,8": model_s(name: "MacBook Pro 16\" (M4 Pro)", year: 2024, type: .macbookPro)
]

let osDict: [String: String] = [
    "10.13": "High Sierra",
    "10.14": "Mojave",
    "10.15": "Catalina",
    "11": "Big Sur",
    "12": "Monterey",
    "13": "Ventura",
    "14": "Sonoma",
    "15": "Sequoia"
]
