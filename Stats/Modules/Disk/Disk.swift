//
//  Disk.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Disk: Module {
    public var name: String = "SSD"
    public var updateInterval: Double = 15
    
    public var enabled: Bool = true
    public var available: Bool = true
    
    public var readers: [Reader] = []
    public var task: Repeater?
    
    public var widget: ModuleWidget = ModuleWidget()
    public var popup: ModulePopup = ModulePopup(false)
    public var menu: NSMenuItem = NSMenuItem()
    
    public let defaults = UserDefaults.standard
    public var submenu: NSMenu = NSMenu()
    
    init() {
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Mini
        
        self.initWidget()
        self.initMenu()
        
        readers.append(DiskCapacityReader(self.usageUpdater))
        
        self.task = Repeater.init(interval: .seconds(self.updateInterval), observer: { _ in
            self.readers.forEach { reader in
                reader.read()
            }
        })
    }
    
    public func start() {
        if self.task != nil && self.task!.state.isRunning == false {
            self.task!.start()
        }
    }
    
    public func stop() {
        if self.task!.state.isRunning {
            self.task?.pause()
        }
    }
    
    public func restart() {
        self.stop()
        self.start()
    }
    
    private func usageUpdater(value: Double) {
        if self.widget.view is Widget {
            (self.widget.view as! Widget).setValue(data: [value])
        }
    }
}
