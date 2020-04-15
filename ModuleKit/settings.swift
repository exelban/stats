//
//  settings.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 13/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Settings_p: NSView {
    
}

open class Settings: NSView, Settings_p {
    private let toggleCallback: () -> ()
    
    init(title: String, enabled: Bool, toggleEnable: @escaping () -> ()) {
        self.toggleCallback = toggleEnable
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.wantsLayer = true
        self.layer?.backgroundColor = .white
        
        let titleView = NSTextField(frame: NSMakeRect((self.frame.width-100)/2, (self.frame.height - 20)/2, 100, 20))
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .black
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .center
        titleView.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleView.stringValue = title
        
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch(frame: NSRect(x: (self.frame.width-100)/2, y: ((self.frame.height - 20)/2) - 30, width: 100, height: 30))
            switchButton.state = enabled ? .on : .off
            switchButton.action = #selector(self.toggleEnable)
            switchButton.target = self
            
            self.addSubview(switchButton)
        }
        
        self.addSubview(titleView)
    }
    
    @objc func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
