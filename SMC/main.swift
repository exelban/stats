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
              args.indices.contains(valueIndex+1) else{
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
    case .help, .unknown:
        print("SMC tool\n")
        print("Usage:")
        print("  ./smc [command]\n")
        print("Available Commands:")
        print("  list    list keys and values")
        print("  set     set value to a key")
        print("  help    help menu\n")
        print("Available Flags:")
        print("  -t    list temperature sensors")
        print("  -v    list voltage sensors (list cmd) / value (set cmd)")
        print("  -p    list power sensors")
        print("  -f    list fans\n")
    }
}

main()
