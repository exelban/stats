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

public struct stats {
    var read: Int64 = 0
    var write: Int64 = 0
    
    var readBytes: Int64 = 0
    var writeBytes: Int64 = 0
    var readOperations: Int64 = 0
    var writeOperations: Int64 = 0
    var readTime: Int64 = 0
    var writeTime: Int64 = 0
}

struct drive {
    var parent: io_registry_entry_t = 0
    
    var mediaName: String = ""
    var BSDName: String = ""
    
    var root: Bool = false
    var removable: Bool = false
    
    var model: String = ""
    var path: URL?
    var connectionType: String = ""
    var fileSystem: String = ""
    
    var size: Int64 = 1
    var free: Int64 = 0
    
    var stats: stats? = nil
}

struct DiskList: value_t {
    var list: [drive] = []
    
    public var widget_value: Double {
        get {
            return 0
        }
    }
    
    func getDiskByBSDName(_ name: String) -> drive? {
        if let idx = self.list.firstIndex(where: { $0.BSDName == name }) {
            return self.list[idx]
        }
        
        return nil
    }
    
    func getDiskByName(_ name: String) -> drive? {
        if let idx = self.list.firstIndex(where: { $0.mediaName == name }) {
            return self.list[idx]
        }
        
        return nil
    }
    
    func getRootDisk() -> drive? {
        if let idx = self.list.firstIndex(where: { $0.root }) {
            return self.list[idx]
        }
        
        return nil
    }
    
    mutating func removeDiskByBSDName(_ name: String) {
        if let idx = self.list.firstIndex(where: { $0.BSDName == name }) {
            self.list.remove(at: idx)
        }
    }
}

public class Disk: Module {
    private let popupView: Popup = Popup()
    private var capacityReader: CapacityReader? = nil
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
        
        self.capacityReader?.callbackHandler = { [unowned self] value in
            self.capacityCallback(value)
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
    }
    
    public override func widgetDidSet(_ type: widget_t) {
        if type == .speed && self.capacityReader?.interval != 1 {
            self.settingsView.setUpdateInterval(value: 1)
        }
    }
    
    private func capacityCallback(_ raw: DiskList?) {
        guard raw != nil, let value = raw else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.popupView.usageCallback(value)
        })
        self.settingsView.setList(value)
        
        guard let d = value.getDiskByName(self.selectedDisk) ?? value.getRootDisk() else {
            return
        }
        
        let total = d.size
        let free = d.free
        var usedSpace = total - free
        if usedSpace < 0 {
            usedSpace = 0
        }
        let percentage = Double(usedSpace) / Double(total)
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini: widget.setValue(percentage)
            case let widget as BarChart: widget.setValue([percentage])
            case let widget as MemoryWidget: widget.setValue((DiskSize(free).getReadableMemory(), DiskSize(usedSpace).getReadableMemory()))
            case let widget as SpeedWidget: widget.setValue(upload: d.stats?.write ?? 0, download: d.stats?.read ?? 0)
            default: break
            }
        }
    }
}
