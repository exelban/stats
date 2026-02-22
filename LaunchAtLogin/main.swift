//
//  main.swift
//  LaunchAtLogin
//
//  Created by Serhiy Mytrovtsiy on 08/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

func main() {
    let mainBundleId = Bundle.main.bundleIdentifier!.replacingOccurrences(of: ".LaunchAtLogin", with: "")
    
    if !NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleId).isEmpty {
        exit(0)
    }
    
    let pathComponents = (Bundle.main.bundlePath as NSString).pathComponents
    let mainPath = NSString.path(withComponents: Array(pathComponents[0...(pathComponents.count - 5)]))
    NSWorkspace.shared.openApplication(at: NSURL.fileURL(withPath: mainPath), configuration: NSWorkspace.OpenConfiguration(), completionHandler: { _, _ in
        exit(0)
    })
}

main()
