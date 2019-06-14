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
    
    func usageColor(reversed: Bool = false) -> NSColor {
        if !colors.value {
            return NSColor.textColor
        }
        
        if reversed {
            switch self {
            case 0.6...0.8:
                return NSColor.systemOrange
            case 0.8...1:
                return NSColor.systemGreen
            default:
                return NSColor.systemRed
            }
        } else {
            switch self {
            case 0.6...0.8:
                return NSColor.systemOrange
            case 0.8...1:
                return NSColor.systemRed
            default:
                return NSColor.systemGreen
            }
        }
    }
    
    func batteryColor() -> NSColor {
        switch self {
        case 0.2...0.4:
            if !colors.value {
                return NSColor.controlTextColor
            }
            return NSColor.systemOrange
        case 0.4...1:
            if !colors.value {
                return NSColor.controlTextColor
            }
            return NSColor.systemGreen
        default:
            return NSColor.systemRed
        }
    }
}

public enum Unit : Float {
    case byte     = 1
    case kilobyte = 1024
    case megabyte = 1048576
    case gigabyte = 1073741824
}

