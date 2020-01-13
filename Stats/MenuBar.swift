//
//  MenuBar.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 31.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

/*
 Class keeps a status bar item and has the main function for updating widgets.
 */
class MenuBar {
    public let modules: [Module] = [CPU(), Memory(), Disk(), Battery(), Network()]
    
    private let menuBarItem: NSStatusItem
    private var menuBarButton: NSButton = NSButton()
    private var stackView: NSStackView = NSStackView()
    private var popup: MainViewController
    
    /*
     Init main variables.
     */
    init(_ menuBarItem: NSStatusItem, menuBarButton: NSButton, popup: MainViewController) {
        self.menuBarItem = menuBarItem
        self.menuBarButton = menuBarButton
        self.popup = popup
    }
    
    /*
     Build status bar view with all widgets. All widgets must be initialized before.
     */
    public func build() {
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: widgetSize.width, height: widgetSize.height))
        stackView.wantsLayer = true
        stackView.orientation = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 0
        self.stackView = stackView
        
        var WIDTH: CGFloat = 0
        for module in self.modules {
            if module.available {
                if module.active {
                    module.initWidget()
                    module.initTab()
                    module.start()
                }
                module.initMenu(active: module.active)
                if module.active {
                    stackView.addArrangedSubview(module.view)
                    WIDTH = WIDTH + module.view.frame.size.width
                }
            }
        }
        
        self.menuBarButton.addSubview(stackView)
        
        if WIDTH == 0 {
            self.menuBarButton.image = NSImage(named:NSImage.Name("tray_icon"))
            self.menuBarItem.length = widgetSize.width
            return
        }
        
        self.menuBarButton.image = nil
        self.stackView.frame.size.width = WIDTH
        self.menuBarItem.length = WIDTH
    }
    
    /*
     Realod status bar view. Using to enable/disable widgets. Use this function when enable/disable modules.
     Or if widget type is changed.
     */
    public func reload(name: String) {
        let module = self.modules.filter{ $0.name == name }
        if module.isEmpty {
            return
        }

        let view = self.stackView.subviews.filter{ $0 is Widget && ($0 as! Widget).name == name }
        if view.isEmpty {
            // if module is active but not exist in stack, add it to stack (enable module)
            if module.first!.active {
                let activeModules = self.modules.filter{ $0.active && $0.available }
                let position = activeModules.firstIndex { $0.name == name }
                
                module.first!.initWidget()
                if !module.first!.tabInitialized {
                    module.first!.initTab()
                }
                
                if position! >= activeModules.count-1 {
                    stackView.addArrangedSubview(module.first!.view)
                } else {
                    stackView.insertArrangedSubview(module.first!.view, at: position!)
                    stackView.updateLayer()
                }
            }
        } else {
            // if module not active but exist, remove from stack (disable module), else replace
            if !module.first!.active {
                view.first!.removeFromSuperview()
            } else {
                let newView = module.first!.view
                newView.invalidateIntrinsicContentSize()
                self.stackView.replaceSubview(view.first!, with: newView)
            }
        }
        
        self.updateWidth()
        self.popup.reload()
    }
    
    /*
     Refresh wigets views if size of view was changed.
     For enabling/disabling widgets, please use reload().
     */
    public func refresh() {
        self.stackView.subviews.forEach { view in
            if !(view is Widget) { return }

            let module = self.modules.first { $0.name == (view as! Widget).name }
            if module == nil {
                return
            }
  
            module!.view.invalidateIntrinsicContentSize()
            self.stackView.replaceSubview(view, with: module!.view)
            self.updateWidth()
        }
    }
    
    /*
     Destroy will destroy status bar view.
     */
    public func destroy() {
        
    }
    
    private func updateWidth() {
        var WIDTH: CGFloat = 0
        for module in self.modules {
            if module.active && module.available {
                WIDTH = WIDTH + module.view.frame.size.width
            }
        }
        
        if self.stackView.frame.size.width == WIDTH {
            return
        }
        
        if WIDTH == 0 {
            self.menuBarButton.image = NSImage(named:NSImage.Name("tray_icon"))
            self.menuBarItem.length = widgetSize.width
            return
        }
        
        self.menuBarButton.image = nil
        self.stackView.frame.size.width = WIDTH
        self.menuBarItem.length = WIDTH
    }
}
