//
//  MenuBar.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 31.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

let MODULE_HEIGHT: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 22
let MODULE_WIDTH: CGFloat = 32
let MODULE_MARGIN: CGFloat = 2

class MenuBar {
    let defaults = UserDefaults.standard
    let menuBarItem: NSStatusItem
    lazy var menuBarButton: NSButton = NSButton()
    
    init(_ menuBarItem: NSStatusItem, menuBarButton: NSButton) {
        self.menuBarItem = menuBarItem
        self.menuBarButton = menuBarButton
        
        generateMenuBar()
        modules.subscribe(observer: self) { (_, _) in
            self.generateMenuBar()
        }
    }
    
    func generateMenuBar() {
        buildModulesView()
        menuBarItem.menu = buildMenu()
        
        for module in modules.value {
            module.active.subscribe(observer: self) { (value, _) in
                self.buildModulesView()
                self.menuBarItem.menu?.removeAllItems()
                self.menuBarItem.menu = self.buildMenu()
            }
            module.available.subscribe(observer: self) { (value, _) in
                self.buildModulesView()
                self.menuBarItem.menu?.removeAllItems()
                self.menuBarItem.menu = self.buildMenu()
            }
        }
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        for module in modules.value {
            if module.available.value {
                menu.addItem(module.menu)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let preferences = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        let preferencesMenu = NSMenu()
        
        let runAtLogin = NSMenuItem(title: "Start at login", action: #selector(toggleMenu), keyEquivalent: "")
        runAtLogin.state = defaults.bool(forKey: "runAtLogin") || defaults.object(forKey: "runAtLogin") == nil ? NSControl.StateValue.on : NSControl.StateValue.off
        runAtLogin.target = self
        preferencesMenu.addItem(runAtLogin)
        
        let dockIcon = NSMenuItem(title: "Show icon in dock", action: #selector(toggleMenu), keyEquivalent: "")
        dockIcon.state = defaults.bool(forKey: "dockIcon") ? NSControl.StateValue.on : NSControl.StateValue.off
        dockIcon.target = self
        preferencesMenu.addItem(dockIcon)
        
        preferences.submenu = preferencesMenu
        menu.addItem(preferences)
        
        menu.addItem(NSMenuItem.separator())
        
        let updateMenu = NSMenuItem(title: "Check for updates", action: #selector(checkUpdate), keyEquivalent: "")
        updateMenu.target = self
        
        let aboutMenu = NSMenuItem(title: "About Stats", action: #selector(openAbout), keyEquivalent: "")
        aboutMenu.target = self
        
        menu.addItem(updateMenu)
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
        case "Run at login":
            SMLoginItemSetEnabled(launcherId as CFString, !status)
            self.defaults.set(status, forKey: "runAtLogin")
        case "Show icon in dock":
            self.defaults.set(status, forKey: "dockIcon")
            let iconStatus = status ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(iconStatus)
            return
        default: break
        }
    }
    
    func buildModulesView() {
        for subview in self.menuBarButton.subviews {
            subview.removeFromSuperview()
        }
        
        self.menuBarButton.image = NSImage(named:NSImage.Name("tray_icon"))
        self.menuBarItem.length = MODULE_WIDTH
        var WIDTH = CGFloat(modules.value.count) * MODULE_WIDTH
        
        WIDTH = 0
        for module in modules.value {
            if module.active.value && module.available.value {
                module.start()
                WIDTH = WIDTH + module.view.frame.size.width
            }
        }
        
        let view: NSView = NSView(frame: NSMakeRect(0, 0, WIDTH, MODULE_HEIGHT))
        
        var x: CGFloat = 0
        for module in modules.value {
            if module.active.value && module.available.value {
                module.view.frame = CGRect(x: x, y: 0, width: module.view.frame.size.width, height: module.view.frame.size.height)
                view.addSubview(module.view)
                x = x + module.view.frame.size.width
            }
        }
        
        if view.subviews.count != 0 {
            view.frame.size.width = WIDTH
            self.menuBarButton.image = nil
            self.menuBarItem.length = WIDTH
            self.menuBarButton.addSubview(view)
        }
    }
}
