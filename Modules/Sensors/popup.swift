//
//  popup.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 22/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: NSView, Popup_p {
    private var list: [String: NSTextField] = [:]
    
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
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
        
        var types: [SensorType] = []
        values!.forEach { (s: Sensor_t) in
            if !types.contains(s.type) {
                types.append(s.type)
            }
        }
        
        self.subviews.forEach { (v: NSView) in
            v.removeFromSuperview()
        }
        
        var y: CGFloat = 0
        types.reversed().forEach { (typ: SensorType) in
            let filtered = values!.filter{ $0.type == typ }
            var groups: [SensorGroup] = []
            filtered.forEach { (s: Sensor_t) in
                if !groups.contains(s.group) {
                    groups.append(s.group)
                }
            }
            
            let height: CGFloat = CGFloat((22*filtered.count)) + Constants.Popup.separatorHeight
            let view: NSView = NSView(frame: NSRect(x: 0, y: y, width: self.frame.width, height: height))
            let separator = separatorView(localizedString(typ.rawValue), origin: NSPoint(x: 0, y: view.frame.height - Constants.Popup.separatorHeight), width: self.frame.width)
            view.addSubview(separator)
            
            var i: CGFloat = 0
            groups.reversed().forEach { (group: SensorGroup) in
                filtered.reversed().filter{ $0.group == group }.forEach { (s: Sensor_t) in
                    let (key, value) = popupRow(view, n: i, title: "\(s.name):", value: s.formattedValue)
                    key.toolTip = s.key
                    self.list[s.key] = value
                    i += 1
                }
            }
            
            self.addSubview(view)
            y += height
        }
        
        self.setFrameSize(NSSize(width: self.frame.width, height: y - Constants.Popup.margins))
        self.sizeCallback?(self.frame.size)
    }
    
    internal func usageCallback(_ values: [Sensor_t]) {
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                values.forEach { (s: Sensor_t) in
                    if self.list[s.key] != nil {
                        self.list[s.key]?.stringValue = s.formattedValue
                    }
                }
            }
        })
    }
}
