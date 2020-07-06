//
//  settings.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 06/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit
import SystemConfiguration

internal class Settings: NSView, Settings_v {
    public var callback: (() -> Void) = {}
    
    private let title: String
    private let store: UnsafePointer<Store>
    private var button: NSPopUpButton?
    
    private var list: [Network_interface] = []
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        
        super.init(frame: CGRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: Constants.Settings.width - (Constants.Settings.margin*2), height: 0))
        
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if  let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
                let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                self.list.append(Network_interface(displayName: displayName as String, BSDName: bsdName as String))
            }
        }
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widget: widget_t) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addNetworkSelector()
        
        self.setFrameSize(NSSize(width: self.frame.width, height: 30 + (Constants.Settings.margin*2)))
    }
    
    private func addNetworkSelector() {
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: self.frame.width, height: 29))
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (view.frame.height - 16)/2, width: view.frame.width - 52, height: 17), "Network interface")
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        self.button = NSPopUpButton(frame: NSRect(x: view.frame.width - 200 - Constants.Settings.margin*2, y: -1, width: 200, height: 30))
        self.button!.target = self
        self.button?.action = #selector(self.handleSelection)
        
        let selectedInterface = self.store.pointee.string(key: "\(self.title)_interface", defaultValue: "")
        let menu = NSMenu()
        let autodetection = NSMenuItem(title: "Autodetection", action: nil, keyEquivalent: "")
        menu.addItem(autodetection)
        menu.addItem(NSMenuItem.separator())
        
        self.list.forEach { (interface: Network_interface) in
            let interfaceMenu = NSMenuItem(title: "\(interface.displayName) (\(interface.BSDName))", action: nil, keyEquivalent: "")
            interfaceMenu.identifier = NSUserInterfaceItemIdentifier(rawValue: interface.BSDName)
            menu.addItem(interfaceMenu)
            if selectedInterface != "" && selectedInterface == interface.BSDName {
                interfaceMenu.state = .on
            }
        }
        
        if selectedInterface == "" {
            self.button?.selectItem(withTitle: "Autodetection")
        }
        
        self.button?.menu = menu
        
        view.addSubview(rowTitle)
        view.addSubview(self.button!)
        
        self.addSubview(view)
    }
    
    @objc func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        
        if item.title == "Autodetection" {
            self.store.pointee.remove("\(self.title)_interface")
        } else {
            if let bsdName = item.identifier?.rawValue {
                self.store.pointee.set(key: "\(self.title)_interface", value: bsdName)
            }
        }
        
        self.callback()
    }
}
