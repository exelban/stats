//
//  portal.swift
//  CPU
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
    private var barChart: BarChartView? = nil
    
    private var initialized: Bool = false
    
    private var systemColorState: Color = .secondRed
    private var systemColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.systemColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var userColorState: Color = .secondBlue
    private var userColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.userColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var idleColorState: Color = .lightGray
    private var idleColor: NSColor {
        var value = NSColor.lightGray
        if let color = self.idleColorState.additional as? NSColor {
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
        
        let circle = PieChartView(frame: NSRect.zero, segments: [], drawValue: true)
        circle.toolTip = localizedString("CPU usage")
        self.circle = circle
        self.addArrangedSubview(circle)
        
        if let cores = SystemKit.shared.device.info.cpu?.logicalCores {
            let barChartContainer: NSView = {
                let box: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 30))
                box.heightAnchor.constraint(equalToConstant: box.frame.height).isActive = true
                box.wantsLayer = true
                box.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
                box.layer?.cornerRadius = 3
                
                let chart = BarChartView(frame: NSRect(
                    x: Constants.Popup.spacing,
                    y: Constants.Popup.spacing,
                    width: Constants.Popup.width/2 - (Constants.Popup.spacing*2),
                    height: box.frame.height - (Constants.Popup.spacing*2)
                ), num: Int(cores))
                self.barChart = chart
                
                box.addArrangedSubview(chart)
                
                return box
            }()
            self.addArrangedSubview(barChartContainer)
        }
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func loadCallback(_ value: CPU_Load) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.circle?.setValue(value.totalUsage)
                self.circle?.setSegments([
                    circle_segment(value: value.systemLoad, color: self.systemColor),
                    circle_segment(value: value.userLoad, color: self.userColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.idleColor)
                
                var usagePerCore: [ColorValue] = []
                if let cores = SystemKit.shared.device.info.cpu?.cores, cores.count == value.usagePerCore.count {
                    for i in 0..<value.usagePerCore.count {
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: cores[i].type == .efficiency ? NSColor.systemTeal : NSColor.systemBlue))
                    }
                } else {
                    for i in 0..<value.usagePerCore.count {
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: NSColor.systemBlue))
                    }
                }
                self.barChart?.setValues(usagePerCore)
                
                self.initialized = true
            }
        })
    }
}
