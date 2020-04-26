//
//  Network.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

class Network: Module {
    public var name: String = "Network"
    public var updateInterval: Double = 1
    
    public var enabled: Bool = true
    public var available: Bool = true
    
    public var readers: [Reader] = []
    public var task: Repeater?
    
    public var widget: ModuleWidget = ModuleWidget()
    public var popup: ModulePopup = ModulePopup(true)
    public var menu: NSMenuItem = NSMenuItem()
    
    internal let defaults = UserDefaults.standard
    internal var submenu: NSMenu = NSMenu()
    internal var chart: LineChartView = LineChartView()
    
    internal var publicIPValue: NSTextField = NSTextField()
    internal var localIPValue: NSTextField = NSTextField()
    internal var networkValue: NSTextField = NSTextField()
    internal var physicalValue: NSTextField = NSTextField()
    internal var downloadValue: NSTextField = NSTextField()
    internal var uploadValue: NSTextField = NSTextField()
    internal var totalDownloadValue: NSTextField = NSTextField()
    internal var totalUploadValue: NSTextField = NSTextField()
    
    init() {
        if !self.available { return }
        
        self.enabled = defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true
        self.widget.type = defaults.object(forKey: "\(name)_widget") != nil ? defaults.float(forKey: "\(name)_widget") : Widgets.NetworkDots
        
        self.initWidget()
        self.initMenu()
        self.initPopup()
        
        readers.append(NetworkReader(self.usageUpdater))
        readers.append(NetworkInterfaceReader(self.overviewUpdater))

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
    
    private func usageUpdater(value: NetworkUsage) {
        self.dataUpdater(value: value)
        self.chartUpdater(value: value)
        
        if self.widget.view is Widget {
            (self.widget.view as! Widget).setValue(data: [Double(value.download), Double(value.upload)])
        }
    }
}
