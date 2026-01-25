//
//  smc.swift
//  SMC
//
//  Created by Serhiy Mytrovtsiy on 25/05/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import IOKit

internal enum SMCDataType: String {
    case UI8 = "ui8 "
    case UI16 = "ui16"
    case UI32 = "ui32"
    case SP1E = "sp1e"
    case SP3C = "sp3c"
    case SP4B = "sp4b"
    case SP5A = "sp5a"
    case SPA5 = "spa5"
    case SP69 = "sp69"
    case SP78 = "sp78"
    case SP87 = "sp87"
    case SP96 = "sp96"
    case SPB4 = "spb4"
    case SPF0 = "spf0"
    case FLT = "flt "
    case FPE2 = "fpe2"
    case FP2E = "fp2e"
    case FDS = "{fds"
}

internal enum SMCKeys: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case writeBytes = 6
    case readIndex = 8
    case readKeyInfo = 9
    case readPLimit = 11
    case readVers = 12
}

public enum FanMode: Int, Codable {
    case automatic = 0
    case forced = 1
}

internal struct SMCKeyData_t {
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
        var dataSize: IOByteCount32 = 0
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

internal struct SMCVal_t {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)
    
    init(_ key: String) {
        self.key = key
    }
}

extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
    
    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

extension UInt16 {
    init(bytes: (UInt8, UInt8)) {
        self = UInt16(bytes.0) << 8 | UInt16(bytes.1)
    }
}

extension UInt32 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | UInt32(bytes.2) << 8 | UInt32(bytes.3)
    }
}

extension Int {
    init(fromFPE2 bytes: (UInt8, UInt8)) {
        self = (Int(bytes.0) << 6) + (Int(bytes.1) >> 2)
    }
}

extension Float {
    init?(_ bytes: [UInt8]) {
        self = bytes.withUnsafeBytes {
            return $0.load(fromByteOffset: 0, as: Self.self)
        }
    }
    
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}

public class SMC {
    public static let shared = SMC()
    private var conn: io_connect_t = 0
    
