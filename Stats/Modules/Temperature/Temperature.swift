//
//  Temperature.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Temperature: Module {
    public var name: String = "Temperature"
    public var updateInterval: Double = 1
    
    public var enabled: Bool = true
    public var available: Bool = true
    
    public var widget: ModuleWidget = ModuleWidget()
    public var popup: ModulePopup = ModulePopup(false)
    public var menu: NSMenuItem = NSMenuItem()
    
    public var readers: [Reader] = []
    public var task: Repeater?
    
    internal let defaults = UserDefaults.standard
    internal var submenu: NSMenu = NSMenu()
    
    internal var value_1: String = "cpu_1_diode"
    internal var value_2: String = "gpu_diode"
    internal var once: Int = 0
    
    init() {
        if !self.available { return }
        
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Temperature
        self.value_1 = (defaults.object(forKey: "\(name)_value_1") != nil ? defaults.string(forKey: "\(name)_value_1")! : value_1)
        self.value_2 = (defaults.object(forKey: "\(name)_value_2") != nil ? defaults.string(forKey: "\(name)_value_2")! : value_2)
        
        self.initGroups()
        self.initWidget()
        self.initMenu()
        
        readers.append(TemperatureReader(self.usageUpdater))
        
        self.task = Repeater.init(interval: .seconds(self.updateInterval), observer: { _ in
            self.readers.forEach { reader in
                reader.read()
            }
        })
    }
    
    func start() {
        if self.task != nil && self.task!.state.isRunning == false {
            self.task!.start()
        }
    }
    
    func stop() {
        if self.task!.state.isRunning {
            self.task?.pause()
        }
    }
    
    func restart() {
        self.stop()
        self.start()
    }
    
    private func usageUpdater(value: Temperatures) {
        if self.widget.view is Widget {
            DispatchQueue.main.async(execute: {
                var value_1: Double = 0
                var value_2: Double = 0
                
                let v1 = value.asDictionary.first { $0.key == self.value_1 }
                let v2 = value.asDictionary.first { $0.key == self.value_2 }
                
                if v1 != nil {
                    value_1 = v1!.value as! Double
                }
                if v2 != nil {
                    value_2 = v2!.value as! Double
                }
                
                (self.widget.view as! Widget).setValue(data: [value_1, value_2])
            })
        }
    }
}
