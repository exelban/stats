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
    var optional: Bool { get }
    var popup: Bool { get }
    
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
    public var value: T?
    public var name: String {
        String(NSStringFromClass(type(of: self)).split(separator: ".").last ?? "unknown")
    }
    
    public var interval: Double? = nil
    public var defaultInterval: Double = 1
    public var optional: Bool = false
    public var popup: Bool = false
    
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
    
    public init(_ module: ModuleType, popup: Bool = false, history: Bool = false, callback: @escaping (T?) -> Void = {_ in }) {
        self.popup = popup
        self.module = module
        self.history = history
        self.callbackHandler = callback
        
        super.init()
        DB.shared.setup(T.self, "\(module.rawValue)@\(self.name)")
        if let lastValue = DB.shared.findOne(T.self, key: "\(module.rawValue)@\(self.name)") {
            self.value = lastValue
            callback(lastValue)
        }
        self.setup()
        
        debug("Successfully initialize reader", log: self.log)
    }
    
    deinit {
        DB.shared.insert(key: "\(self.module.rawValue)@\(self.name)", value: self.value, ts: self.history)
    }
    
    public func initStoreValues(title: String) {
        guard self.interval == nil else { return }
        let updateIntervalString = Store.shared.string(key: "\(title)_updateInterval", defaultValue: "\(self.defaultInterval)")
        if let updateInterval = Double(updateIntervalString) {
            self.interval = updateInterval
        }
    }
    
    public func callback(_ value: T?) {
        self.value = value
        if let value {
            self.callbackHandler(value)
            if let ts = self.lastDBWrite, let interval = self.interval, Date().timeIntervalSince(ts) > interval * 10 {
                DB.shared.insert(key: "\(self.module.rawValue)@\(self.name)", value: value, ts: self.history)
                self.lastDBWrite = Date()
            } else if self.lastDBWrite == nil {
                DB.shared.insert(key: "\(self.module.rawValue)@\(self.name)", value: value, ts: self.history)
                self.lastDBWrite = Date()
            }
        }
    }
    
    open func read() {}
    open func setup() {}
    open func terminate() {}
    
    open func start() {
        if self.popup && self.locked {
            DispatchQueue.global(qos: .background).async {
                self.read()
            }
            return
        }
        
        if let interval = self.interval, self.repeatTask == nil {
            if !self.popup && !self.optional {
                debug("Set up update interval: \(Int(interval)) sec", log: self.log)
            }
            
            self.repeatTask = Repeater.init(seconds: Int(interval)) { [weak self] in
                self?.read()
            }
        }
        
        if !self.initlizalized {
            DispatchQueue.global(qos: .background).async {
                self.read()
            }
            self.initlizalized = true
        }
        self.repeatTask?.start()
        self.active = true
    }
    
    open func pause() {
        self.repeatTask?.pause()
        self.active = false
    }
    
    open func stop() {
        self.repeatTask?.pause()
        self.repeatTask = nil
        self.active = false
        self.initlizalized = false
    }
    
    public func setInterval(_ value: Int) {
        debug("Set update interval: \(Int(value)) sec", log: self.log)
        self.interval = Double(value)
        self.repeatTask?.reset(seconds: value, restart: true)
    }
    
    public func save(_ value: T) {
        DB.shared.insert(key: "\(self.module.rawValue)@\(self.name)", value: value, ts: self.history, force: true)
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
