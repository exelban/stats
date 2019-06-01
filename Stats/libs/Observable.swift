//
//  Observable.swift
//  Mini Stats
//
//  Created by Serhiy Mytrovtsiy on 29/05/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

protocol ObservableProtocol {
    associatedtype T
    var value: T { get set }
    func subscribe(observer: AnyObject, block: @escaping (_ newValue: T, _ oldValue: T) -> ())
    func unsubscribe(observer: AnyObject)
    func userDefaults(key: String)
}

public final class Observable<T>: ObservableProtocol {
    typealias ObserverBlock = (_ newValue: T, _ oldValue: T) -> ()
    typealias ObserversEntry = (observer: AnyObject, block: ObserverBlock)
    private var observers: Array<ObserversEntry>
    private let defaults = UserDefaults.standard
    private var userDefaultsKey: String = ""
    
    init(_ value: T) {
        self.value = value
        observers = []
    }
    
    var value: T {
        didSet {
            observers.forEach { (entry: ObserversEntry) in
                let (_, block) = entry
                block(value, oldValue)
            }
            updateUserDefaults()
        }
    }
    
    func subscribe(observer: AnyObject, block: @escaping ObserverBlock) {
        let entry: ObserversEntry = (observer: observer, block: block)
        observers.append(entry)
    }
    
    func unsubscribe(observer: AnyObject) {
        let filtered = observers.filter { entry in
            let (owner, _) = entry
            return owner !== observer
        }
        
        observers = filtered
    }
    
    func userDefaults(key: String) {
        self.userDefaultsKey = key
    }
    
    func updateUserDefaults() {
        self.defaults.set(self.value, forKey: self.userDefaultsKey)
    }
}

func <<<T>(observable: Observable<T>, value: T) {
    observable.value = value
}
