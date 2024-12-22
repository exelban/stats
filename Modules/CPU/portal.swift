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

public class Portal: PortalWrapper {
    private var circle: PieChartView? = nil
    private var barChart: BarChartView? = nil
    
    private var initialized: Bool = false
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var shedulerLimitField: NSTextField? = nil
    private var speedLimitField: NSTextField? = nil
    private var eCoresField: NSTextField? = nil
    private var pCoresField: NSTextField? = nil
    private var average1Field: NSTextField? = nil
    private var average5Field: NSTextField? = nil
    private var average15Field: NSTextField? = nil
    
    private var systemColorView: NSView? = nil
    private var userColorView: NSView? = nil
    private var idleColorView: NSView? = nil
    private var eCoresColorView: NSView? = nil
    private var pCoresColorView: NSView? = nil
    
    private var systemColorState: SColor = .secondRed
    private var systemColor: NSColor { self.systemColorState.additional as? NSColor ?? NSColor.systemRed }
    private var userColorState: SColor = .secondBlue
    private var userColor: NSColor { self.userColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var idleColorState: SColor = .lightGray
    private var idleColor: NSColor { self.idleColorState.additional as? NSColor ?? NSColor.lightGray }
    private var eCoresColorState: SColor = .teal
    private var eCoresColor: NSColor { self.eCoresColorState.additional as? NSColor ?? NSColor.systemTeal }
    private var pCoresColorState: SColor = .indigo
    private var pCoresColor: NSColor { self.pCoresColorState.additional as? NSColor ?? NSColor.systemBlue }
    
    public override func load() {
        self.loadColors()
        
        let view = NSStackView()
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        view.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Popup.spacing*2,
            bottom: 0,
            right: Constants.Popup.spacing*2
        )
        
        let chartsView = self.charts()
        let detailsView = self.details()
        
        view.addArrangedSubview(chartsView)
        view.addArrangedSubview(detailsView)
        
        self.addArrangedSubview(view)
        
        chartsView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        detailsView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
    }
    
    public func loadColors() {
        self.systemColorState = SColor.fromString(Store.shared.string(key: "\(self.name)_systemColor", defaultValue: self.systemColorState.key))
        self.userColorState = SColor.fromString(Store.shared.string(key: "\(self.name)_userColor", defaultValue: self.userColorState.key))
        self.idleColorState = SColor.fromString(Store.shared.string(key: "\(self.name)_idleColor", defaultValue: self.idleColorState.key))
        self.eCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.name)_eCoresColor", defaultValue: self.eCoresColorState.key))
        self.pCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.name)_pCoresColor", defaultValue: self.pCoresColorState.key))
    }
    
    private func charts() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        let circle = PieChartView(frame: NSRect.zero, segments: [], drawValue: true)
        circle.toolTip = localizedString("CPU usage")
        self.circle = circle
        view.addArrangedSubview(circle)
        
        if let cores = SystemKit.shared.device.info.cpu?.logicalCores {
            let barChartContainer: NSView = {
                let box: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 24))
                box.heightAnchor.constraint(equalToConstant: box.frame.height).isActive = true
                box.wantsLayer = true
                box.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
                box.layer?.cornerRadius = 3
                
                let chart = BarChartView(num: Int(cores))
                self.barChart = chart
                box.addArrangedSubview(chart)
                
                return box
            }()
            view.addArrangedSubview(barChartContainer)
        }
        
        return view
    }
    
    private func details() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        (self.systemColorView, self.systemField) = portalWithColorRow(view, color: self.systemColor, title: "\(localizedString("System")):")
        (self.userColorView, self.userField) = portalWithColorRow(view, color: self.userColor, title: "\(localizedString("User")):")
        (self.idleColorView, self.idleField) = portalWithColorRow(view, color: self.idleColor.withAlphaComponent(0.5), title: "\(localizedString("Idle")):")
        
        if SystemKit.shared.device.info.cpu?.eCores != nil {
            (self.eCoresColorView, self.eCoresField) = portalWithColorRow(view, color: self.eCoresColor, title: "E-cores:")
        }
        if SystemKit.shared.device.info.cpu?.pCores != nil {
            (self.pCoresColorView, self.pCoresField) = portalWithColorRow(view, color: self.pCoresColor, title: "P-cores:")
        }
        
        return view
    }
    
    internal func callback(_ value: CPU_Load) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
                self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
                self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
                
                self.circle?.setValue(value.totalUsage)
                self.circle?.setSegments([
                    circle_segment(value: value.systemLoad, color: self.systemColor),
                    circle_segment(value: value.userLoad, color: self.userColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.idleColor)
                
                if let field = self.eCoresField, let usage = value.usageECores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                if let field = self.pCoresField, let usage = value.usagePCores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                
                var usagePerCore: [ColorValue] = []
                if let cores = SystemKit.shared.device.info.cpu?.cores, cores.count == value.usagePerCore.count {
                    for i in 0..<value.usagePerCore.count {
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: cores[i].type == .efficiency ? self.eCoresColor : self.pCoresColor))
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
