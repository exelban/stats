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
        if !colors.value {
            return NSColor.textColor
        }
        
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

public enum Unit : Float {
    case byte     = 1
    case kilobyte = 1024
    case megabyte = 1048576
    case gigabyte = 1073741824
}

//extension NSView {
//    var backgroundColor: NSColor? {
//        get {
//            guard let color = layer?.backgroundColor else { return nil }
//            return NSColor(cgColor: color)
//        }
//        set {
//            wantsLayer = true
//            layer?.backgroundColor = newValue?.cgColor
//        }
//    }
//}
