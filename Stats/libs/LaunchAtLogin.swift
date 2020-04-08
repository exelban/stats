//
//  LaunchAtLogin.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 08/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import ServiceManagement

public struct LaunchAtLogin {
    private static let id = "\(Bundle.main.bundleIdentifier!).LaunchAtLogin"

    public static var isEnabled: Bool {
        get {
            guard let jobs = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]]) else {
                return false
            }

            let job = jobs.first { $0["Label"] as! String == id }

            return job?["OnDemand"] as? Bool ?? false
        }
        set {
            SMLoginItemSetEnabled(id as CFString, newValue)
        }
    }
}
