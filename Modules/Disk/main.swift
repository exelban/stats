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

public struct stats: Codable {
    var read: Int64 = 0
    var write: Int64 = 0
    
    var readBytes: Int64 = 0
    var writeBytes: Int64 = 0
}

public struct smart_t: Codable {
    var temperature: Int = 0
    var life: Int = 0
}

public struct drive: Codable {
    var parent: io_object_t = 0
    
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
    var smart: smart_t? = nil
    
    var percentage: Double {
        let total = self.size
        let free = self.free
        var usedSpace = total - free
        if usedSpace < 0 {
            usedSpace = 0
        }
        return Double(usedSpace) / Double(total)
    }
}

public class Disks: Codable {
    private var queue: DispatchQueue = DispatchQueue(label: "eu.exelban.Stats.Disk.SynchronizedArray")
    private var _array: [drive] = []
    public var array: [drive] {
        get { self.queue.sync { self._array } }
        set { self.queue.sync { self._array = newValue } }
    }
    
    enum CodingKeys: String, CodingKey {
        case array
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.array = try container.decode(Array<drive>.self, forKey: CodingKeys.array)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(array, forKey: .array)
    }
    
    init() {}
    
    public var count: Int {
        var result = 0
        self.queue.sync { result = self.array.count }
        return result
    }
    
    // swiftlint:disable empty_count
    public var isEmpty: Bool {
        self.count == 0
    }
    // swiftlint:enable empty_count
    
    public func first(where predicate: (drive) -> Bool) -> drive? {
        return self.array.first(where: predicate)
    }
    
    public func index(where predicate: (drive) -> Bool) -> Int? {
        return self.array.firstIndex(where: predicate)
    }
    
    public func map<ElementOfResult>(_ transform: (drive) -> ElementOfResult?) -> [ElementOfResult] {
        return self.array.compactMap(transform)
    }
    
    public func reversed() -> [drive] {
        return self.array.reversed()
    }
    
    func forEach(_ body: (drive) -> Void) {
        self.array.forEach(body)
    }
    
    public func append( _ element: drive) {
        if !self.array.contains(where: {$0.BSDName == element.BSDName}) {
            self.array.append(element)
        }
    }
    
    public func remove(at index: Int) {
        self.array.remove(at: index)
    }
    
    public func sort() {
        self.array.sort{ $1.removable }
    }
    
    func updateFreeSize(_ idx: Int, newValue: Int64) {
        self.array[idx].free = newValue
    }
    
    func updateReadWrite(_ idx: Int, read: Int64, write: Int64) {
        self.array[idx].activity.readBytes = read
        self.array[idx].activity.writeBytes = write
    }
    
    func updateRead(_ idx: Int, newValue: Int64) {
        self.array[idx].activity.read = newValue
    }
    
    func updateWrite(_ idx: Int, newValue: Int64) {
        self.array[idx].activity.write = newValue
    }
    
    func updateSMARTData(_ idx: Int, smart: smart_t?) {
        self.array[idx].smart = smart
    }
}

public struct Disk_process: Process_p, Codable {
    public var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(ModuleType.disk.rawValue)_base", defaultValue: "byte")) ?? .byte
    }
    
    public var pid: Int
    public var name: String
    public var icon: NSImage {
        if let app = NSRunningApplication(processIdentifier: pid_t(self.pid)) {
            return app.icon ?? Constants.defaultProcessIcon
        }
        return Constants.defaultProcessIcon
    }
    
    var read: Int
    var write: Int
    
    init(pid: Int, name: String, read: Int, write: Int) {
        self.pid = pid
        self.name = name
        self.read = read
        self.write = write
        
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            if let name = app.localizedName {
                self.name = name
            }
        }
    }
}

public class Disk: Module {
    private let popupView: Popup = Popup(.disk)
    private let settingsView: Settings = Settings(.disk)
    private let portalView: Portal = Portal(.disk)
    private let notificationsView: Notifications = Notifications(.disk)
    
    private var capacityReader: CapacityReader?
    private var activityReader: ActivityReader?
    private var processReader: ProcessReader?
    
    private var selectedDisk: String = ""
    
    public init() {
        super.init(
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView,
            notifications: self.notificationsView
        )
        guard self.available else { return }
        
        self.capacityReader = CapacityReader(.disk) { [weak self] value in
            if let value {
                self?.capacityCallback(value)
            }
        }
        self.activityReader = ActivityReader(.disk) { [weak self] value in
            if let value {
                self?.activityCallback(value)
            }
        }
        self.processReader = ProcessReader(.disk) { [weak self] value in
            if let list = value {
                self?.popupView.processCallback(list)
            }
        }
        
        self.selectedDisk = Store.shared.string(key: "\(ModuleType.disk.rawValue)_disk", defaultValue: self.selectedDisk)
        
        self.settingsView.selectedDiskHandler = { [weak self] value in
            self?.selectedDisk = value
            self?.capacityReader?.read()
        }
        self.settingsView.callback = { [weak self] in
            self?.capacityReader?.read()
        }
        self.settingsView.setInterval = { [weak self] value in
            self?.capacityReader?.setInterval(value)
        }
        self.settingsView.callbackWhenUpdateNumberOfProcesses = { [weak self] in
            self?.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self?.processReader?.read()
            }
        }
        
        self.setReaders([self.capacityReader, self.activityReader, self.processReader])
    }
    
    public override func widgetDidSet(_ type: widget_t) {
        if type == .speed && self.capacityReader?.interval != 1 {
            self.settingsView.setUpdateInterval(value: 1)
        }
    }
    
    private func capacityCallback(_ value: Disks) {
        guard self.enabled else { return }
        
        DispatchQueue.main.async(execute: {
            self.popupView.capacityCallback(value)
        })
        self.settingsView.setList(value)
        
        guard let d = value.first(where: { $0.mediaName == self.selectedDisk }) ?? value.first(where: { $0.root }) else {
            return
        }
        
        self.portalView.utilizationCallback(d)
        self.notificationsView.utilizationCallback(d.percentage)
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as Mini: widget.setValue(d.percentage)
            case let widget as BarChart: widget.setValue([[ColorValue(d.percentage)]])
            case let widget as MemoryWidget:
                widget.setValue((DiskSize(d.free).getReadableMemory(), DiskSize(d.size - d.free).getReadableMemory()), usedPercentage: d.percentage)
            case let widget as PieChart:
                widget.setValue([
                    circle_segment(value: d.percentage, color: NSColor.systemBlue)
                ])
            default: break
            }
        }
    }
    
    private func activityCallback(_ value: Disks) {
        guard self.enabled else { return }
        
        DispatchQueue.main.async(execute: {
            self.popupView.activityCallback(value)
        })
        
        guard let d = value.first(where: { $0.mediaName == self.selectedDisk }) ?? value.first(where: { $0.root }) else {
            return
        }
        
        self.portalView.activityCallback(d)
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SpeedWidget: widget.setValue(upload: d.activity.write, download: d.activity.read)
            case let widget as NetworkChart: widget.setValue(upload: Double(d.activity.write), download: Double(d.activity.read))
            default: break
            }
        }
    }
}
