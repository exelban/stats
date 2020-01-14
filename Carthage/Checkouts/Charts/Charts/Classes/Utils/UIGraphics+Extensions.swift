//
//  UIGraphics+Extensions.swift
//  Charts
//
//  UIGraphics+Extensions implementation:
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import UIKit

public func UIGraphicsPushContext(context: CGContext?) {
    
    guard let context = context else {
        return
    }
    
    UIGraphicsPushContext(context)
}
