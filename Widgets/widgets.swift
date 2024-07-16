//
//  widgets.swift
//  WidgetsExtension
//
//  Created by Serhiy Mytrovtsiy on 30/06/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI

import CPU
import RAM
import Disk

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        CPUWidget()
        RAMWidget()
        DiskWidget()
    }
}
