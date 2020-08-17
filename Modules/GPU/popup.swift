//
//  popup.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

internal class Popup: NSView {
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func infoCallback(_ value: GPUs) {
        print(value)
    }
}

private class GPUView: NSView {
    
}
