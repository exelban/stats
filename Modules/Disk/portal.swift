//
//  portal.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 20/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Portal: NSStackView, Portal_p {
    internal var name: String { Disk.name }
    
    private var circle: PieChartView? = nil
    
    private var initialized: Bool = false
    
    init() {
        super.init(frame: NSRect.zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 3
        
        self.orientation = .horizontal
        self.distribution = .fillEqually
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.margins,
            left: Constants.Popup.margins,
            bottom: Constants.Popup.margins,
            right: Constants.Popup.margins
        )
        
        self.circle = PieChartView(frame: NSRect.zero, segments: [], drawValue: true)
        self.circle!.toolTip = localizedString("Disk usage")
        self.addArrangedSubview(self.circle!)
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func loadCallback(_ value: Double) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.circle?.setValue(value)
                self.circle?.setSegments([
                    circle_segment(value: value, color: .controlAccentColor)
                ])
                self.initialized = true
            }
        })
    }
}
