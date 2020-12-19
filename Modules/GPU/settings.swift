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
import StatsKit
import ModuleKit

internal class Settings: NSView, Settings_v {
    private var updateIntervalValue: Int = 1
    private var selectedGPU: String
    
    private let title: String
    private let store: UnsafePointer<Store>
    
    public var selectedGPUHandler: (String) -> Void = {_ in }
    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    
    private var hyperthreadView: NSView? = nil
    private var button: NSPopUpButton?
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.title = title
        self.store = store
        self.selectedGPU = store.pointee.string(key: "\(self.title)_gpu", defaultValue: "")
        self.updateIntervalValue = store.pointee.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: Constants.Settings.width - (Constants.Settings.margin*2),
            height: 0
        ))
        
        self.wantsLayer = true
        self.canDrawConcurrently = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widget: widget_t) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        let rowHeight: CGFloat = 30
        let num: CGFloat = 1
        
        self.addSubview(SelectTitleRow(
            frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin + (rowHeight + Constants.Settings.margin) * num, width: self.frame.width - (Constants.Settings.margin*2), height: rowHeight),
            title: LocalizedString("Update interval"),
            action: #selector(changeUpdateInterval),
            items: ReaderUpdateIntervals.map{ "\($0) sec" },
            selected: "\(self.updateIntervalValue) sec"
        ))
        
        self.addGPUSelector()
        
        self.setFrameSize(NSSize(width: self.frame.width, height: (rowHeight*(num+1)) + (Constants.Settings.margin*(2+num))))
    }
    
    private func addGPUSelector() {
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: self.frame.width - Constants.Settings.margin*2,
            height: 30
        ))
        
        let rowTitle: NSTextField = LabelField(frame: NSRect(
            x: 0,
            y: (view.frame.height - 16)/2,
            width: view.frame.width - 52,
            height: 17
        ), LocalizedString("GPU to show"))
        rowTitle.font = NSFont.systemFont(ofSize: 13, weight: .light)
        rowTitle.textColor = .textColor
        
        self.button = NSPopUpButton(frame: NSRect(x: view.frame.width - 200, y: -1, width: 200, height: 30))
        self.button!.target = self
        self.button?.action = #selector(self.handleSelection)
        
        view.addSubview(rowTitle)
        view.addSubview(self.button!)
        
        self.addSubview(view)
    }
    
    internal func setList(_ gpus: GPUs) {
        var list: [KeyValue_t] = [
            KeyValue_t(key: "automatic", value: "Automatic"),
            KeyValue_t(key: "separator", value: "separator"),
        ]
        gpus.active().forEach{ list.append(KeyValue_t(key: $0.model, value: $0.model)) }
        
        DispatchQueue.main.async(execute: {
            guard let button = self.button else {
                return
            }
            
            if button.menu?.items.count != list.count {
                let menu = NSMenu()
                
                list.forEach { (item) in
                    if item.key.contains("separator") {
                        menu.addItem(NSMenuItem.separator())
                    } else {
                        let interfaceMenu = NSMenuItem(title: LocalizedString(item.value), action: nil, keyEquivalent: "")
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
        if let value = Int(sender.title.replacingOccurrences(of: " sec", with: "")) {
            self.updateIntervalValue = value
            self.store.pointee.set(key: "\(self.title)_updateInterval", value: value)
            self.setInterval(value)
        }
    }
    
    @objc private func handleSelection(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        
        self.selectedGPU = key
        self.store.pointee.set(key: "\(self.title)_gpu", value: key)
        self.selectedGPUHandler(key)
    }
}
