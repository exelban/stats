//
//  portal.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 16/03/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Portal: NSStackView, Portal_p {
    var name: String
    
    private let batteryView: BatteryView = BatteryView()
    private var levelField: NSTextField = ValueField(frame: NSRect.zero, "")
    private var timeField: NSTextField = ValueField(frame: NSRect.zero, "")
    
    private var initialized: Bool = false
    
    private var timeFormat: String {
        Store.shared.string(key: "\(self.name)_timeFormat", defaultValue: "short")
    }
    
    init(_ name: String) {
        self.name = name
        
        super.init(frame: NSRect.zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 3
        
        self.orientation = .vertical
        self.distribution = .fillEqually
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.margins,
            left: Constants.Popup.margins,
            bottom: Constants.Popup.margins,
            right: Constants.Popup.margins
        )
        self.spacing = 0
        
        let box: NSStackView = NSStackView()
        box.heightAnchor.constraint(equalToConstant: 13).isActive = true
        box.orientation = .horizontal
        box.spacing = 0
        
        self.levelField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        self.timeField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        box.addArrangedSubview(self.levelField)
        box.addArrangedSubview(NSView())
        box.addArrangedSubview(self.timeField)
        
        self.addArrangedSubview(self.batteryView)
        self.addArrangedSubview(box)
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func loadCallback(_ value: Battery_Usage) {
        DispatchQueue.main.async(execute: {
            self.levelField.stringValue = "\(Int(abs(value.level) * 100))%"
            
            var seconds: Double = 0
            if value.timeToEmpty != -1 && value.timeToEmpty != 0 {
                seconds = Double((value.isBatteryPowered ? value.timeToEmpty : value.timeToCharge)*60)
            }
            self.timeField.stringValue = seconds != 0 ? seconds.printSecondsToHoursMinutesSeconds(short: self.timeFormat == "short") : ""
            
            self.batteryView.setValue(abs(value.level))
            self.initialized = true
        })
    }
}
