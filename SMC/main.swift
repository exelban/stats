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
    case help
    case unknown
    
    init(value: String) {
        switch value {
        case "list": self = .list
        case "set": self = .set
        case "fan": self = .fan
        case "fans": self = .fans
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
        guard let idIndex = args.firstIndex(where: { $0 == "-id" }),
              args.indices.contains(idIndex+1),
              let id = Int(args[idIndex+1]) else {
            print("[ERROR]: missing id")
            return
        }
        
        if let index = args.firstIndex(where: { $0 == "-v" }), args.indices.contains(index+1), let value = Int(args[index+1]) {
            SMC.shared.setFanSpeed(id, speed: value)
            return
        }
        
        if let index = args.firstIndex(where: { $0 == "-m" }), args.indices.contains(index+1),
           let raw = Int(args[index+1]), let mode = FanMode.init(rawValue: raw) {
            SMC.shared.setFanMode(id, mode: mode)
            return
        }
        
        print("[ERROR]: missing value or mode")
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
    case .help, .unknown:
        print("SMC tool\n")
        print("Usage:")
        print("  ./smc [command]\n")
        print("Available Commands:")
        print("  list     list keys and values")
        print("  set      set value to a key")
        print("  fan      set fan speed")
        print("  fans     list of fans")
        print("  help     help menu\n")
        print("Available Flags:")
        print("  -t    list temperature sensors")
        print("  -v    list voltage sensors (list cmd) / value (set cmd)")
        print("  -p    list power sensors")
        print("  -f    list fans\n")
    }
}

main()
