//
//  store.swift
//  Kit
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
    private var cache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "eu.exelban.Stats.Store.cache", attributes: .concurrent)
    
    public init() {
        self.loadCache()
    }
    
    private func loadCache() {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let domain = self.defaults.persistentDomain(forName: bundleId) else { return }
        self.cache = domain
    }
    
    private func getValue<T>(for key: String, type: T.Type) -> T? {
        return self.cacheQueue.sync {
            return self.cache[key] as? T
        }
    }
    
    private func setValue(_ value: Any?, for key: String) {
        self.cacheQueue.async(flags: .barrier) {
            self.cache[key] = value
        }
        
        if let value = value {
            self.defaults.set(value, forKey: key)
        } else {
            self.defaults.removeObject(forKey: key)
        }
    }
    
    public func exist(key: String) -> Bool {
        return self.cacheQueue.sync {
            self.cache.keys.contains(key) || self.defaults.object(forKey: key) != nil
        }
    }
    
    public func remove(_ key: String) {
        self.setValue(nil, for: key)
    }
    
    public func bool(key: String, defaultValue value: Bool) -> Bool {
        return self.getValue(for: key, type: Bool.self) ?? value
    }
    
    public func string(key: String, defaultValue value: String) -> String {
        return self.getValue(for: key, type: String.self) ?? value
    }
    
    public func int(key: String, defaultValue value: Int) -> Int {
        return self.getValue(for: key, type: Int.self) ?? value
    }
    
    public func array(key: String, defaultValue value: [Any]) -> [Any] {
        return self.getValue(for: key, type: [Any].self) ?? value
    }
    
    public func data(key: String) -> Data? {
        return self.getValue(for: key, type: Data.self)
    }
    
    public func set(key: String, value: Bool) {
        self.setValue(value, for: key)
    }
    
    public func set(key: String, value: String) {
        self.setValue(value, for: key)
    }
    
    public func set(key: String, value: Int) {
        self.setValue(value, for: key)
    }
    
    public func set(key: String, value: Data) {
        self.setValue(value, for: key)
    }
    
    public func set(key: String, value: [Any]) {
        self.setValue(value, for: key)
    }
    
    public func reset() {
        self.cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
        
        self.defaults.dictionaryRepresentation().keys.forEach { key in
            self.defaults.removeObject(forKey: key)
        }
    }
    
    public func export(to url: URL) {
        guard let id = Bundle.main.bundleIdentifier,
              var dictionary = self.defaults.persistentDomain(forName: id) else { return }
        dictionary.removeValue(forKey: "remote_id")
        dictionary.removeValue(forKey: "access_token")
        dictionary.removeValue(forKey: "refresh_token")
        NSDictionary(dictionary: dictionary).write(to: url, atomically: true)
    }
    
    public func `import`(from url: URL) {
        guard let id = Bundle.main.bundleIdentifier,
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return }
        
        let keysToPreserve = ["remote_id", "access_token", "refresh_token"]
        var importedDict = dict
        
        for key in keysToPreserve {
            if let existingValue = getValue(for: key, type: String.self) {
                importedDict[key] = existingValue
            }
        }
        
        self.cacheQueue.async(flags: .barrier) {
            self.cache = importedDict
        }
        
        self.defaults.setPersistentDomain(importedDict, forName: id)
        restartApp(self)
    }
}
