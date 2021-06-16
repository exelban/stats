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
import Kit

public struct stats {
    var read: Int64 = 0
    var write: Int64 = 0
    
    var readBytes: Int64 = 0
    var writeBytes: Int64 = 0
}

public struct drive {
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
    
    var activity: stats = stats()
}

public class Disks {
    fileprivate let queue = DispatchQueue(label: "eu.exelban.Stats.Disk.SynchronizedArray", attributes: .concurrent)
    fileprivate var array = [drive]()
    
    public var count: Int {
        var result = 0
        self.queue.sync { result = self.array.count }
        return result
    }
    
    public func first(where predicate: (drive) -> Bool) -> drive? {
        var result: drive?
        self.queue.sync { result = self.array.first(where: predicate) }
        return result
    }
    
    public func index(where predicate: (drive) -> Bool) -> Int? {
        var result: Int?
        self.queue.sync { result = self.array.firstIndex(where: predicate) }
        return result
    }
    
    public func map<ElementOfResult>(_ transform: (drive) -> ElementOfResult?) -> [ElementOfResult] {
        var result = [ElementOfResult]()
        self.queue.sync { result = self.array.compactMap(transform) }
        return result
    }
    
    public func reversed() -> [drive] {
        var result: [drive] = []
        self.queue.sync(flags: .barrier) { result = self.array.reversed() }
        return result
    }
    
    func forEach(_ body: (drive) -> Void) {
        self.queue.sync { self.array.forEach(body) }
    }
    
    public func append( _ element: drive) {
        self.queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }
    
    public func remove(at index: Int) {
        self.queue.async(flags: .barrier) {
            self.array.remove(at: index)
        }
    }
    
    public func sort() {
        self.queue.async(flags: .barrier) {
            self.array.sort{ $1.removable }
        }
    }
    
    func updateFreeSize(_ idx: Int, newValue: Int64) {
        self.queue.async(flags: .barrier) {
            self.array[idx].free = newValue
        }
    }
    
    func updateReadWrite(_ idx: Int, read: Int64, write: Int64) {
        self.queue.async(flags: .barrier) {
            self.array[idx].activity.readBytes = read
            self.array[idx].activity.writeBytes = write
        }
    }
    
    func updateRead(_ idx: Int, newValue: Int64) {
        self.queue.async(flags: .barrier) {
            self.array[idx].activity.read = newValue
        }
    }
    
    func updateWrite(_ idx: Int, newValue: Int64) {
        self.queue.async(flags: .barrier) {
            self.array[idx].activity.write = newValue
        }
    }
}

public class Disk: Module {
    private let popupView: Popup = Popup()
    private var capacityReader: CapacityReader? = nil
    private var activityReader: ActivityReader? = nil
    private var settingsView: Settings
    private var selectedDisk: String = ""
    
    public init() {
        self.settingsView = Settings("Disk")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.capacityReader = CapacityReader()
        self.activityReader = ActivityReader()
        self.selectedDisk = Store.shared.string(key: "\(self.config.name)_disk", defaultValue: self.selectedDisk)
        
        self.capacityReader?.callbackHandler = { [unowned self] value in
            if let value = value {
                self.capacityCallback(value)
            }
        }
        self.capacityReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.activityReader?.callbackHandler = { [unowned self] value in
            if let value = value {
                self.activityCallback(value)
            }
        }
        
        self.settingsView.selectedDiskHandler = { [unowned self] value in
            self.selectedDisk = value
            self.capacityReader?.read()
        }
        self.settingsView.callback = { [unowned self] in
            self.capacityReader?.read()
        }
        
        if let reader = self.capacityReader {
            self.addReader(reader)
        }
        if let reader = self.activityReader {
            self.addReader(reader)
        }
    }
    
    public override func widgetDidSet(_ type: widget_t) {
        if type == .speed && self.capacityReader?.interval != 1 {
            self.settingsView.setUpdateInterval(value: 1)
        }
    }
    
    private func capacityCallback(_ value: Disks) {
        DispatchQueue.main.async(execute: {
            self.popupView.capacityCallback(value)
        })
        self.settingsView.setList(value)
        
        guard let d = value.first(where: { $0.mediaName == self.selectedDisk }) ?? value.first(where: { $0.root }) else {
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
            default: break
            }
        }
    }
    
    private func activityCallback(_ value: Disks) {
        DispatchQueue.main.async(execute: {
            self.popupView.activityCallback(value)
        })
        
        guard let d = value.first(where: { $0.mediaName == self.selectedDisk }) ?? value.first(where: { $0.root }) else {
            return
        }
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SpeedWidget: widget.setValue(upload: d.activity.write, download: d.activity.read)
            default: break
            }
        }
    }
}
