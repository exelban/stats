//
//  AppDelegate.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

let modules: Observable<[Module]> = Observable([CPU(), Memory(), Disk()])
let colors: Observable<Bool> = Observable(true)

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard
    var menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = self.menuBarItem.button else {
            NSApp.terminate(nil)
            return
        }
        
        colors << (defaults.object(forKey: "colors") != nil ? defaults.bool(forKey: "colors") : false)
        _ = MenuBar(menuBarItem, menuBarButton: menuBarButton)
        
        let launcherAppId = "eu.exelban.StatsLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        
        if defaults.object(forKey: "runAtLogin") != nil {
            SMLoginItemSetEnabled(launcherAppId as CFString, defaults.bool(forKey: "runAtLogin"))
        } else {
            SMLoginItemSetEnabled(launcherAppId as CFString, true)
            self.defaults.set(true, forKey: "runAtLogin")
        }
        
        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if modules.value.count != 0 {
            for module in modules.value{
                module.stop()
            }
        }
    }
}

class AboutVC: NSViewController {
    @IBOutlet weak var versionLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
    }
    
    @IBAction func openLink(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats")!)
    }
    
    @IBAction func exit(_ sender: Any) {
        self.view.window?.close()
    }
    
    override func awakeFromNib() {
        if self.view.layer != nil {
            self.view.window?.backgroundColor = .white
            self.view.layer?.backgroundColor = .white
            
            let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            versionLabel.stringValue = "Version \(versionNumber)"
        }
    }
}
