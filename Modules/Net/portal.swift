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

public class Portal: PortalWrapper {
    private var chart: NetworkChartView? = nil
    
    private var publicIPField: NSTextField? = nil
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.name)_base", defaultValue: "byte")) ?? .byte
    }
    
    private var downloadColorState: Color = .secondBlue
    private var downloadColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.downloadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColorState: Color = .secondRed
    private var uploadColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.uploadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    private var initialized: Bool = false
    
    public override func load() {
        self.loadColors()
        
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        view.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Popup.spacing*2,
            bottom: 0,
            right: Constants.Popup.spacing*2
        )
        
        let chartView = self.chartView()
        view.addArrangedSubview(chartView)
        
        self.publicIPField = portalRow(view, title: "\(localizedString("Public IP")):", value: localizedString("Unknown"))
        view.subviews.last?.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        self.addArrangedSubview(view)
    }
    
    public func loadColors() {
        self.downloadColorState = Color.fromString(Store.shared.string(key: "\(self.name)_downloadColor", defaultValue: self.downloadColorState.key))
        self.uploadColorState = Color.fromString(Store.shared.string(key: "\(self.name)_uploadColor", defaultValue: self.uploadColorState.key))
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fill
        view.spacing = Constants.Popup.spacing*2
        let chart = NetworkChartView(frame: NSRect.zero, num: 120, minMax: true, outColor: self.uploadColor, inColor: self.downloadColor)
        self.chart = chart
        
        view.addArrangedSubview(chart)
        
        return view
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if let chart = self.chart {
                if chart.base != self.base {
                    chart.base = self.base
                }
                chart.addValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
            }
            
            if let view = self.publicIPField, view.stringValue != value.raddr.v4 {
                if let addr = value.raddr.v4 {
                    view.stringValue = (value.wifiDetails.countryCode != nil) ? "\(addr) (\(value.wifiDetails.countryCode!))" : addr
                } else {
                    view.stringValue = localizedString("Unknown")
                }
                if let addr = value.raddr.v6 {
                    view.toolTip = "\("\(localizedString("v6")):") \(addr)"
                } else {
                    view.toolTip = "\("\(localizedString("v6")):") \(localizedString("Unknown"))"
                }
            }
        })
    }
}
