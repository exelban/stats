//
//  popup.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 11/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public func initWindow(title: String) -> NSWindow {
    let viewController = PopupViewController()
    viewController.setup(title: title)
    
    let panel = NSPanel()
    panel.contentViewController = viewController
    panel.backingType = .buffered
    panel.isFloatingPanel = true
    panel.styleMask = .borderless
    panel.animationBehavior = .default
    panel.collectionBehavior = .transient
    panel.setIsVisible(false)
    panel.setFrame(NSRect(x: 0, y: 0, width: viewController.view.frame.width, height: viewController.view.frame.height), display: false)
    
    let windowController = NSWindowController()
    windowController.window = panel
    windowController.loadWindow()
    
    return panel
}

class PopupViewController: NSViewController {
    let width: CGFloat = 300
    let height: CGFloat = 350
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: self.width, height: self.height))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleField = NSTextField(frame: NSRect(x: 10, y: 10, width: 100, height: 100))
        titleField.isBezeled = false
        titleField.drawsBackground = false
        titleField.isEditable = false
        titleField.isSelectable = false
        titleField.stringValue = "Hello World \(self.title ?? "")"
        
        self.view.addSubview(titleField)
    }
    
    public func setup(title: String) {
        self.title = title
    }
}
