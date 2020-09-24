//
//  store.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class Store {
    public static let shared = Store()
    private let defaults = UserDefaults.standard
    
    public init() {}
    
    public func exist(key: String) -> Bool {
        return self.defaults.object(forKey: key) == nil ? false : true
    }
    
    public func remove(_ key: String) {
        self.defaults.removeObject(forKey: key)
    }
    
    public func bool(key: String, defaultValue value: Bool) -> Bool {
        return !self.exist(key: key) ? value : defaults.bool(forKey: key)
    }
    
    public func string(key: String, defaultValue value: String) -> String {
        return (!self.exist(key: key) ? value : defaults.string(forKey: key))!
    }
    
    public func int(key: String, defaultValue value: Int) -> Int {
        return (!self.exist(key: key) ? value : defaults.integer(forKey: key))
    }
    
    public func set(key: String, value: Bool) {
        self.defaults.set(value, forKey: key)
    }
    
    public func set(key: String, value: String) {
        self.defaults.set(value, forKey: key)
    }
    
    public func reset() {
        self.defaults.dictionaryRepresentation().keys.forEach { key in
            self.defaults.removeObject(forKey: key)
        }
    }
}
