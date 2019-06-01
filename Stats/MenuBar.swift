//
//  MenuBar.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 31.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

let MODULE_HEIGHT = CGFloat(NSApplication.shared.mainMenu?.menuBarHeight ?? 22)
let MODULE_WIDTH = CGFloat(28)

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
            }
        }
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        for module in modules.value {
            menu.addItem(module.menu())
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let preferences = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        let preferencesMenu = NSMenu()
        
        let colorStatus = NSMenuItem(title: "Colors", action: #selector(toggleMenu), keyEquivalent: "")
        colorStatus.state = defaults.object(forKey: "colors") != nil && !defaults.bool(forKey: "colors") ? NSControl.StateValue.off : NSControl.StateValue.on
        colorStatus.target = self
        preferencesMenu.addItem(colorStatus)
        
        let runAtLogin = NSMenuItem(title: "Run at login", action: #selector(toggleMenu), keyEquivalent: "")
        runAtLogin.state = defaults.object(forKey: "runAtLogin") != nil && !defaults.bool(forKey: "runAtLogin") ? NSControl.StateValue.off : NSControl.StateValue.on
        runAtLogin.target = self
        preferencesMenu.addItem(runAtLogin)
        
        preferences.submenu = preferencesMenu
        menu.addItem(preferences)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Stats", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        return menu
    }
    
    @objc func toggleMenu(_ sender : NSMenuItem) {
        let launcherId = "eu.exelban.StatsLauncher"
        let status = sender.state != NSControl.StateValue.on
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        
        switch sender.title {
        case "Run at login":
            SMLoginItemSetEnabled(launcherId as CFString, !status)
            self.defaults.set(status, forKey: "runAtLogin")
        case "Colors":
            self.defaults.set(status, forKey: "colors")
            colors << status
            return
        default: break
        }
    }
    
    func buildModulesView() {
        for subview in self.menuBarButton.subviews {
            subview.removeFromSuperview()
        }
        
        self.menuBarButton.image = NSImage(named:NSImage.Name("tray_icon"))
        var WIDTH = CGFloat(modules.value.count * 28)
        
        let view: NSView = NSView(frame: NSMakeRect(0, 0, WIDTH, MODULE_HEIGHT))
        
        let stack: NSStackView = NSStackView(frame: NSMakeRect(0, 0, WIDTH, MODULE_HEIGHT))
        stack.orientation = NSUserInterfaceLayoutOrientation.horizontal
        stack.distribution  = NSStackView.Distribution.fillEqually
        stack.spacing = 0
        
        WIDTH = 0
        for module in modules.value {
            if module.active.value {
                module.start()
                WIDTH = WIDTH + module.view.frame.size.width
                stack.addView(module.view, in: NSStackView.Gravity.center)
            }
        }
        
        if stack.subviews.count != 0 {
            view.frame.size.width = WIDTH
            stack.frame.size.width = WIDTH
            self.menuBarItem.length = WIDTH
            
            view.addSubview(stack)
            
            self.menuBarButton.image = nil
            self.menuBarButton.addSubview(view)
        }
    }
}
