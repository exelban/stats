//
//  main.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 07/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

struct diskInfo {
    var name: String = ""
    var model: String = ""
    var path: URL?
    var connection: String = ""
    var fileSystem: String = ""
    
    var totalSize: Int64 = 0
    var freeSize: Int64 = 0
    
    var mediaBSDName: String = ""
    var root: Bool = false
    
    var removable: Bool = false
}

struct DiskList: value_t {
    var list: [diskInfo] = []
    
    public var widget_value: Double {
        get {
            return 0
        }
    }
    
    func getDiskByBSDName(_ name: String) -> diskInfo? {
        if let idx = self.list.firstIndex(where: { $0.mediaBSDName == name }) {
            return self.list[idx]
        }
        
        return nil
    }
    
    func getDiskByName(_ name: String) -> diskInfo? {
        if let idx = self.list.firstIndex(where: { $0.name == name }) {
            return self.list[idx]
        }
        
        return nil
    }
    
    func getRootDisk() -> diskInfo? {
        if let idx = self.list.firstIndex(where: { $0.root }) {
            return self.list[idx]
        }
        
        return nil
    }
}

public struct IO {
    var read: Int = 0
    var write: Int = 0
}

public class Disk: Module {
    private let popupView: Popup = Popup()
    private var capacityReader: CapacityReader? = nil
    private var ioReader: IOReader? = nil
    private var settingsView: Settings
    private var selectedDisk: String = ""
    
    public init(_ store: UnsafePointer<Store>) {
        self.settingsView = Settings("Disk", store: store)
        
        super.init(
            store: store,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.capacityReader = CapacityReader()
        self.capacityReader?.store = store
        self.selectedDisk = store.pointee.string(key: "\(self.config.name)_disk", defaultValue: self.selectedDisk)
        
        self.ioReader = IOReader()
        
        self.capacityReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        self.capacityReader?.callbackHandler = { [unowned self] value in
            self.capacityCallback(value: value)
        }
        self.ioReader?.callbackHandler = { [unowned self] value in
            self.ioCallback(value: value)
        }
        
        self.settingsView.selectedDiskHandler = { [unowned self] value in
            self.selectedDisk = value
            self.capacityReader?.read()
        }
        self.settingsView.callback = { [unowned self] in
            self.capacityReader?.read()
        }
        self.settingsView.setInterval = { [unowned self] value in
            self.capacityReader?.setInterval(value)
        }
        
        if let reader = self.capacityReader {
            self.addReader(reader)
        }
        if let reader = self.ioReader {
            self.addReader(reader)
        }
    }
    
    private func capacityCallback(value: DiskList?) {
        if value == nil {
            return
        }
        self.popupView.usageCallback(value!)
        self.settingsView.setList(value!)
        
        var d: diskInfo? = value!.getDiskByName(self.selectedDisk)
        if d == nil {
            d = value!.getRootDisk()
        }
        
        if d == nil {
            return
        }
        
        let total = d!.totalSize
        let free = d!.freeSize
        let usedSpace = total - free
        let percentage = Double(usedSpace) / Double(total)
        
        if let widget = self.widget as? Mini {
            widget.setValue(percentage, sufix: "%")
        }
        if let widget = self.widget as? BarChart {
            widget.setValue([percentage])
        }
        if let widget = self.widget as? DiskWidget {
            widget.setValue((free, usedSpace))
        }
    }
    
    private func ioCallback(value: IO?) {
        if value == nil {
            return
        }
        
        if let widget = self.widget as? SpeedWidget {
            widget.setValue(upload: Int64(value!.write), download: Int64(value!.read))
        }
    }
}
