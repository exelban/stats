//
//  Extensions.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 29/05/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import Cocoa

extension Float {
    func roundTo(decimalPlaces: Int) -> String {
        return NSString(format: "%.\(decimalPlaces)f" as NSString, self) as String
    }
    
    func usageColor() -> NSColor {
        switch self {
        case 0.6...0.8:
            return NSColor.orange
        case 0.8...1:
            return NSColor.red
        default:
            return NSColor.green
        }
    }
}

public enum Unit : Double {
    case byte     = 1
    case kilobyte = 1024
    case megabyte = 1048576
    case gigabyte = 1073741824
}
