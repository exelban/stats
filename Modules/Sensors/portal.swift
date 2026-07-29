//
//  portal.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 14/01/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import AppKit
import Kit

public class Portal: PortalWrapper {
    private var container: ScrollableStackView = ScrollableStackView()
    
    private var list: [String: NSView] = [:]
    
    private var unknownSensorsState: Bool {
        Store.shared.bool(key: "Sensors_unknown", defaultValue: false)
    }
    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "Sensors_popup_fanValue", defaultValue: FanValue.percentage.rawValue)) ?? .percentage
    }
    
    public override func load() {
        self.container.stackView.spacing = 0
        self.body.addArrangedSubview(self.container)
    }
    
    public func setup(_ values: [Sensor_p]? = nil) {
        guard var list = values else { return }
        list = list.filter{ $0.popupState }
        if !self.unknownSensorsState {
            list = list.filter({ $0.group != .unknown })
        }
        
        if !self.list.isEmpty {
            self.container.stackView.subviews.forEach({ $0.removeFromSuperview() })
            self.list = [:]
        }
        
        var width: CGFloat = Constants.Popup.width - self.body.edgeInsets.left - self.body.edgeInsets.right
        if list.count >= 4 {
            width -= self.container.scrollWidth ?? Constants.Popup.margins
        }
        list.forEach { s in
            let v = ValueSensorView(s, width: width, callback: {})
            v.update(self.formattedValue(s))
            self.container.stackView.addArrangedSubview(v)
            self.list[s.key] = v
        }
    }
    
    public func usageCallback(_ values: [Sensor_p]) {
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                values.forEach { (s: Sensor_p) in
                    if let v = self.list[s.key] as? ValueSensorView {
                        v.update(self.formattedValue(s))
                    }
                }
            }
        })
    }
    
    private func formattedValue(_ sensor: Sensor_p) -> String {
        if let fan = sensor as? Fan {
            return self.fanValueState == .percentage ? "\(fan.percentage)%" : fan.formattedValue
        }
        return sensor.formattedPopupValue
    }
}
