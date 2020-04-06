//
//  Sensors.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class Sensors: Module {
    public var name: String = "Sensors"
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
    
    internal var value_1: String = "TC0P"
    internal var value_2: String = "TG0D"
    internal var once: Int = 0
    
    internal var sensors: Sensors_t = Sensors_t()
    
    init() {
        if !self.available { return }
        
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Sensors
        self.value_1 = (defaults.object(forKey: "\(name)_value_1") != nil ? defaults.string(forKey: "\(name)_value_1")! : value_1)
        self.value_2 = (defaults.object(forKey: "\(name)_value_2") != nil ? defaults.string(forKey: "\(name)_value_2")! : value_2)
        
        self.initWidget()
        self.initMenu()

        if self.enabled {
            self.update()
        }
        
        self.task = Repeater.init(interval: .seconds(self.updateInterval), observer: { _ in
            if self.enabled {
                self.update()
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
    
    private func update() {
        var value_1: Double = 0
        var value_2: Double = 0
        
        var sensor_1: Sensor_t? = self.sensors.find(byKey: self.value_1)
        var sensor_2: Sensor_t? = self.sensors.find(byKey: self.value_2)
        
        if sensor_1 != nil {
            sensor_1!.update()
            if sensor_1!.value != nil {
                value_1 = sensor_1!.value!
            }
        }
        if sensor_2 != nil {
            sensor_2!.update()
            if sensor_2!.value != nil {
                value_2 = sensor_2!.value!
            }
        }

        DispatchQueue.main.async(execute: {
            (self.widget.view as! Widget).setValue(data: [value_1, value_2])
        })
    }
}
