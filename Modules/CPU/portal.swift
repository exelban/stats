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
    private var circle: PieChartView = PieChartView(drawValue: true)
    private var columnChart: ColumnChartView? = nil
    
    private var initialized: Bool = false
    
    private var usageField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var eCoresField: NSTextField? = nil
    private var pCoresField: NSTextField? = nil
    private var sCoresField: NSTextField? = nil
    
    private var systemColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_systemColor", defaultValue: SColor.secondRed.key)).additional as! NSColor
    }
    private var userColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_userColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var idleColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_idleColor", defaultValue: SColor.lightGray.key)).additional as! NSColor
    }
    private var eCoresColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_eCoresColor", defaultValue: SColor.teal.key)).additional as! NSColor
    }
    private var pCoresColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_pCoresColor", defaultValue: SColor.indigo.key)).additional as! NSColor
    }
    private var sCoresColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_sCoresColor", defaultValue: SColor.orange.key)).additional as! NSColor
    }
    
    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        
        let container = NSStackView()
        container.orientation = .horizontal
        container.distribution = .fillEqually
        container.spacing = Constants.Popup.spacing*2
        
        let circle: NSView = self.circleView()
        let details: NSView = self.detailsView()
        
        container.addArrangedSubview(circle)
        container.addArrangedSubview(details)
        
        self.body.addArrangedSubview(container)
        
        if let cores = SystemKit.shared.device.info.cpu?.logicalCores {
            let chart = ColumnChartView(num: Int(cores))
            self.columnChart = chart
            self.body.addArrangedSubview(chart)
        }
    }
    
    private func circleView() -> NSView {
        let view = NSStackView()
        
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        view.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        view.addArrangedSubview(self.circle)
        
        return view
    }
    
    private func detailsView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        (_, self.usageField, _) = portalRow(view, title: "\(localizedString("Usage")):")
        (_, self.idleField, _) = portalRow(view, title: "\(localizedString("Idle")):")
        
        if SystemKit.shared.device.info.cpu?.eCores != nil {
            (_, self.eCoresField) = portalWithColorRow(view, color: self.eCoresColor, title: "E-cores:")
        }
        if SystemKit.shared.device.info.cpu?.pCores != nil {
            (_, self.pCoresField) = portalWithColorRow(view, color: self.pCoresColor, title: "P-cores:")
        }
        if SystemKit.shared.device.info.cpu?.sCores != nil {
            (_, self.sCoresField) = portalWithColorRow(view, color: self.sCoresColor, title: "S-cores:")
        }
        
        return view
    }
    
    internal func callback(_ value: CPU_Load) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.usageField?.stringValue = "\(Int(value.totalUsage.rounded(toPlaces: 2) * 100))%"
                self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
                
                self.circle.toolTip = "\(localizedString("CPU usage")): \(Int(value.totalUsage.rounded(toPlaces: 2) * 100))%"
                self.circle.setValue(value.totalUsage)
                self.circle.setSegments([
                    ColorValue(value.systemLoad, color: self.systemColor),
                    ColorValue(value.userLoad, color: self.userColor)
                ])
                self.circle.setNonActiveSegmentColor(self.idleColor)
                
                if let field = self.eCoresField, let usage = value.usageECores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                if let field = self.pCoresField, let usage = value.usagePCores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                if let field = self.sCoresField, let usage = value.usageSCores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                
                var usagePerCore: [ColorValue] = []
                if let cores = SystemKit.shared.device.info.cpu?.cores, !cores.isEmpty {
                    for i in 0..<value.usagePerCore.count {
                        let core = cores.first(where: { $0.id == i })
                        let color = core?.type == .efficiency ? self.eCoresColor : core?.type == .super ? self.sCoresColor : self.pCoresColor
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: color))
                    }
                } else {
                    for i in 0..<value.usagePerCore.count {
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: NSColor.systemBlue))
                    }
                }
                self.columnChart?.setValues(usagePerCore)
                
                self.initialized = true
            }
        })
    }
}
