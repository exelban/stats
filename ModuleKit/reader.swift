//
//  reader.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Repeat
import os.log
import StatsKit

public protocol value_t {
    var widget_value: Double { get }
}

public protocol Reader_p {
    var optional: Bool { get }
    var popup: Bool { get }
    
    func setup() -> Void
    func read() -> Void
    func terminate() -> Void
    
    func getValue<T>() -> T
    func getHistory() -> [value_t]
    
    func start() -> Void
    func pause() -> Void
    func stop() -> Void
    
    func lock() -> Void
    func unlock() -> Void
    
    func initStoreValues(title: String, store: UnsafePointer<Store>) -> Void
    func setInterval(_ value: Int) -> Void
}

public protocol ReaderInternal_p {
    associatedtype T
    
    var value: T? { get }
    func read() -> Void
}

open class Reader<T>: ReaderInternal_p {
    public var log: OSLog
    public var value: T?
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
    public var active: Bool = false
    
    private var history: [T]? = []
    
    public init() {
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "\(T.self)")
        
        self.setup()
        
        os_log(.debug, log: self.log, "Successfully initialize reader")
    }
    
    public func initStoreValues(title: String, store: UnsafePointer<Store>) {
        guard self.interval == nil else {
            return
        }
        
        let updateIntervalString = store.pointee.string(key: "\(title)_updateInterval", defaultValue: "\(self.defaultInterval)")
        if let updateInterval = Double(updateIntervalString) {
            self.interval = updateInterval
        }
    }
    
    public func callback(_ value: T?) {
        if !self.optional && !self.ready {
            if self.value == nil && value != nil {
                self.ready = true
                self.readyCallback()
                os_log(.debug, log: self.log, "Reader is ready")
            } else if self.value == nil && value != nil {
                if self.nilCallbackCounter > 5 {
                    os_log(.error, log: self.log, "Callback receive nil value more than 5 times. Please check this reader!")
                    self.stop()
                    return
                } else {
                    os_log(.debug, log: self.log, "Restarting initial read")
                    self.nilCallbackCounter += 1
                    self.read()
                    return
                }
            } else if self.nilCallbackCounter != 0 && value != nil {
                self.nilCallbackCounter = 0
            }
        }
        
        self.value = value
        if value != nil {
            if self.history?.count ?? 0 >= 300 {
                self.history!.remove(at: 0)
            }
            self.history?.append(value!)
            self.callbackHandler(value!)
        }
    }
    
    open func read() {}
    open func setup() {}
    open func terminate() {}
    
    open func start() {
        if self.popup && self.locked {
            if !self.ready {
                DispatchQueue.global().async {
                    self.read()
                }
            }
            return
        }
        
        if let interval = self.interval, self.repeatTask == nil {
            if !self.popup && !self.optional {
                os_log(.debug, log: self.log, "Set up update interval: %.0f sec", interval)
            }
            
            self.repeatTask = Repeater.init(interval: .seconds(interval), observer: { _ in
                self.read()
            })
        }

        DispatchQueue.global().async {
            self.read()
        }
        self.repeatTask?.start()
        self.active = true
    }
    
    open func pause() {
        self.repeatTask?.pause()
        self.active = false
    }
    
    open func stop() {
        self.repeatTask?.removeAllObservers(thenStop: true)
        self.repeatTask = nil
        self.active = false
    }
    
    public func setInterval(_ value: Int) {
        os_log(.debug, log: self.log, "Set update interval: %d sec", value)
        self.repeatTask?.reset(.seconds(Double(value)), restart: true)
    }
}

extension Reader: Reader_p {
    public func getValue<T>() -> T {
        return self.value as! T
    }
    
    public func getHistory<T>() -> [T] {
        return self.history as! [T]
    }
    
    public func lock() {
        self.locked = true
    }
    
    public func unlock() {
        self.locked = false
    }
}
