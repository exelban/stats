//
//  popup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 22/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSView {
    private var list: [String: NSTextField] = [:]
    
    public init() {
        super.init(frame: NSRect( x: 0, y: 0, width: Constants.Popup.width, height: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func setup(_ values: [Sensor_t]?) {
        guard values != nil else {
            return
        }
        
        var types: [SensorType_t: Int] = [:]
        values!.forEach { (s: Sensor_t) in
            types[s.type] = (types[s.type] ?? 0) + 1
        }
        
        self.subviews.forEach { (v: NSView) in
            v.removeFromSuperview()
        }
        
        var y: CGFloat = 0
        types.sorted{ $0.1 < $1.1 }.forEach { (t: (key: SensorType_t, value: Int)) in
            let filtered = values!.filter{ $0.type == t.key }
            var groups: [SensorGroup_t: Int] = [:]
            filtered.forEach { (s: Sensor_t) in
                groups[s.group] = (groups[s.group] ?? 0) + 1
            }
            
            let height: CGFloat = CGFloat((22*filtered.count)) + Constants.Popup.separatorHeight
            
            let view: NSView = NSView(frame: NSRect(x: 0, y: y, width: self.frame.width, height: height))
            let separator = SeparatorView(t.key, origin: NSPoint(x: 0, y: view.frame.height - Constants.Popup.separatorHeight), width: self.frame.width)
            view.addSubview(separator)
            
            var i: CGFloat = 0
            groups.sorted{ $0.1 < $1.1 }.forEach { (g: (key: SensorGroup_t, value: Int)) in
                filtered.reversed().filter{ $0.group == g.key }.forEach { (s: Sensor_t) in
                    print(s.name)
                    self.list[s.key] = PopupRow(view, n: i, title: "\(s.name):", value: s.formattedValue)
                    i += 1
                }
            }
            
            self.addSubview(view)
            y += height
        }
        
        self.setFrameSize(NSSize(width: self.frame.width, height: y - Constants.Popup.margins))
    }
    
    internal func usageCallback(_ values: [Sensor_t]) {
        values.forEach { (s: Sensor_t) in
            if self.list[s.key] != nil {
                DispatchQueue.main.async(execute: {
                    if self.window!.isVisible {
                        self.list[s.key]?.stringValue = s.formattedValue
                    }
                })
            }
        }
    }
}
