//
//  MenuBar.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 31.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

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
        
        for module in modules.value {
            module.active.subscribe(observer: self) { (value, _) in
                self.buildModulesView()
                self.menuBarItem.menu?.removeAllItems()
            }
            module.available.subscribe(observer: self) { (value, _) in
                self.buildModulesView()
                self.menuBarItem.menu?.removeAllItems()
            }
        }
    }
    
    func buildModulesView() {
        for subview in self.menuBarButton.subviews {
            subview.removeFromSuperview()
        }
        
        self.menuBarButton.image = NSImage(named:NSImage.Name("tray_icon"))
        self.menuBarItem.length = widgetSize.width
        var WIDTH = CGFloat(modules.value.count) * widgetSize.width
        
        WIDTH = 0
        for module in modules.value {
            if module.active.value && module.available.value {
                module.start()
                WIDTH = WIDTH + module.view.frame.size.width
            }
        }
        
        let view: NSView = NSView(frame: NSMakeRect(0, 0, WIDTH, widgetSize.height))
        
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
