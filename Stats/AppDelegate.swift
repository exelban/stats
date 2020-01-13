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

let updater = macAppUpdater(user: "exelban", repo: "stats")
var menuBar: MenuBar?

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private var menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = self.menuBarItem.button else {
            NSApp.terminate(nil)
            return
        }

        menuBarButton.action = #selector(toggleMenu)
        menuBarButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
        
        let mcv = MainViewController.Init()
        self.popover.contentViewController = mcv
        self.popover.behavior = .transient
        self.popover.animates = true

        menuBar = MenuBar(menuBarItem, menuBarButton: menuBarButton, popup: mcv)
        menuBar!.build()

        self.defaultValues()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        menuBar?.destroy()
    }

    func applicationWillResignActive(_ notification: Notification) {
        self.popover.performClose(self)
    }
    
    @objc func toggleMenu(_ sender: Any?) {
        if self.popover.isShown {
            self.popover.performClose(sender)
        } else {
            if let button = self.menuBarItem.button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                self.popover.show(relativeTo: .zero, of: button, preferredEdge: .maxY)
                self.popover.becomeFirstResponder()
            }
        }
    }
    
    private func defaultValues() {
        if self.defaults.object(forKey: "runAtLoginInitialized") == nil {
            LaunchAtLogin.isEnabled = true
        }

        if defaults.object(forKey: "dockIcon") != nil {
            let dockIconStatus = defaults.bool(forKey: "dockIcon") ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }
        
        if defaults.object(forKey: "checkUpdatesOnLogin") == nil || defaults.bool(forKey: "checkUpdatesOnLogin") {
            self.checkForNewVersion()
        }
    }
    
    private func checkForNewVersion() {
        updater.check() { result, error in
            if error != nil && error as! String == "No internet connection" {
                print("Error: \(error ?? "check error")")
                return
            }

            guard error == nil, let version: version = result else {
                print("Error: \(error ?? "download error")")
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
