//
//  Telemetry.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 18/06/2023
//  Using Swift 5.0
//  Running on macOS 13.4
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

public class Telemetry {
    public static let shared = Telemetry()
    
    public var isEnabled: Bool {
        get { Store.shared.bool(key: "telemetry", defaultValue: true) }
        set { Store.shared.set(key: "telemetry", value: newValue) }
    }
    
    public init() {}
}
