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
    private let defaults = UserDefaults.standard
    private let menuBarItem: NSStatusItem
    private var menuBarButton: NSButton = NSButton()
    private var view: NSView? = nil
    
    init(_ menuBarItem: NSStatusItem, menuBarButton: NSButton) {
        self.menuBarItem = menuBarItem
        self.menuBarButton = menuBarButton
        
        generateMenuBar()
        modules.subscribe(observer: self) { (_, _) in
            self.generateMenuBar()
        }
    }
    
    private func generateMenuBar() {
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
    
    private func buildModulesView() {
        if self.view == nil {
            self.view = NSView(frame: NSMakeRect(0, 0, widgetSize.width, widgetSize.height))
            self.menuBarButton.addSubview(self.view!)
        }
        let view = self.view!
        
        var WIDTH: CGFloat = 0
        for module in modules.value {
            if module.active.value && module.available.value {
                module.start()
                WIDTH = WIDTH + module.view.frame.size.width
            }
        }
        
        self.menuBarButton.image = nil
        for v in view.subviews {
            v.removeFromSuperview()
        }
        
        var x: CGFloat = 0
        for module in modules.value {
            if module.active.value && module.available.value {
                module.view.frame = CGRect(x: x, y: 0, width: module.view.frame.size.width, height: module.view.frame.size.height)
                view.addSubview(module.view)
                x = x + module.view.frame.size.width
            }
        }
        
        if view.subviews.count == 0 {
            self.menuBarButton.image = NSImage(named:NSImage.Name("tray_icon"))
            self.menuBarItem.length = widgetSize.width
        } else {
            self.menuBarItem.length = WIDTH
            view.frame.size.width = WIDTH
        }
    }
}
