//
//  main.swift
//  SMC
//
//  Created by Serhiy Mytrovtsiy on 25/05/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

enum CMDType: String {
    case list
    case set
    case fan
    case fans
    case unlock
    case lock
    case ftstStatus
    case help
    case unknown
    
    init(value: String) {
        switch value {
        case "list": self = .list
        case "set": self = .set
        case "fan": self = .fan
        case "fans": self = .fans
        case "unlock": self = .unlock
        case "lock": self = .lock
        case "ftst": self = .ftstStatus
        case "help": self = .help
        default: self = .unknown
        }
    }
}

enum FlagsType: String {
    case temperature = "T"
    case voltage = "V"
    case power = "P"
    case fans = "F"
    case all
    
    init(value: String) {
        switch value {
        case "-t": self = .temperature
        case "-v": self = .voltage
        case "-p": self = .power
        case "-f": self = .fans
        default: self = .all
        }
    }
}

func main() {
    var args = CommandLine.arguments.dropFirst()
    let cmd = CMDType(value: args.first ?? "")
    args = args.dropFirst()
    
    switch cmd {
    case .list:
        var keys = SMC.shared.getAllKeys()
        args.forEach { (arg: String) in
            let flag = FlagsType(value: arg)
            if flag != .all {
                keys = keys.filter{ $0.hasPrefix(flag.rawValue)}
            }
        }
        
        print("[INFO]: found \(keys.count) keys\n")
        
        keys.forEach { (key: String) in
            let value = SMC.shared.getValue(key)
            print("[\(key)]    ", value ?? 0)
        }
    case .set:
        guard let keyIndex = args.firstIndex(where: { $0 == "-k" }),
              let valueIndex = args.firstIndex(where: { $0 == "-v" }),
              args.indices.contains(keyIndex+1),
              args.indices.contains(valueIndex+1) else {
            return
        }
        
        let key = args[keyIndex+1]
        if key.count != 4 {
            print("[ERROR]: key must contain 4 characters!")
            return
        }
        
        guard let value = Int(args[valueIndex+1]) else {
            print("[ERROR]: wrong value passed!")
            return
        }
        
        let result = SMC.shared.write(key, value)
        if result != kIOReturnSuccess {
            print("[ERROR]: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        print("[INFO]: set \(value) on \(key)")
    case .fan:
        guard let idString = args.first, let id = Int(idString) else {
            print("[ERROR]: missing fan id")
            return
        }
        var help: Bool = true
        let needsUnlock = SMC.shared.isAppleSilicon
        var didUnlock = false
        
        // Auto-unlock for Apple Silicon when writing speed
        if needsUnlock && args.contains("-v") {
            let currentFtst = SMC.shared.getFtstValue() ?? 0
            if currentFtst == 0 {
                print("[INFO] Apple Silicon detected, unlocking Ftst...")
                let unlockResult = SMC.shared.setFtstUnlock()
                if unlockResult != kIOReturnSuccess {
                    print("[ERROR] Ftst unlock failed: \(unlockResult)")
                    // Continue anyway, write might still work
                } else {
                    didUnlock = true
                    // Wait for mode transition
                    print("[INFO] Waiting for mode transition...")
                    if SMC.shared.waitForModeTransition(timeout: 5.0) {
                        print("[INFO] Mode transition complete")
                    } else {
                        print("[WARNING] Mode transition timeout")
                    }
                }
            }
        }
        
        // Note: Don't auto-reset Ftst here - let it stay unlocked for continuous control
        // The helper daemon handles Ftst lifecycle (inactivity timeout, orphan detection)
        
        if let index = args.firstIndex(where: { $0 == "-v" }), args.indices.contains(index+1), let value = Int(args[index+1]) {
            // Use safe method with min/max enforcement
            let minSpeed = Int(SMC.shared.getValue("F\(id)Mn") ?? 1000)
            let maxSpeed = Int(SMC.shared.getValue("F\(id)Mx") ?? 6000)
            
            // Safety checks
            if value <= 0 {
                print("[ERROR] Zero or negative RPM not allowed for safety")
                return
            }
            
            var safeValue = value
            if value < minSpeed {
                print("[WARNING] RPM \(value) below minimum \(minSpeed), using minimum")
                safeValue = minSpeed
            }
            if value > maxSpeed {
                print("[WARNING] RPM \(value) above maximum \(maxSpeed), using maximum")
                safeValue = maxSpeed
            }
            
            SMC.shared.setFanSpeed(id, speed: safeValue)
            print("[INFO] Set fan \(id) speed to \(safeValue) RPM")
            help = false
        }
        
        if let index = args.firstIndex(where: { $0 == "-m" }), args.indices.contains(index+1),
           let raw = Int(args[index+1]), let mode = FanMode.init(rawValue: raw) {
            SMC.shared.setFanMode(id, mode: mode)
            print("[INFO] Set fan \(id) mode to \(mode.description)")
            help = false
        }
        
        guard help else { return }
        
        print("Available Flags:")
        print("  -m    change the fan mode: 0 - automatic, 1 - manual")
        print("  -v    change the fan speed")
        print("")
        print("Note: On Apple Silicon, Ftst unlock is handled automatically")
    case .fans:
        guard let count = SMC.shared.getValue("FNum") else {
            print("FNum not found")
            return
        }
        print("Number of fans: \(count)\n")
        
        for i in 0..<Int(count) {
            print("\(i): \(SMC.shared.getStringValue("F\(i)ID") ?? "Fan #\(i)")")
            print("Actual speed:", SMC.shared.getValue("F\(i)Ac") ?? -1)
            print("Minimal speed:", SMC.shared.getValue("F\(i)Mn") ?? -1)
            print("Maximum speed:", SMC.shared.getValue("F\(i)Mx") ?? -1)
            print("Target speed:", SMC.shared.getValue("F\(i)Tg") ?? -1)
            print("Mode:", FanMode(rawValue: Int(SMC.shared.getValue("F\(i)Md") ?? -1)) ?? .forced)
            
            print()
        }
    case .unlock:
        if !SMC.shared.isAppleSilicon {
            print("[INFO] Not Apple Silicon - Ftst unlock not needed")
            return
        }
        
        let currentFtst = SMC.shared.getFtstValue()
        print("[INFO] Current Ftst value: \(currentFtst ?? 255)")
        
        if currentFtst == 1 {
            print("[INFO] Ftst already unlocked")
            return
        }
        
        let result = SMC.shared.setFtstUnlock()
        if result == kIOReturnSuccess {
            print("[INFO] Ftst unlock: success")
            
            // Wait for and report mode transition
            print("[INFO] Waiting for mode transition...")
            if SMC.shared.waitForModeTransition(timeout: 10.0) {
                let mode = SMC.shared.getValue("F0Md") ?? -1
                print("[INFO] Mode transition complete (F0Md = \(Int(mode)))")
            } else {
                print("[WARNING] Mode transition timeout")
            }
        } else {
            print("[ERROR] Ftst unlock failed: \(result)")
            exit(1)
        }
        
    case .lock:
        if !SMC.shared.isAppleSilicon {
            print("[INFO] Not Apple Silicon - Ftst lock not needed")
            return
        }
        
        let result = SMC.shared.setFtstLock()
        if result == kIOReturnSuccess {
            print("[INFO] Ftst lock: success")
            
            // Report final mode
            usleep(500_000) // Wait 500ms for mode to update
            let mode = SMC.shared.getValue("F0Md") ?? -1
            print("[INFO] F0Md = \(Int(mode))")
        } else {
            print("[ERROR] Ftst lock failed: \(result)")
            exit(1)
        }
        
    case .ftstStatus:
        print("Ftst Status:")
        print("  Apple Silicon: \(SMC.shared.isAppleSilicon)")
        print("  Ftst key exists: \(SMC.shared.hasFtstKey())")
        
        if let ftst = SMC.shared.getFtstValue() {
            print("  Ftst value: \(ftst) (\(ftst == 1 ? "unlocked" : "locked"))")
        } else {
            print("  Ftst value: N/A")
        }
        
        if let mode = SMC.shared.getValue("F0Md") {
            let modeInt = Int(mode)
            let modeDesc: String
            switch modeInt {
            case 0: modeDesc = "automatic"
            case 1: modeDesc = "manual"
            case 3: modeDesc = "system (thermalmonitord)"
            default: modeDesc = "unknown"
            }
            print("  F0Md: \(modeInt) (\(modeDesc))")
        }
        
    case .help, .unknown:
        print("SMC tool\n")
        print("Usage:")
        print("  ./smc [command]\n")
        print("Available Commands:")
        print("  list     list keys and values")
        print("  set      set value to a key")
        print("  fan      set fan speed/mode (auto-handles Ftst on Apple Silicon)")
        print("  fans     list of fans")
        print("  unlock   unlock Ftst for Apple Silicon fan control")
        print("  lock     lock Ftst to restore automatic control")
        print("  ftst     show Ftst status")
        print("  help     help menu\n")
        print("Available Flags:")
        print("  -t    list temperature sensors")
        print("  -v    list voltage sensors (list cmd) / value (set cmd)")
        print("  -p    list power sensors")
        print("  -f    list fans\n")
        print("Apple Silicon Notes:")
        print("  Fan control on M1/M2/M3/M4 requires Ftst unlock.")
        print("  The 'fan' command handles this automatically.")
        print("  Use 'unlock' and 'lock' for manual control.\n")
    }
}

main()
