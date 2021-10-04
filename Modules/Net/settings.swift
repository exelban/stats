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
import Kit
import SystemConfiguration

internal class Settings: NSStackView, Settings_v {
    private var numberOfProcesses: Int = 8
    private var readerType: String = "interface"
    private var usageReset: String = AppUpdateInterval.atStart.rawValue
    
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    public var usageResetCallback: (() -> Void) = {}
    
    private let title: String
    private var button: NSPopUpButton?
    
    private var list: [Network_interface] = []
    
    public init(_ title: String) {
        self.title = title
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.readerType = Store.shared.string(key: "\(self.title)_reader", defaultValue: self.readerType)
        self.usageReset = Store.shared.string(key: "\(self.title)_usageReset", defaultValue: self.usageReset)
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width - (Constants.Settings.margin*2), height: 0))
        
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if  let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
                let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                self.list.append(Network_interface(displayName: displayName as String, BSDName: bsdName as String))
            }
        }
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let width: CGFloat = self.frame.width - (Constants.Settings.margin*2)
        
        self.addArrangedSubview(selectTitleRow(
            frame: NSRect(x: 0, y: 0, width: width, height: Constants.Settings.row),
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        self.addArrangedSubview(selectRow(
            frame: NSRect(x: 0, y: 0, width: width, height: Constants.Settings.row),
            title: localizedString("Reader type"),
            action: #selector(changeReaderType),
            items: NetworkReaders,
            selected: self.readerType
        ))
        
        self.addArrangedSubview(selectRow(
            frame: NSRect(x: 0, y: 0, width: width, height: Constants.Settings.row),
            title: localizedString("Reset data usage"),
            action: #selector(toggleUsageReset),
            items: AppUpdateIntervals.dropLast(2),
            selected: self.usageReset
        ))
        
        self.addInterfaceSelector()
        
        let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing + self.edgeInsets.top + self.edgeInsets.bottom
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.bounds.width, height: h))
        }
    }
    
    private func addInterfaceSelector() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 30))
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(x: 0, y: (view.frame.height - 16)/2, width: view.frame.width - 52, height: 17), localizedString("Network interface"))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        self.button = NSPopUpButton(frame: NSRect(x: view.frame.width - 200 - Constants.Settings.margin*2, y: 0, width: 200, height: 26))
        self.button?.target = self
        self.button?.action = #selector(self.handleSelection)
        self.button?.isEnabled = self.readerType == "interface"
        
        let selectedInterface = Store.shared.string(key: "\(self.title)_interface", defaultValue: "")
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
        
        self.button?.menu = menu
        
        if selectedInterface == "" {
            self.button?.selectItem(withTitle: "Autodetection")
        }
        
        view.addSubview(rowTitle)
        view.addSubview(self.button!)
        
        self.addArrangedSubview(view)
    }
    
    @objc func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        
        if item.title == "Autodetection" {
            Store.shared.remove("\(self.title)_interface")
        } else {
            if let bsdName = item.identifier?.rawValue {
                Store.shared.set(key: "\(self.title)_interface", value: bsdName)
            }
        }
        
        self.callback()
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    
    @objc private func changeReaderType(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.readerType = key
        Store.shared.set(key: "\(self.title)_reader", value: key)
        self.button?.isEnabled = self.readerType == "interface"
    }
    
    @objc private func toggleUsageReset(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.usageReset = key
        Store.shared.set(key: "\(self.title)_usageReset", value: key)
        self.usageResetCallback()
    }
}