    public init() {
        var result: kern_return_t
        var iterator: io_iterator_t = 0
        let device: io_object_t
        
        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")
        result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator)
        if result != kIOReturnSuccess {
            print("Error IOServiceGetMatchingServices(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        if device == 0 {
            print("Error IOIteratorNext(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        result = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        if result != kIOReturnSuccess {
            print("Error IOServiceOpen(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
    }
    
    deinit {
        let result = self.close()
        if result != kIOReturnSuccess {
            print("error close smc connection: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
    
    public func close() -> kern_return_t {
        return IOServiceClose(conn)
    }
    
    public func getValue(_ key: String) -> Double? {
        var result: kern_return_t = 0
        var val: SMCVal_t = SMCVal_t(key)
        
        result = read(&val)
        if result != kIOReturnSuccess {
            print("Error read(\(key)): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        if val.dataSize > 0 {
            if val.bytes.first(where: { $0 != 0 }) == nil && val.key != "FS! " && val.key != "F0Md" && val.key != "F1Md" {
                return nil
            }
            
            switch val.dataType {
            case SMCDataType.UI8.rawValue:
                return Double(val.bytes[0])
            case SMCDataType.UI16.rawValue:
                return Double(UInt16(bytes: (val.bytes[0], val.bytes[1])))
            case SMCDataType.UI32.rawValue:
                return Double(UInt32(bytes: (val.bytes[0], val.bytes[1], val.bytes[2], val.bytes[3])))
            case SMCDataType.SP1E.rawValue:
                let result: Double = Double(UInt16(val.bytes[0]) * 256 + UInt16(val.bytes[1]))
                return Double(result / 16384)
            case SMCDataType.SP3C.rawValue:
                let result: Double = Double(UInt16(val.bytes[0]) * 256 + UInt16(val.bytes[1]))
                return Double(result / 4096)
            case SMCDataType.SP4B.rawValue:
                let result: Double = Double(UInt16(val.bytes[0]) * 256 + UInt16(val.bytes[1]))
                return Double(result / 2048)
            case SMCDataType.SP5A.rawValue:
                let result: Double = Double(UInt16(val.bytes[0]) * 256 + UInt16(val.bytes[1]))
                return Double(result / 1024)
            case SMCDataType.SP69.rawValue:
                let result: Double = Double(UInt16(val.bytes[0]) * 256 + UInt16(val.bytes[1]))
                return Double(result / 512)
            case SMCDataType.SP78.rawValue:
                let intValue: Double = Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1]))
                return Double(intValue / 256)
            case SMCDataType.SP87.rawValue:
                let intValue: Double = Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1]))
                return Double(intValue / 128)
            case SMCDataType.SP96.rawValue:
                let intValue: Double = Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1]))
                return Double(intValue / 64)
            case SMCDataType.SPA5.rawValue:
                let result: Double = Double(UInt16(val.bytes[0]) * 256 + UInt16(val.bytes[1]))
                return Double(result / 32)
            case SMCDataType.SPB4.rawValue:
                let intValue: Double = Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1]))
                return Double(intValue / 16)
            case SMCDataType.SPF0.rawValue:
                let intValue: Double = Double(Int(val.bytes[0]) * 256 + Int(val.bytes[1]))
                return intValue
            case SMCDataType.FLT.rawValue:
                let value: Float? = Float(val.bytes)
                if value != nil {
                    return Double(value!)
                }
                return nil
            case SMCDataType.FPE2.rawValue:
                return Double(Int(fromFPE2: (val.bytes[0], val.bytes[1])))
            default:
                return nil
            }
        }
        
        return nil
    }
    
    public func getStringValue(_ key: String) -> String? {
        var result: kern_return_t = 0
        var val: SMCVal_t = SMCVal_t(key)
        
        result = read(&val)
        if result != kIOReturnSuccess {
            print("Error read(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        if val.dataSize > 0 {
            if val.bytes.first(where: { $0 != 0}) == nil {
                return nil
            }
            
            switch val.dataType {
            case SMCDataType.FDS.rawValue:
                let c1  = String(UnicodeScalar(val.bytes[4]))
                let c2  = String(UnicodeScalar(val.bytes[5]))
                let c3  = String(UnicodeScalar(val.bytes[6]))
                let c4  = String(UnicodeScalar(val.bytes[7]))
                let c5  = String(UnicodeScalar(val.bytes[8]))
                let c6  = String(UnicodeScalar(val.bytes[9]))
                let c7  = String(UnicodeScalar(val.bytes[10]))
                let c8  = String(UnicodeScalar(val.bytes[11]))
                let c9  = String(UnicodeScalar(val.bytes[12]))
                let c10 = String(UnicodeScalar(val.bytes[13]))
                let c11 = String(UnicodeScalar(val.bytes[14]))
                let c12 = String(UnicodeScalar(val.bytes[15]))
                
                return (c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + c10 + c11 + c12).trimmingCharacters(in: .whitespaces)
            default:
                print("unsupported data type \(val.dataType) for key: \(key)")
                return nil
            }
        }
        
        return nil
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
            
            input.data8 = SMCKeys.readIndex.rawValue
            input.data32 = UInt32(i)
            
            result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
            if result != kIOReturnSuccess {
                continue
            }
            
            list.append(output.key.toString())
        }
        
        return list
    }
    
    public func write(_ key: String, _ newValue: Int) -> kern_return_t {
        var value = SMCVal_t(key)
        value.dataSize = 2
        value.bytes = [UInt8(newValue >> 6), UInt8((newValue << 2) ^ ((newValue >> 6) << 8)), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0)]
        
        return write(value)
    }
    
    // MARK: - fans
    
    public func setFanMode(_ id: Int, mode: FanMode) {
        print("[setFanMode] fan \(id) -> \(mode == .forced ? "manual" : "automatic")")
        
        #if arch(arm64)
        // Apple Silicon: unlock before setting manual mode
        if mode == .forced {
            if !unlockFanControl(fanId: id) {
                print("[fan \(id)] FAILED to unlock fan control")
                return
            }
            print("[fan \(id)] successfully set to manual mode")
        } else {
            // Setting to automatic
            let otherFansManual = countManualFans(excluding: id)
            let modeKey = "F\(id)Md"
            let targetKey = "F\(id)Tg"

            var result: kern_return_t = 0
            
            // Set mode to 0 (automatic)
            if self.getValue(modeKey) != nil {
                var value = SMCVal_t(modeKey)
                
                result = read(&value)
                guard result == kIOReturnSuccess else {
                    print(smcError("read", key: modeKey, result: result))
                    return
                }
                
                let prevMode = value.bytes[0]
                if prevMode == 0 {
                    print("[\(modeKey)] already in automatic mode")
                } else {
                    value.bytes[0] = 0
                    if !writeWithRetry(value, context: "mode \(prevMode)->0") {
                        return
                    }
                }
            }
            
            // Set target to 0 (Apple Silicon uses flt IEEE 754 float format)
            var targetValue = SMCVal_t(targetKey)
            
            result = read(&targetValue)
            guard result == kIOReturnSuccess else {
                print(smcError("read", key: targetKey, result: result))
                return
            }
            
            let bytes = Float(0).bytes
            targetValue.bytes[0] = bytes[0]
            targetValue.bytes[1] = bytes[1]
            targetValue.bytes[2] = bytes[2]
            targetValue.bytes[3] = bytes[3]
            
            if !writeWithRetry(targetValue, context: "write target=0") {
                return
            }
            
            if otherFansManual == 0 {
                if resetFanControl() {
                    print("[fan \(id)] last manual fan, Ftst reset, thermalmonitord has control")
                } else {
                    print("[fan \(id)] last manual fan, but Ftst reset FAILED")
                }
            } else {
                print("[fan \(id)] set to automatic, \(otherFansManual) other fan(s) still manual")
            }
        }
        #else
        // Intel
        if self.getValue("F\(id)Md") != nil {
            var result: kern_return_t = 0
            var value = SMCVal_t("F\(id)Md")
            
            result = read(&value)
            if result != kIOReturnSuccess {
                print("Error read fan mode: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
                return
            }
            
            value.bytes = [UInt8(mode.rawValue), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                   UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                   UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                   UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                   UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                   UInt8(0), UInt8(0)]
            
            result = write(value)
            if result != kIOReturnSuccess {
                print("Error write: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
                return
            }
        }
        
        let fansMode = Int(self.getValue("FS! ") ?? 0)
        var newMode: UInt8 = 0
        
        if fansMode == 0 && id == 0 && mode == .forced {
            newMode = 1
        } else if fansMode == 0 && id == 1 && mode == .forced {
            newMode = 2
        } else if fansMode == 1 && id == 0 && mode == .automatic {
            newMode = 0
        } else if fansMode == 1 && id == 1 && mode == .forced {
            newMode = 3
        } else if fansMode == 2 && id == 1 && mode == .automatic {
            newMode = 0
        } else if fansMode == 2 && id == 0 && mode == .forced {
            newMode = 3
        } else if fansMode == 3 && id == 0 && mode == .automatic {
            newMode = 2
        } else if fansMode == 3 && id == 1 && mode == .automatic {
            newMode = 1
        }
        
        if fansMode == newMode {
            return
        }
        
        var result: kern_return_t = 0
        var value = SMCVal_t("FS! ")
        
        result = read(&value)
        if result != kIOReturnSuccess {
            print("Error read fan mode: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        value.bytes = [0, newMode, UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                       UInt8(0), UInt8(0)]
        
        result = write(value)
        if result != kIOReturnSuccess {
            print("Error write: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        #endif
    }
    
    public func setFanSpeed(_ id: Int, speed: Int) {
        print("[setFanSpeed] fan \(id) -> \(speed) RPM")
        
        // Enforce recommended max as safety limit
        if let maxSpeed = self.getValue("F\(id)Mx"), speed > Int(maxSpeed) {
            print("[fan \(id)] speed \(speed) exceeds max \(Int(maxSpeed)), clamping")
            return setFanSpeed(id, speed: Int(maxSpeed))
        }
        
        #if arch(arm64)
        // Apple Silicon: ensure fan is in manual mode before setting speed
        var modeVal = SMCVal_t("F\(id)Md")
        let modeResult = read(&modeVal)
        guard modeResult == kIOReturnSuccess else {
            print("Error read fan mode: " + (String(cString: mach_error_string(modeResult), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        if modeVal.bytes[0] != 1 {
            if !unlockFanControl(fanId: id) {
                print("Error: Failed to unlock fan \(id) for speed change")
                return
            }
        }
        #endif
        
        var result: kern_return_t = 0
        var value = SMCVal_t("F\(id)Tg")
        
        result = read(&value)
        if result != kIOReturnSuccess {
            print("Error read fan value: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        if value.dataType == "flt " {
            let bytes = Float(speed).bytes
            value.bytes[0] = bytes[0]
            value.bytes[1] = bytes[1]
            value.bytes[2] = bytes[2]
            value.bytes[3] = bytes[3]
        } else if value.dataType == "fpe2" {
            value.bytes[0] = UInt8(speed >> 6)
            value.bytes[1] = UInt8((speed << 2) ^ ((speed >> 6) << 8))
            value.bytes[2] = UInt8(0)
            value.bytes[3] = UInt8(0)
        }
        
        #if arch(arm64)
        if !writeWithRetry(value, context: "set speed to \(speed)") {
            return
        }
        #else
        result = write(value)
        if result != kIOReturnSuccess {
            print("Error write: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        #endif
    }
    
    public func resetFans() {
        var value = SMCVal_t("FS! ")
        value.dataSize = 2
        
        let result = write(value)
        if result != kIOReturnSuccess {
            print("Error write: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }
    
    // MARK: - Apple Silicon Fan Control
    
    #if arch(arm64)
    /// Format SMC error for logging with context
    private func smcError(_ operation: String, key: String, result: kern_return_t) -> String {
        let errorDesc = String(cString: mach_error_string(result), encoding: .ascii)
            ?? "unknown error"
        return "[\(key)] \(operation) failed: \(errorDesc) (0x\(String(result, radix: 16)))"
    }
    
    /// Write an SMC value with retry logic for thermalmonitord contention
    /// - Parameters:
    ///   - value: The SMC value to write
    ///   - maxAttempts: Maximum retry attempts (default 10)
    ///   - delayMicros: Delay between retries in microseconds (default 50ms)
    ///   - context: Description for logging
    /// - Returns: Success or failure
    private func writeWithRetry(
        _ value: SMCVal_t,
        maxAttempts: Int = 10,
        delayMicros: UInt32 = 50_000,
        context: String
    ) -> Bool {
        var mutableValue = value
        for attempt in 0..<maxAttempts {
            let result = write(mutableValue)
            if result == kIOReturnSuccess {
                if attempt > 0 {
                    print("[\(value.key)] \(context) succeeded after \(attempt + 1) attempts")
                } else {
                    print("[\(value.key)] \(context) succeeded")
                }
                return true
            }
            if attempt < maxAttempts - 1 {
                usleep(delayMicros)
            }
        }
        print("[\(value.key)] \(context) failed after \(maxAttempts) attempts")
        return false
    }
    
    /// Unlock fan control for Apple Silicon by writing Ftst=1
    /// This prevents thermalmonitord from overriding manual fan settings
    private func unlockFanControl(fanId: Int) -> Bool {
        var ftstCheck = SMCVal_t("Ftst")
        var result = read(&ftstCheck)
        guard result == kIOReturnSuccess else {
            print(smcError("read", key: "Ftst", result: result))
            return false
        }
        let alreadyUnlocked = ftstCheck.bytes[0] == 1
        print("[Ftst] current value: \(ftstCheck.bytes[0]), alreadyUnlocked: \(alreadyUnlocked)")
        
        if !alreadyUnlocked {
            var ftstVal = SMCVal_t("Ftst")
            result = read(&ftstVal)
            guard result == kIOReturnSuccess else {
                print(smcError("read", key: "Ftst", result: result))
                return false
            }
            ftstVal.bytes[0] = 1
            if !writeWithRetry(ftstVal, context: "unlock (set to 1)") {
                return false
            }
        }
        
        // Retry writing mode=1 until thermalmonitord releases control
        let modeKey = "F\(fanId)Md"
        var modeVal = SMCVal_t(modeKey)
        guard read(&modeVal) == kIOReturnSuccess else {
            print(smcError("read", key: modeKey, result: result))
            return false
        }
        modeVal.bytes[0] = 1
        
        let maxAttempts = alreadyUnlocked ? 10 : 100
        let delayMicros: UInt32 = alreadyUnlocked ? 10_000 : 50_000
        
        if writeWithRetry(modeVal, maxAttempts: maxAttempts, delayMicros: delayMicros,
                          context: "set fan \(fanId) to manual mode") {
            return true
        }
        print("[F\(fanId)Md] timeout setting fan to manual mode")
        return false
    }
    
    /// Reset Ftst to 0, returning control to thermalmonitord
    /// - Returns: true if successfully reset, false otherwise
    private func resetFanControl() -> Bool {
        var value = SMCVal_t("Ftst")
        let readResult = read(&value)
        guard readResult == kIOReturnSuccess else {
            print(smcError("read", key: "Ftst", result: readResult))
            return false
        }
        
        let currentValue = value.bytes[0]
        print("[Ftst] current value before reset: \(currentValue)")
        
        if currentValue == 0 {
            print("[Ftst] already 0, skipping write")
            return true
        }
        
        value.bytes[0] = 0
        return writeWithRetry(value, maxAttempts: 10, delayMicros: 50_000,
                              context: "reset to 0 (return control to thermalmonitord)")
    }
    
    /// Check how many fans are currently in manual mode
    /// - Parameter excluding: Optional fan ID to exclude from count (for checking OTHER fans)
    private func countManualFans(excluding fanId: Int? = nil) -> Int {
        guard let fanCount = getValue("FNum") else {
            print("[FNum] failed to read fan count")
            return 0
        }
        var count = 0
        for i in 0..<Int(fanCount) {
            if let exclude = fanId, i == exclude { continue }
            var modeVal = SMCVal_t("F\(i)Md")
            if read(&modeVal) == kIOReturnSuccess {
                if modeVal.bytes[0] == 1 {
                    count += 1
                }
            }
        }
        print("[countManualFans] excluding fan \(fanId ?? -1): \(count) fans in manual mode")
        return count
    }
    #endif
    
    // MARK: - internal functions
    
    private func read(_ value: UnsafeMutablePointer<SMCVal_t>) -> kern_return_t {
        var result: kern_return_t = 0
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()
        
        input.key = FourCharCode(fromString: value.pointee.key)
        input.data8 = SMCKeys.readKeyInfo.rawValue
        
        result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess {
            return result
        }
        
        value.pointee.dataSize = UInt32(output.keyInfo.dataSize)
        value.pointee.dataType = output.keyInfo.dataType.toString()
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKeys.readBytes.rawValue
        
        result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess {
            return result
        }
        
        memcpy(&value.pointee.bytes, &output.bytes, Int(value.pointee.dataSize))
        
        return kIOReturnSuccess
    }
    
    private func write(_ value: SMCVal_t) -> kern_return_t {
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()
        
        input.key = FourCharCode(fromString: value.key)
        input.data8 = SMCKeys.writeBytes.rawValue
        input.keyInfo.dataSize = IOByteCount32(value.dataSize)
        input.bytes = (value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3], value.bytes[4], value.bytes[5],
                       value.bytes[6], value.bytes[7], value.bytes[8], value.bytes[9], value.bytes[10], value.bytes[11],
                       value.bytes[12], value.bytes[13], value.bytes[14], value.bytes[15], value.bytes[16], value.bytes[17],
                       value.bytes[18], value.bytes[19], value.bytes[20], value.bytes[21], value.bytes[22], value.bytes[23],
                       value.bytes[24], value.bytes[25], value.bytes[26], value.bytes[27], value.bytes[28], value.bytes[29],
                       value.bytes[30], value.bytes[31])
        
        let result = self.call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess {
            return result
        }
        
        // IOKit can return kIOReturnSuccess but SMC firmware may still reject the write.
        // Check SMC-level result code (0x00 = success, non-zero = error)
        if output.result != 0x00 {
            return kIOReturnError
        }
        
        return kIOReturnSuccess
    }
    
    private func call(_ index: UInt8, input: inout SMCKeyData_t, output: inout SMCKeyData_t) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData_t>.stride
        var outputSize = MemoryLayout<SMCKeyData_t>.stride
        
        return IOConnectCallStructMethod(conn, UInt32(index), &input, inputSize, &output, &outputSize)
    }
}
