//
//  portal.swift
//  RAM
//
//  Created by Serhiy Mytrovtsiy on 17/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Portal: NSStackView, Portal_p {
    public var name: String
    
    private var circle: PieChartView? = nil
    private var level: PressureView? = nil
    
    private var initialized: Bool = false
    
    private var appColorState: Color = .secondBlue
    private var appColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.appColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var wiredColorState: Color = .secondOrange
    private var wiredColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.wiredColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var compressedColorState: Color = .pink
    private var compressedColor: NSColor {
        var value = NSColor.lightGray
        if let color = self.compressedColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var freeColorState: Color = .lightGray
    private var freeColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.freeColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    init(_ name: String) {
        self.name = name
        
        super.init(frame: NSRect.zero)
        
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
        self.addArrangedSubview(PortalHeader(name))
        
        self.circle = PieChartView(frame: NSRect.zero, segments: [], drawValue: true)
        self.circle!.toolTip = localizedString("Memory usage")
        self.addArrangedSubview(self.circle!)
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func loadCallback(_ value: RAM_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.circle?.setValue(value.usage)
                self.circle?.setSegments([
                    circle_segment(value: value.app/value.total, color: self.appColor),
                    circle_segment(value: value.wired/value.total, color: self.wiredColor),
                    circle_segment(value: value.compressed/value.total, color: self.compressedColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.freeColor)
                
                self.initialized = true
            }
        })
    }
}
