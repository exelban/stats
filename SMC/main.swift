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
    let args = CommandLine.arguments.dropFirst()
    let cmd = CMDType(value: args.first ?? "")
    
    switch cmd {
    case .list:
        var keys = SMC.shared.getAllKeys()
        args.dropFirst().forEach { (arg: String) in
            let flag = FlagsType(value: arg)
            if flag != .all {
                keys = keys.filter{ $0.hasPrefix(flag.rawValue)}
            }
        }
        
        keys.forEach { (key: String) in
            let value = SMC.shared.getValue(key)
            print("[\(key)]    ", value ?? 0)
        }
    case .help, .unknown:
        print("SMC tool\n")
        print("Usage:")
        print("  ./smc [command]\n")
        print("Available Commands:")
        print("  list    list keys and values")
        print("  help    help menu\n")
        print("Available Flags:")
        print("  -t    list temperature sensors")
        print("  -v    list voltage sensors")
        print("  -p    list power sensors")
        print("  -f    list fans\n")
    }
}

main()
