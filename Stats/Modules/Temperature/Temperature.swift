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
    
    internal var cpu: String = SMC_TEMP_CPU_0_PROXIMITY
    internal var gpu: String = SMC_TEMP_GPU_0_PROXIMITY
    
    init() {
        if !self.available { return }
        
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.Temperature
        self.cpu = (defaults.object(forKey: "\(name)_cpu") != nil ? defaults.string(forKey: "\(name)_cpu") : cpu)!
        self.gpu = (defaults.object(forKey: "\(name)_gpu") != nil ? defaults.string(forKey: "\(name)_gpu") : gpu)!
        
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
    
    private func usageUpdater(value: TemperatureValue) {
        if self.widget.view is Widget {
            DispatchQueue.main.async(execute: {
                let cpu: Double = self.cpu == SMC_TEMP_CPU_0_DIE ? value.CPUDie : value.CPUProximity
                let gpu: Double = self.gpu == SMC_TEMP_GPU_0_DIODE ? value.GPUDie : value.GPUProximity
                
                (self.widget.view as! Widget).setValue(data: [cpu, gpu])
            })
        }
    }
}
