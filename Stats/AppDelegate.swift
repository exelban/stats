//
//  AppDelegate.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement
import LaunchAtLogin

let modules: [Module] = [CPU(), Memory(), Disk(), Battery(), Network()]
let updater = macAppUpdater(user: "exelban", repo: "stats")
let popover = NSPopover()
var menuBar: MenuBar?

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private var menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = self.menuBarItem.button else {
            NSApp.terminate(nil)
            return
        }

        menuBarButton.action = #selector(toggleMenu)
        popover.contentViewController = MainViewController.Init()
        popover.behavior = .transient
        popover.animates = true

        menuBar = MenuBar(menuBarItem, menuBarButton: menuBarButton)
        menuBar!.build()

        if self.defaults.object(forKey: "runAtLoginInitialized") == nil {
            LaunchAtLogin.isEnabled = true
        }

        if defaults.object(forKey: "dockIcon") != nil {
            let dockIconStatus = defaults.bool(forKey: "dockIcon") ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }

        if defaults.object(forKey: "checkUpdatesOnLogin") == nil || defaults.bool(forKey: "checkUpdatesOnLogin") {
            updater.check() { result, error in
                if error != nil && error as! String == "No internet connection" {
                    return
                }

                guard error == nil, let version: version = result else {
                    print("Error: \(error ?? "check error")")
                    return
                }

                if version.newest {
                    DispatchQueue.main.async(execute: {
                        let updatesVC: NSWindowController? = NSStoryboard(name: "Updates", bundle: nil).instantiateController(withIdentifier: "UpdatesVC") as? NSWindowController
                        updatesVC?.window?.center()
                        updatesVC?.window?.level = .floating
                        updatesVC!.showWindow(self)
                    })
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if modules.count != 0 {
            for module in modules {
                module.stop()
            }
        }
    }
    
    @objc func toggleMenu(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = self.menuBarItem.button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                popover.show(relativeTo: .zero, of: button, preferredEdge: .maxY)
                popover.becomeFirstResponder()
            }
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
        popover.performClose(self)
    }
}
