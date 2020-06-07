//
//  SMC.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 05/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import IOKit

enum SMCDataType: String {
    case UI32 = "ui32"
    case SP78 = "sp78"
    case SP87 = "sp87"
    case FLT = "flt "
    case FPE2 = "fpe2"
    case FP2E = "fp2e"
}

enum SMCKeys: UInt8 {
    case KERNEL_INDEX = 2
    case READ_BYTES = 5
    case WRITE_BYTES = 6
    case READ_INDEX = 8
    case READ_KEYINFO = 9
    case READ_PLIMIT = 11
    case READ_VERS = 12
}

struct SMCKeyData_t {
    typealias SMCBytes_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8)
    
    struct vers_t {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct LimitData_t {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct keyInfo_t {
        var dataSize: IOByteCount = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
    
    var key: UInt32 = 0
    var vers = vers_t()
    var pLimitData = LimitData_t()
    var keyInfo = keyInfo_t()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    
    var bytes: SMCBytes_t = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0))
}

struct SMCVal_t {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)
    
    init(_ key: String) {
        self.key = key
    }
}

public class SMCService {
    private var conn: io_connect_t = 0;
    
    public init() {
        var result: kern_return_t
        var iterator: io_iterator_t = 0
        let device: io_object_t

        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")
        result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator)
        if (result != kIOReturnSuccess) {
            print("Error IOServiceGetMatchingServices(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }

        device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        if (device == 0) {
            print("Error IOIteratorNext(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }

        result = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        if (result != kIOReturnSuccess) {
            print("Error IOServiceOpen(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
    }
    
    public func close() -> kern_return_t{
        return IOServiceClose(conn)
    }
    
    public func getValue(_ key: String) -> Double? {
        var result: kern_return_t = 0
        var val: SMCVal_t = SMCVal_t(key)
        
        result = read(&val)
        if result != kIOReturnSuccess {
            print("Error read(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        if (val.dataSize > 0) {
            if val.bytes.first(where: { $0 != 0}) == nil {
                return nil
            }
            
            switch val.dataType {
            case SMCDataType.UI32.rawValue:
                return Double(UInt32(bytes: (val.bytes[0], val.bytes[1], val.bytes[2], val.bytes[3])))
            case SMCDataType.SP78.rawValue, SMCDataType.SP87.rawValue:
                let intValue: Double = Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1]))
                return Double(intValue / 256.0)
            case SMCDataType.FLT.rawValue:
                let value: Float? = Float(val.bytes)
                if value != nil {
                    return Double(value!)
                }
                return nil
            default:
                print("unsupported data type \(val.dataType) for key: \(key)")
                return nil
            }
        }
        
        return nil
    }
    
    private func read(_ value: UnsafeMutablePointer<SMCVal_t>) -> kern_return_t {
        var result: kern_return_t = 0
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()
        
        input.key = FourCharCode(fromString: value.pointee.key)
        input.data8 = SMCKeys.READ_KEYINFO.rawValue
        
        result = call(SMCKeys.KERNEL_INDEX.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess {
            print("Error call(READ_KEYINFO): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return result
        }
        
        value.pointee.dataSize = output.keyInfo.dataSize
        value.pointee.dataType = output.keyInfo.dataType.toString()
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKeys.READ_BYTES.rawValue
        
        result = call(SMCKeys.KERNEL_INDEX.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess {
            print("Error call(READ_BYTES): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return result
        }
        
        memcpy(&value.pointee.bytes, &output.bytes, Int(value.pointee.dataSize))
        
        return kIOReturnSuccess;
    }
    
    private func call(_ index: UInt8, input: inout SMCKeyData_t, output: inout SMCKeyData_t) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData_t>.stride
        var outputSize = MemoryLayout<SMCKeyData_t>.stride

        return IOConnectCallStructMethod(
            conn,
            UInt32(index),
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }
    
    public func getAllKeys() -> [String] {
        var list: [String] = []
        
        let keysNum: Double? = self.getValue("#KEY")
        if keysNum == nil {
            print("ERROR no keys count found")
            return list
        }
        
        var result: kern_return_t = 0
        var input: SMCKeyData_t = SMCKeyData_t()
        var output: SMCKeyData_t = SMCKeyData_t()
        
        for i in 0...Int(keysNum!) {
            input = SMCKeyData_t()
            output = SMCKeyData_t()
            
            input.data8 = SMCKeys.READ_INDEX.rawValue
            input.data32 = UInt32(i)
            
            result = call(SMCKeys.KERNEL_INDEX.rawValue, input: &input, output: &output)
            if result != kIOReturnSuccess {
                continue
            }
            
            list.append(output.key.toString())
        }
        
        return list
    }
}
