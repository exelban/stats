//
//  MainViewController.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 02/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement
import LaunchAtLogin

public let TabWidth: CGFloat = 300
public let TabHeight: CGFloat = 356

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
        
        for module in modules {
            module.active.subscribe(observer: self) { (value, _) in
                for tab in self.tabView.tabViewItems {
                    self.tabView.removeTabViewItem(tab)
                }
                for view in self.topStackView.subviews {
                    view.removeFromSuperview()
                }
                self.segmentsControl = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: self, action: #selector(self.switchTabs))
                self.makeHeader()
            }
        }
    }
    
    override func viewWillAppear() {
        for module in modules {
            if module.tabAvailable && module.available.value && module.active.value && module.reader.availableAdditional {
                module.reader.startAdditional()
            }
        }
    }
    
    override func viewWillDisappear() {
        for module in modules {
            if module.tabAvailable && module.available.value && module.active.value && module.reader.availableAdditional {
                module.reader.stopAdditional()
            }
        }
    }
    
    func makeHeader() {
        var list: [String] = []
        for module in modules {
            if module.tabAvailable && module.available.value && module.active.value {
                list.append(module.name)
                
                let tab = module.tabView
                tab.label = module.name
                tab.identifier = module.name
                tab.view?.wantsLayer = true
                tab.view?.layer?.backgroundColor = NSColor.white.cgColor
                
                tabView.addTabViewItem(module.tabView)
            }
        }
        
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 26, height: 20))
        button.title = ""
        button.image = NSImage(named: NSImage.Name("NSActionTemplate"))
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedSquare
        button.setButtonType(.momentaryPushIn)
        button.action = #selector(showSettings)
        
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
        button.heightAnchor.constraint(equalToConstant: 21).isActive = true
        
        if list.count > 0 {
            self.segmentsControl = NSSegmentedControl(labels: list, trackingMode: NSSegmentedControl.SwitchTracking.selectOne, target: self, action: #selector(switchTabs))
            self.segmentsControl.setSelected(true, forSegment: 0)
            self.segmentsControl.segmentDistribution = .fillEqually
            
            self.topStackView.addView(self.segmentsControl, in: NSStackView.Gravity.center)
        } else {
            self.topStackView.addView(NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 0)), in: NSStackView.Gravity.center)
            tabView.addTabViewItem(generateEmptyTabView())
        }
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
        
        for module in modules {
            if module.available.value {
                menu.addItem(module.menu)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
      
        let openActivityMonitorMenu = NSMenuItem(title: "Open Activity Monitor", action: #selector(openActivityMonitor), keyEquivalent: "")
        openActivityMonitorMenu.target = self

        let checkForUpdates = NSMenuItem(title: "Check for updates on start", action: #selector(toggleMenu), keyEquivalent: "")
        checkForUpdates.state = defaults.bool(forKey: "checkUpdatesOnLogin") || defaults.object(forKey: "checkUpdatesOnLogin") == nil ? NSControl.StateValue.on : NSControl.StateValue.off
        checkForUpdates.target = self
        
        let runAtLogin = NSMenuItem(title: "Start at login", action: #selector(toggleMenu), keyEquivalent: "")
        runAtLogin.state = LaunchAtLogin.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
        runAtLogin.target = self
        
        let dockIcon = NSMenuItem(title: "Show icon in dock", action: #selector(toggleMenu), keyEquivalent: "")
        dockIcon.state = defaults.bool(forKey: "dockIcon") ? NSControl.StateValue.on : NSControl.StateValue.off
        dockIcon.target = self
        
        let updateMenu = NSMenuItem(title: "Check for updates", action: #selector(checkUpdate), keyEquivalent: "")
        updateMenu.target = self
        
        let aboutMenu = NSMenuItem(title: "About Stats", action: #selector(openAbout), keyEquivalent: "")
        aboutMenu.target = self
        
        menu.addItem(checkForUpdates)
        menu.addItem(runAtLogin)
        menu.addItem(dockIcon)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(openActivityMonitorMenu)
        menu.addItem(updateMenu)
        menu.addItem(aboutMenu)
        menu.addItem(NSMenuItem(title: "Quit Stats", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        return menu
    }
  
    @objc func openActivityMonitor(_ sender: NSMenuItem) {
        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.apple.ActivityMonitor",
            options: [.default],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil)
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
        let status = sender.state != NSControl.StateValue.on
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        
        switch sender.title {
        case "Start at login":
            LaunchAtLogin.isEnabled = status
            if self.defaults.object(forKey: "runAtLoginInitialized") == nil {
                self.defaults.set(true, forKey: "runAtLoginInitialized")
            }
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


func LabelField(string: String) -> NSTextField {
    let label: NSTextField = NSTextField(string: string)
    
    label.isEditable = false
    label.isSelectable = false
    label.isBezeled = false
    label.textColor = .darkGray
    label.alignment = .center
    label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
    label.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
    
    return label
}

func ValueField(string: String) -> NSTextField {
    let label: NSTextField = NSTextField(string: string)
    
    label.isEditable = false
    label.isSelectable = false
    label.isBezeled = false
    label.textColor = .black
    label.alignment = .center
    label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
    label.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
    
    return label
}

func generateEmptyTabView() -> NSTabViewItem {
    let emptyTabView = NSTabViewItem()
    emptyTabView.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
    emptyTabView.label = "empty"
    emptyTabView.identifier = "empty"
    emptyTabView.view?.wantsLayer = true
    emptyTabView.view?.layer?.backgroundColor = NSColor.white.cgColor
    
    let text: NSTextField = NSTextField(string: "No dashboard available")
    text.isEditable = false
    text.isSelectable = false
    text.isBezeled = false
    text.wantsLayer = true
    text.textColor = .labelColor
    text.canDrawSubviewsIntoLayer = true
    text.alignment = .center
    text.font = NSFont.systemFont(ofSize: 13, weight: .regular)
    text.frame = NSRect(x: 0, y: 0, width: TabWidth, height: 22)
    text.frame.origin.y = ((emptyTabView.view?.frame.size.height)! - 22) / 2
    
    emptyTabView.view?.addSubview(text)
    
    return emptyTabView
}
