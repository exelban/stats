//
//  protocol.swift
//  Helper
//
//  Created by Serhiy Mytrovtsiy on 17/11/2022
//  Using Swift 5.0
//  Running on macOS 13.0
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

@objc public protocol HelperProtocol {
    func version(completion: @escaping (String) -> Void)
    func setSMCPath(_ path: String)
    
    // Fan control
    func setFanMode(id: Int, mode: Int, completion: @escaping (String?) -> Void)
    func setFanSpeed(id: Int, value: Int, completion: @escaping (String?) -> Void)
    
    // Apple Silicon Ftst unlock (required for M1/M2/M3/M4 fan control)
    func setFtstUnlock(completion: @escaping (Bool, String?) -> Void)
    func setFtstLock(completion: @escaping (Bool, String?) -> Void)
    func getFtstStatus(completion: @escaping (Bool, Int, String?) -> Void)
    
    // System
    func powermetrics(_ samplers: [String], completion: @escaping (String?) -> Void)
    
    func uninstall()
}
