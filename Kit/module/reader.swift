//
//  reader.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Reader_p {
    var popup: Bool { get }
    var preview: Bool { get }
    var sleep: Bool { get }
    
    func setup()
    func read()
    func terminate()
    
    func start()
    func pause()
    func stop()
    
    func lock()
    func unlock()
    
    func initStoreValues(title: String)
    func setInterval(_ value: Int)
    func sleepMode(state: Bool)
}

public protocol ReaderInternal_p {
    associatedtype T
    
    var value: T? { get }
    func read()
}

open class Reader<T: Codable>: NSObject, ReaderInternal_p {
    public var log: NextLog {
        NextLog.shared.copy(category: "\(String(describing: self))")
    }
    private let valueQueue = DispatchQueue(label: "eu.exelban.readerActiveQueue")
    private var _value: T?
    public var value: T? {
        get { self.valueQueue.sync { self._value } }
        set { self.valueQueue.sync { self._value = newValue } }
    }
    public var name: String {
        String(NSStringFromClass(type(of: self)).split(separator: ".").last ?? "unknown")
    }
    
    public var interval: Double? = nil
    public var defaultInterval: Int = 1
    public var optional: Bool = false
    public var popup: Bool = false
    public var preview: Bool = false
    public var sleep: Bool = false
    
    public var alignToSecondBoundary: Bool = false
    public var alignOffset: TimeInterval = 0
    
    public var callbackHandler: (T?) -> Void
    
    private let module: ModuleType
    private var history: Bool
    private var repeatTask: Repeater?
    private var locked: Bool = true
    private var initlizalized: Bool = false
    
    private let activeQueue = DispatchQueue(label: "eu.exelban.readerActiveQueue")
    private var _active: Bool = false
    public var active: Bool {
        get { self.activeQueue.sync { self._active } }
        set { self.activeQueue.sync { self._active = newValue } }
    }
    
    private var lastDBWrite: Date? = nil
    
    private var alignWorkItem: DispatchWorkItem?
    private let alignQueue = DispatchQueue(label: "eu.exelban.readerAlignQueue")
    
    public init(_ module: ModuleType, popup: Bool = false, preview: Bool = false, history: Bool = false, callback: @escaping (T?) -> Void = {_ in }) {
        self.popup = popup
        self.preview = preview
        self.module = module
        self.history = history
        self.callbackHandler = callback
        
        super.init()
        DB.shared.setup(T.self, "\(module.stringValue)@\(self.name)")
        if let lastValue = DB.shared.findOne(T.self, key: "\(module.stringValue)@\(self.name)") {
            self.value = lastValue
            callback(lastValue)
        }
        self.setup()
        
        debug("Successfully initialize reader", log: self.log)
    }
    
    deinit {
        DB.shared.insert(key: "\(self.module.stringValue)@\(self.name)", value: self.value, ts: self.history)
    }
    
    public func initStoreValues(title: String) {
        guard self.interval == nil else { return }
        let updateInterval = Store.shared.int(key: "\(title)_updateInterval", defaultValue: self.defaultInterval)
        self.interval = Double(updateInterval)
    }
    
    public func callback(_ value: T?) {
        let moduleKey = "\(self.module.stringValue)@\(self.name)"
        self.value = value
        if let value {
            self.callbackHandler(value)
            Remote.shared.send(key: moduleKey, value: value)
            if let ts = self.lastDBWrite, let interval = self.interval, Date().timeIntervalSince(ts) > interval * 10 {
                DB.shared.insert(key: moduleKey, value: value, ts: self.history)
                self.lastDBWrite = Date()
            } else if self.lastDBWrite == nil {
                DB.shared.insert(key: moduleKey, value: value, ts: self.history)
                self.lastDBWrite = Date()
            }
        }
    }
    
    open func read() {}
    open func setup() {}
    open func terminate() {}
    
    open func start() {
        if (self.popup || self.preview) && self.locked {
            DispatchQueue.global(qos: .background).async {
                self.read()
            }
            return
        }
        
        if !self.initlizalized {
            if self.alignToSecondBoundary {
                self.startAlignedRepeater()
            } else {
                self.startNormalRepeater()
                DispatchQueue.global(qos: .background).async { self.read() }
                self.repeatTask?.start()
            }
            self.initlizalized = true
        } else {
            self.repeatTask?.start()
        }
        
        self.active = true
    }
    
    open func pause() {
        self.alignWorkItem?.cancel()
        self.repeatTask?.pause()
        self.active = false
    }
    
    open func stop() {
        self.alignWorkItem?.cancel()
        self.repeatTask?.pause()
        self.repeatTask = nil
        self.active = false
        self.initlizalized = false
    }
    
    public func setInterval(_ value: Int) {
        debug("Set update interval: \(value) sec", log: self.log)
        self.interval = Double(value)
        
        if self.alignToSecondBoundary {
            self.repeatTask?.pause()
            self.repeatTask = nil
            self.alignWorkItem?.cancel()
            if self.active {
                self.startAlignedRepeater()
            }
        } else {
            self.repeatTask?.reset(seconds: value, restart: true)
        }
    }
    
    public func save(_ value: T) {
        DB.shared.insert(key: "\(self.module.stringValue)@\(self.name)", value: value, ts: self.history, force: true)
    }
    
    private func delayToNextSecondBoundary() -> TimeInterval {
        let now = Date().addingTimeInterval(self.alignOffset)
        let fractional = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0)
        let baseDelay = (fractional == 0) ? 0.0 : (1.0 - fractional)
        let safety: TimeInterval = 0.005 // 5ms past the boundary
        return baseDelay + safety
    }
    
    private func startNormalRepeater() {
        guard let interval = self.interval, self.repeatTask == nil else { return }
        
        if !self.popup && !self.preview {
            debug("Set up update interval: \(Int(interval)) sec", log: self.log)
        }
        
        self.repeatTask = Repeater(seconds: Int(interval)) { [weak self] in
            self?.read()
        }
    }
    
    private func startAlignedRepeater() {
        guard let interval = self.interval, self.repeatTask == nil else { return }
        
        if !self.popup && !self.preview {
            debug("Set up update interval: \(Int(interval)) sec (aligned)", log: self.log)
        }
        
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            
            self.read()
            self.repeatTask = Repeater(seconds: Int(interval)) { [weak self] in
                self?.read()
            }
            self.repeatTask?.start()
        }
        
        self.alignWorkItem?.cancel()
        self.alignWorkItem = work
        self.alignQueue.asyncAfter(deadline: .now() + self.delayToNextSecondBoundary(), execute: work)
    }
    
    public func sleepMode(state: Bool) {
        guard state != self.sleep else { return }

        debug("Sleep mode: \(state ? "on" : "off")", log: self.log)
        self.sleep = state

        if state {
            self.pause()
        } else {
            self.start()
        }
    }
}

extension Reader: Reader_p {
    public func lock() {
        self.locked = true
    }
    
    public func unlock() {
        self.locked = false
    }
}
