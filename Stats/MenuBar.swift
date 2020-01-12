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
    private let menuBarItem: NSStatusItem
    private var menuBarButton: NSButton = NSButton()
    private var stackView: NSStackView = NSStackView()
    
    init(_ menuBarItem: NSStatusItem, menuBarButton: NSButton) {
        self.menuBarItem = menuBarItem
        self.menuBarButton = menuBarButton
        
        for module in modules {
            module.active.subscribe(observer: self) { (value, _) in
                if !value {
                    let emptyWidget = Empty()
                    emptyWidget.name = module.name
                    module.view = emptyWidget
                } else {
                    module.initWidget()
                }
                module.initMenu(active: value)
                if !module.tabInitialized {
                    module.initTab()
                }
                self.updateWidget(name: module.name)
            }
        }
    }
    
    public func updateWidget(name: String) {
        let newViewList = modules.filter{ $0.name == name }
        if newViewList.isEmpty {
            return
        }
        let oldViewList = self.stackView.subviews.filter{ ($0 as! Widget).name == name }
        if oldViewList.isEmpty {
            return
        }
        
        let newView = newViewList.first!.view
        newView.invalidateIntrinsicContentSize()
        let oldView = oldViewList.first!
        
        self.stackView.replaceSubview(oldView, with: newView)
        self.updateWidth()
    }
    
    private func updateWidth() {
        var WIDTH: CGFloat = 0
        for module in modules {
            if module.active.value && module.available.value {
                WIDTH = WIDTH + module.view.frame.size.width
            }
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
    
    public func build() {
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: widgetSize.width, height: widgetSize.height))
        stackView.wantsLayer = true
        stackView.orientation = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 0
        self.stackView = stackView
        
        var WIDTH: CGFloat = 0
        for module in modules {
            if module.available.value {
                if module.active.value {
                    module.initWidget()
                    module.initTab()
                    module.start()
                } else {
                    let emptyView = Empty()
                    emptyView.name = module.name
                    module.view = emptyView
                }
                module.initMenu(active: module.active.value)
                stackView.addArrangedSubview(module.view)
                WIDTH = WIDTH + module.view.frame.size.width
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
}
