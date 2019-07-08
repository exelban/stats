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

let modules: Observable<[Module]> = Observable([CPU(), Memory(), Disk(), Battery(), Network()])

let updater = macAppUpdater(user: "exelban", repo: "stats")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard
    var menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = self.menuBarItem.button else {
            NSApp.terminate(nil)
            return
        }
        
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
        
        if defaults.object(forKey: "dockIcon") != nil {
            let dockIconStatus = defaults.bool(forKey: "dockIcon") ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
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
            self.view.window?.backgroundColor = .windowBackgroundColor
            let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            versionLabel.stringValue = "Version \(versionNumber)"
        }
    }
}

class UpdatesVC: NSViewController {
    @IBOutlet weak var mainView: NSStackView!
    @IBOutlet weak var spinnerView: NSView!
    @IBOutlet weak var noInternetView: NSView!
    @IBOutlet weak var mainTextLabel: NSTextFieldCell!
    @IBOutlet weak var currentVersionLabel: NSTextField!
    @IBOutlet weak var latestVersionLabel: NSTextField!
    @IBOutlet weak var downloadButton: NSButton!
    @IBOutlet weak var spinner: NSProgressIndicator!
    
    var url: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        
        self.spinner.startAnimation(self)
        
        updater.check() { result, error in
            if error != nil && error as! String == "No internet connection" {
                DispatchQueue.main.async(execute: {
                    self.spinnerView.isHidden = true
                    self.noInternetView.isHidden = false
                })
                return
            }
            
            guard error == nil, let version: version = result else {
                print("Error: \(error ?? "check error")")
                return
            }
            
            DispatchQueue.main.async(execute: {
                self.spinner.stopAnimation(self)
                self.spinnerView.isHidden = true
                self.mainView.isHidden = false
                self.currentVersionLabel.stringValue = version.current
                self.latestVersionLabel.stringValue = version.latest
                self.url = version.url
                
                if !version.newest {
                    self.mainTextLabel.stringValue = "No new version available"
                    self.downloadButton.isEnabled = false
                }
            })
        }
    }
    
    override func awakeFromNib() {
        if self.view.layer != nil {
            self.view.window?.backgroundColor = .windowBackgroundColor
        }
    }
    
    @IBAction func download(_ sender: Any) {
        guard let urlString = self.url, let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
        self.view.window?.close()
    }
    
    @IBAction func exit(_ sender: Any) {
        self.view.window?.close()
    }
}
