//
//  Module.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

protocol Module {
    var name: String { get }
    var active: Observable<Bool> { get }
    var reader: Reader { get }
    var view: NSView { get }
    
    func menu() -> NSMenuItem
    func start()
    func stop()
}

extension Module {
    func stop() {
        self.reader.stop()
        self.reader.usage.unsubscribe(observer: self as AnyObject)
    }
    
    func loadViewFromNib() -> NSView {
        var topLevelObjects: NSArray?
        if Bundle.main.loadNibNamed(NSNib.Name(String(describing: Self.self)), owner: self, topLevelObjects: &topLevelObjects) {
            return (topLevelObjects?.first(where: { $0 is NSView } ) as? NSView)!
        }
        return NSView()
    }
}

protocol Reader {
    var usage: Observable<Float>! { get }
    func start()
    func read()
    func stop()
}
