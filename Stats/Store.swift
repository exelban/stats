//
//  Store.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 29/05/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

class Store {
    let defaults = UserDefaults.standard
    
    let cpuUsage: Observable<Float>
    let memoryUsage: Observable<Float>
    let diskUsage: Observable<Float>
    
    let cpuStatus: Observable<Bool>
    let memoryStatus: Observable<Bool>
    let diskStatus: Observable<Bool>
    
    let colors: Observable<Bool>
    
    let activeWidgets: Observable<Int8>
    
    init() {
        cpuUsage = Observable(0)
        memoryUsage = Observable(0)
        diskUsage = Observable(0)
        
        cpuStatus = Observable(true)
        memoryStatus = Observable(true)
        diskStatus = Observable(true)
        
        activeWidgets = Observable(3)
        
        colors = Observable(false)
        
        if defaults.object(forKey: "cpuStatus") != nil {
            cpuStatus << defaults.bool(forKey: "cpuStatus")
        }
        if defaults.object(forKey: "memoryStatus") != nil {
            memoryStatus << defaults.bool(forKey: "memoryStatus")
        }
        if defaults.object(forKey: "diskStatus") != nil {
            diskStatus << defaults.bool(forKey: "diskStatus")
        }
        if defaults.object(forKey: "colors") != nil {
            colors << defaults.bool(forKey: "colors")
        }
        
        cpuStatus.subscribe(observer: self) { (newValue, _) in
            self.defaults.set(newValue, forKey: "cpuStatus")
        }
        memoryStatus.subscribe(observer: self) { (newValue, _) in
            self.defaults.set(newValue, forKey: "memoryStatus")
        }
        diskStatus.subscribe(observer: self) { (newValue, _) in
            self.defaults.set(newValue, forKey: "diskStatus")
        }
        
        colors.subscribe(observer: self) { (newValue, _) in
            self.defaults.set(newValue, forKey: "colors")
        }
    }
}

var store = Store()
