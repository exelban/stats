//
//  portal.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 18/02/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Portal: NSStackView, Portal_p {
    public var name: String
    
    private var chart: NetworkChartView? = nil
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.name)_base", defaultValue: "byte")) ?? .byte
    }
    
    private var downloadColorState: Color = .secondBlue
    private var downloadColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.downloadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColorState: Color = .secondRed
    private var uploadColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.uploadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    public init(_ module: ModuleType) {
        self.name = module.rawValue
        
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
        
        let chart = NetworkChartView(frame: NSRect.zero, num: 120, outColor: self.uploadColor, inColor: self.downloadColor)
        chart.base = self.base
        self.chart = chart
        self.chart!.toolTip = localizedString("Network activity")
        self.addArrangedSubview(self.chart!)
        
        self.heightAnchor.constraint(equalToConstant: Constants.Popup.portalHeight).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if let chart = self.chart {
                if chart.base != self.base {
                    chart.base = self.base
                }
                chart.addValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
            }
        })
    }
}
