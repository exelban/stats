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

public protocol value_t {
    var widgetValue: Double { get }
}

public protocol Reader_p {
    var optional: Bool { get }
    var popup: Bool { get }
    
    func setup()
    func read()
    func terminate()
    
    func getValue<T>() -> T
    
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
    
    public var readyCallback: () -> Void = {}
    public var callbackHandler: (T?) -> Void = {_ in }
    
    private var repeatTask: Repeater?
    private var nilCallbackCounter: Int = 0
    private var ready: Bool = false
    private var locked: Bool = true
    private var initlizalized: Bool = false
    
    private let variablesQueue = DispatchQueue(label: "eu.exelban.readerQueue")
    
    private var _active: Bool = false
    public var active: Bool {
        get {
            self.variablesQueue.sync { self._active }
        }
        set {
            self.variablesQueue.sync { self._active = newValue }
        }
    }
    
    public init(_ module: ModuleType, popup: Bool = false) {
        self.popup = popup
        
        super.init()
        self.setup()
        
        debug("Successfully initialize reader", log: self.log)
    }
    
    public func initStoreValues(title: String) {
        guard self.interval == nil else {
            return
        }
        
        let updateIntervalString = Store.shared.string(key: "\(title)_updateInterval", defaultValue: "\(self.defaultInterval)")
        if let updateInterval = Double(updateIntervalString) {
            self.interval = updateInterval
        }
    }
    
    public func callback(_ value: T?) {
        if !self.optional && !self.ready {
            if self.value == nil && value != nil {
                self.ready = true
                self.readyCallback()
                debug("Reader is ready", log: self.log)
            } else if self.value == nil && value == nil {
                if self.nilCallbackCounter > 5 {
                    error("Callback receive nil value more than 5 times. Please check this reader!", log: self.log)
                    self.stop()
                    return
                } else {
                    debug("Restarting initial read", log: self.log)
                    self.nilCallbackCounter += 1
                    self.read()
                    return
                }
            } else if self.nilCallbackCounter != 0 && value != nil {
                self.nilCallbackCounter = 0
            }
        }
        
        self.value = value
        if let value {
            self.callbackHandler(value)
        }
    }
    
    open func read() {}
    open func setup() {}
    open func terminate() {}
    
    open func start() {
        if self.popup && self.locked {
            if !self.ready {
                DispatchQueue.global(qos: .background).async {
                    self.read()
                }
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
}

extension Reader: Reader_p {
    public func getValue<T>() -> T {
        return self.value as! T
    }
    
    public func lock() {
        self.locked = true
    }
    
    public func unlock() {
        self.locked = false
    }
}
