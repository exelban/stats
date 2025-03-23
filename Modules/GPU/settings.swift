//
//  settings.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private var updateIntervalValue: Int = 1
    private var selectedGPU: String
    private var showTypeValue: Bool = false
    
    private let title: String
    
    public var selectedGPUHandler: (String) -> Void = {_ in }
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    private var hyperthreadView: NSView? = nil
    private var button: NSPopUpButton?
    
    public init(_ module: ModuleType) {
        self.title = module.stringValue
        self.selectedGPU = Store.shared.string(key: "\(self.title)_gpu", defaultValue: "")
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.showTypeValue = Store.shared.bool(key: "\(self.title)_showType", defaultValue: self.showTypeValue)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        self.wantsLayer = true
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Update interval"), component: selectView(
                action: #selector(self.changeUpdateInterval),
                items: ReaderUpdateIntervals,
                selected: "\(self.updateIntervalValue)"
            ))
        ]))
        
        #if arch(x86_64)
        if !widgets.filter({ $0 == .mini }).isEmpty {
            self.addArrangedSubview(PreferencesSection([
                PreferencesRow(localizedString("Show GPU type"), component: switchView(
                    action: #selector(self.toggleShowType),
                    state: self.showTypeValue
                ))
            ]))
        }
        #endif
        
        self.button = selectView(
            action: #selector(self.handleSelection),
            items: [],
            selected: ""
        )
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("GPU to show"), component: self.button!)
        ]))
    }
    
    internal func setList(_ gpus: GPUs) {
        var list: [KeyValue_t] = [
            KeyValue_t(key: "automatic", value: "Automatic"),
            KeyValue_t(key: "separator", value: "separator")
        ]
        gpus.active().forEach{ list.append(KeyValue_t(key: $0.model, value: $0.model)) }
        
        DispatchQueue.main.async(execute: {
            guard let button = self.button else { return }
            if button.menu?.items.count != list.count {
                let menu = NSMenu()
                
                list.forEach { (item) in
                    if item.key.contains("separator") {
                        menu.addItem(NSMenuItem.separator())
                    } else {
                        let interfaceMenu = NSMenuItem(title: localizedString(item.value), action: nil, keyEquivalent: "")
                        interfaceMenu.representedObject = item.key
                        menu.addItem(interfaceMenu)
                        if self.selectedGPU == item.key {
                            interfaceMenu.state = .on
                        }
                    }
                }
                
                button.menu = menu
                button.sizeToFit()
            }
        })
    }
    
    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.updateIntervalValue = value
        Store.shared.set(key: "\(self.title)_updateInterval", value: value)
        self.setInterval(value)
    }
    @objc private func handleSelection(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.selectedGPU = key
        Store.shared.set(key: "\(self.title)_gpu", value: key)
        self.selectedGPUHandler(key)
    }
    @objc private func toggleShowType(_ sender: NSControl) {
        self.showTypeValue = controlState(sender)
        Store.shared.set(key: "\(self.title)_showType", value: self.showTypeValue)
        self.callback()
    }
}
