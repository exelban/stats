//
//  AppDelegate.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement
import LaunchAtLogin

let modules: Observable<[Module]> = Observable([CPU(), Memory(), Disk(), Battery(), Network()])
let updater = macAppUpdater(user: "exelban", repo: "stats")
let menu = NSPopover()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard
    var menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let menuBarButton = self.menuBarItem.button else {
            NSApp.terminate(nil)
            return
        }
        
        menuBarButton.action = #selector(toggleMenu)
        menu.contentViewController = MainViewController.Init()
        menu.behavior = NSPopover.Behavior.transient
        
        _ = MenuBar(menuBarItem, menuBarButton: menuBarButton)

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
        if modules.value.count != 0 {
            for module in modules.value{
                module.stop()
            }
        }
    }
    
    @objc func toggleMenu(_ sender: Any?) {
        if menu.isShown {
            menu.performClose(sender)
        } else {
            if let button = self.menuBarItem.button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                menu.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                menu.becomeFirstResponder()
            }
        }
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        menu.performClose(self)
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
