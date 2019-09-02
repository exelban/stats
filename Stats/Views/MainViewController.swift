//
//  MainViewController.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 02/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

let TabWidth: CGFloat = 300
let TabHeight: CGFloat = 356

class MainViewController: NSViewController {
    let defaults = UserDefaults.standard
    
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var topStackView: NSStackView!
    
    var segmentsControl: NSSegmentedControl!
    var settingsButton: NSButton!
    
    static func Init() -> MainViewController {
        let storyboard = NSStoryboard.init(name: "Main", bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("MainViewController")
        
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? MainViewController else {
            fatalError("Why cant i find MainViewController? - Check Main.storyboard")
        }
        
        return viewcontroller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        makeHeader()
    }
    
    func makeHeader() {
        var items: [String] = []
        for module in modules.value {
            if module.viewAvailable && module.available.value {
                items.append(module.name)
                
                let tab = module.tabView
                tab.label = module.name
                tab.identifier = module.name
                tab.view?.wantsLayer = true
                tab.view?.layer?.backgroundColor = NSColor.white.cgColor
                
                tabView.addTabViewItem(module.tabView)
            }
        }
        
        self.segmentsControl = NSSegmentedControl(labels: items, trackingMode: NSSegmentedControl.SwitchTracking.selectOne, target: self, action: #selector(switchTabs))
        self.segmentsControl.setSelected(true, forSegment: 0)
        self.segmentsControl.segmentDistribution = .fillEqually
        
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 26, height: 20))
        button.title = ""
        button.image = NSImage(named: NSImage.Name("NSActionTemplate"))
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedSquare
        button.setButtonType(.momentaryPushIn)
        button.action = #selector(showSettings)
        
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
        button.heightAnchor.constraint(equalToConstant: 21).isActive = true
        
        self.topStackView.addView(self.segmentsControl, in: NSStackView.Gravity.center)
        self.topStackView.addView(button, in: NSStackView.Gravity.center)
    }
    
    @objc func switchTabs(_ sender: NSSegmentedControl) {
        if let selectedLabel = self.segmentsControl.label(forSegment: sender.selectedSegment) {
            let tabNumber = self.tabView.indexOfTabViewItem(withIdentifier: selectedLabel)
            self.tabView.selectTabViewItem(at: tabNumber)
        }
    }
    
    @IBAction func showSettings(_ sender: NSButton) {
        let settings = buildSettings()
        let p = NSPoint(x: NSEvent.mouseLocation.x + 3, y: NSEvent.mouseLocation.y - 3)
        settings.popUp(positioning: settings.item(at: 0), at:p , in: nil)
    }
    
    func buildSettings() -> NSMenu {
        let menu = NSMenu()
        
        for module in modules.value {
            if module.available.value {
                menu.addItem(module.menu)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let checkForUpdates = NSMenuItem(title: "Check for updates on start", action: #selector(toggleMenu), keyEquivalent: "")
        checkForUpdates.state = defaults.bool(forKey: "checkUpdatesOnLogin") || defaults.object(forKey: "checkUpdatesOnLogin") == nil ? NSControl.StateValue.on : NSControl.StateValue.off
        checkForUpdates.target = self
        
        let runAtLogin = NSMenuItem(title: "Start at login", action: #selector(toggleMenu), keyEquivalent: "")
        runAtLogin.state = defaults.bool(forKey: "runAtLogin") || defaults.object(forKey: "runAtLogin") == nil ? NSControl.StateValue.on : NSControl.StateValue.off
        runAtLogin.target = self
        
        let dockIcon = NSMenuItem(title: "Show icon in dock", action: #selector(toggleMenu), keyEquivalent: "")
        dockIcon.state = defaults.bool(forKey: "dockIcon") ? NSControl.StateValue.on : NSControl.StateValue.off
        dockIcon.target = self
        
        menu.addItem(checkForUpdates)
        menu.addItem(runAtLogin)
        menu.addItem(dockIcon)
        
        menu.addItem(NSMenuItem.separator())
        
        let updateMenu = NSMenuItem(title: "Check for updates", action: #selector(checkUpdate), keyEquivalent: "")
        updateMenu.target = self
        
        let aboutMenu = NSMenuItem(title: "About Stats", action: #selector(openAbout), keyEquivalent: "")
        aboutMenu.target = self
        
        if !appStoreMode {
            menu.addItem(updateMenu)
        }
        menu.addItem(aboutMenu)
        menu.addItem(NSMenuItem(title: "Quit Stats", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        return menu
    }
    
    @objc func checkUpdate(_ sender : NSMenuItem) {
        let updatesVC: NSWindowController? = NSStoryboard(name: "Updates", bundle: nil).instantiateController(withIdentifier: "UpdatesVC") as? NSWindowController
        updatesVC?.window?.center()
        updatesVC?.window?.level = .floating
        updatesVC!.showWindow(self)
    }
    
    @objc func openAbout(_ sender : NSMenuItem) {
        let aboutVC: NSWindowController? = NSStoryboard(name: "About", bundle: nil).instantiateController(withIdentifier: "AboutVC") as? NSWindowController
        aboutVC?.window?.center()
        aboutVC?.window?.level = .floating
        aboutVC!.showWindow(self)
    }
    
    @objc func toggleMenu(_ sender : NSMenuItem) {
        let launcherId = "eu.exelban.StatsLauncher"
        let status = sender.state != NSControl.StateValue.on
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        
        switch sender.title {
        case "Start at login":
            SMLoginItemSetEnabled(launcherId as CFString, status)
            self.defaults.set(status, forKey: "runAtLogin")
        case "Check for updates on start":
            self.defaults.set(status, forKey: "checkUpdatesOnLogin")
        case "Show icon in dock":
            self.defaults.set(status, forKey: "dockIcon")
            let iconStatus = status ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(iconStatus)
            return
        default: break
        }
    }
}
