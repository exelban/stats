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

public class Portal: NSStackView, Portal_p {
    public var name: String
    
    private var initialized: Bool = false
    private var container: ScrollableStackView = ScrollableStackView()
    
    private var list: [String: NSView] = [:]
    
    private var unknownSensorsState: Bool {
        Store.shared.bool(key: "Sensors_unknown", defaultValue: false)
    }
    
    init(_ name: ModuleType) {
        self.name = name.rawValue
        
        super.init(frame: NSRect( x: 0, y: 0, width: Constants.Popup.width, height: Constants.Popup.portalHeight))
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 3
        
        self.orientation = .vertical
        self.distribution = .fillEqually
        self.spacing = Constants.Popup.spacing*2
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.spacing*2,
            left: Constants.Popup.spacing*2,
            bottom: Constants.Popup.spacing*2,
            right: Constants.Popup.spacing*2
        )
        
        self.container.stackView.spacing = 0
        
        self.addArrangedSubview(PortalHeader(self.name))
        self.addArrangedSubview(self.container)
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
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
        
        var width: CGFloat = self.frame.width - self.edgeInsets.left - self.edgeInsets.right
        if list.count >= 4 {
            width -= self.container.scrollWidth ?? Constants.Popup.margins
        }
        list.forEach { s in
            let v = ValueSensorView(s, width: width, callback: {})
            self.container.stackView.addArrangedSubview(v)
            self.list[s.key] = v
        }
    }
    
    public func usageCallback(_ values: [Sensor_p]) {
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                values.forEach { (s: Sensor_p) in
                    if let v = self.list[s.key] as? ValueSensorView {
                        v.update(s.formattedPopupValue)
                    }
                }
            }
        })
    }
    
}
