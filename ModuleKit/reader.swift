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

public protocol Reader_p {
    func setup() -> Void
    
    func getValue<T>() -> T
    
    func start() -> Void
    func pause() -> Void
    func stop() -> Void
}

public protocol ReaderInternal_p {
    associatedtype T
    
    var value: T? { get }
    func read() -> Void
}

open class Reader<T>: ReaderInternal_p {
    public let log: OSLog
    public var value: T?
    public var interval: Int = 1000
    public var optional: Bool = false
    
    private var readyCallback: () -> Void
    private var callbackHandler: (T?) -> Void
    private var task: Repeater?
    private var nilCallbackCounter: Int = 0
    
    public init(callback: @escaping ((T?) -> Void), ready: @escaping () -> Void) {
        self.log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "\(type(of: self)).\(T.Type.self)")
        
        self.callbackHandler = callback
        self.readyCallback = ready
        
        self.setup()
        self.read()
        
        self.task = Repeater.init(interval: .milliseconds(self.interval), observer: { _ in
            self.read()
        })
        
        os_log(.error, log: self.log, "Successfully initialized reader")
    }
    
    public func callback(_ value: T?) {
        if !self.optional {
            if self.value == nil && value != nil {
                self.readyCallback()
            } else if self.value == nil && value == nil {
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
        self.callbackHandler(value!)
    }
    
    open func read() {}
    open func setup() {}
}

extension Reader: Reader_p {
    public func getValue<T>() -> T {
        return self.value as! T
    }
    
    public func start() {
        self.task!.start()
    }
    
    public func pause() {
        self.task!.pause()
    }
    
    public func stop() {
        self.task!.removeAllObservers(thenStop: true)
    }
}
