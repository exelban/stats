//
//  TemperatureMenu.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

extension Temperature {
    public func initMenu() {
        menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        submenu = NSMenu()
        
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        
        let cpuDie: NSMenuItem = NSMenuItem(title: "CPU Die", action: #selector(toggleCPU), keyEquivalent: "")
        cpuDie.state = self.cpu == SMC_TEMP_CPU_0_DIE ? NSControl.StateValue.on : NSControl.StateValue.off
        cpuDie.target = self
        
        let cpuProximity: NSMenuItem = NSMenuItem(title: "CPU Proximity", action: #selector(toggleCPU), keyEquivalent: "")
        cpuProximity.state = self.cpu == SMC_TEMP_CPU_0_PROXIMITY ? NSControl.StateValue.on : NSControl.StateValue.off
        cpuProximity.target = self
        
        let gpuDie: NSMenuItem = NSMenuItem(title: "GPU Die", action: #selector(toggleGPU), keyEquivalent: "")
        gpuDie.state = self.gpu == SMC_TEMP_GPU_0_DIODE ? NSControl.StateValue.on : NSControl.StateValue.off
        gpuDie.target = self
        
        let gpuProximity: NSMenuItem = NSMenuItem(title: "GPU Proximity", action: #selector(toggleGPU), keyEquivalent: "")
        gpuProximity.state = self.gpu == SMC_TEMP_GPU_0_PROXIMITY ? NSControl.StateValue.on : NSControl.StateValue.off
        gpuProximity.target = self
        
        submenu.addItem(cpuProximity)
        submenu.addItem(cpuDie)
        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(gpuProximity)
        submenu.addItem(gpuDie)
        
        submenu.addItem(NSMenuItem.separator())
        
        if let view = self.widget.view as? Widget {
            for widgetMenu in view.menus {
                submenu.addItem(widgetMenu)
            }
        }
        
        if self.enabled {
            menu.submenu = submenu
        }
    }
    
    @objc func toggle(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: name)
        self.enabled = state
        menuBar!.reload(name: self.name)
        
        if !state {
            menu.submenu = nil
        } else {
            menu.submenu = submenu
        }
        
        self.restart()
    }
    
    @objc func toggleCPU(_ sender: NSMenuItem) {
        var cpu: String = sender.title
        
        switch cpu {
        case "CPU Die":
            cpu = SMC_TEMP_CPU_0_DIE
        case "CPU Proximity":
            cpu = SMC_TEMP_CPU_0_PROXIMITY
        default:
            break
        }
        
        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            if item.title == "CPU Die" || item.title == "CPU Proximity" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(cpu, forKey: "\(name)_cpu")
        self.cpu = cpu
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
    
    @objc func toggleGPU(_ sender: NSMenuItem) {
        var gpu: String = sender.title
        
        switch gpu {
        case "GPU Die":
            gpu = SMC_TEMP_GPU_0_DIODE
        case "GPU Proximity":
            gpu = SMC_TEMP_GPU_0_PROXIMITY
        default:
            break
        }
        
        let state = sender.state == NSControl.StateValue.on
        for item in self.submenu.items {
            if item.title == "GPU Die" || item.title == "GPU Proximity" {
                item.state = NSControl.StateValue.off
            }
        }
        
        sender.state = state ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(gpu, forKey: "\(name)_gpu")
        self.gpu = gpu
        self.initWidget()
        self.initMenu()
        menuBar!.reload(name: self.name)
    }
}
