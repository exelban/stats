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
    private var initialized: Bool = false
    
    private var uploadField: NSTextField? = nil
    private var downloadField: NSTextField? = nil
    
    private var publicIPField: NSTextField? = nil
    private var localIPField: NSTextField? = nil
    
    private var publicIPView: NSView? = nil
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.name)_base", defaultValue: "byte")) ?? .byte
    }
    private var speedUnit: String {
        networkSpeedUnit(from: Store.shared.string(key: "\(self.name)_speedUnit", defaultValue: NetworkSpeedUnitAuto)).key
    }
    private var reverseOrderState: Bool {
        Store.shared.bool(key: "\(self.name)_reverseOrder", defaultValue: false)
    }
    private var chartScale: Scale {
        Scale.fromString(Store.shared.string(key: "\(self.name)_chartScale", defaultValue: Scale.none.key))
    }
    private var chartFixedScale: Int {
        Store.shared.int(key: "\(self.name)_chartFixedScale", defaultValue: 12)
    }
    private var chartFixedScaleSize: SizeUnit {
        SizeUnit.fromString(Store.shared.string(key: "\(self.name)_chartFixedScaleSize", defaultValue: SizeUnit.MB.key))
    }
    private var publicIPState: Bool {
        Store.shared.bool(key: "\(self.name)_publicIP", defaultValue: true)
    }
    private var emojiCCState: Bool {
        Store.shared.bool(key: "\(self.name)_emojiCC", defaultValue: true)
    }
    
    private var downloadColor: NSColor {
        let v = SColor.fromString(Store.shared.string(key: "\(self.name)_downloadColor", defaultValue: SColor.secondBlue.key))
        var value = NSColor.systemBlue
        if let color = v.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColor: NSColor {
        let v = SColor.fromString(Store.shared.string(key: "\(self.name)_uploadColor", defaultValue: SColor.secondRed.key))
        var value = NSColor.systemRed
        if let color = v.additional as? NSColor {
            value = color
        }
        return value
    }
    
    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        
        var top: NSStackView {
            let view = NSStackView()
            
            view.orientation = .horizontal
            view.distribution = .fillEqually
            view.spacing = Constants.Popup.spacing*2
            
            let chart: NSView = self.chartView()
            let details: NSView = self.ioView()
            
            view.addArrangedSubview(details)
            view.addArrangedSubview(chart)
            
            return view
        }
        
        let bottom = self.detailsView()
        
        self.body.addArrangedSubview(top)
        self.body.addArrangedSubview(bottom)
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 5)
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        view.layer?.cornerRadius = Constants.Popup.radius
        
        let chart = NetworkChartView(
            num: 120,
            minMax: false,
            reversedOrder: self.reverseOrderState,
            outColor: self.uploadColor,
            inColor: self.downloadColor,
            scale: self.chartScale,
            fixedScale: Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale))
        )
        chart.setBase(self.base)
        chart.setSpeedUnit(self.speedUnit)
        
        self.chart = chart
        
        view.addArrangedSubview(chart)
        
        return view
    }
    
    private func ioView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        (_, self.uploadField) = portalWithColorRow(view, color: self.uploadColor, title: "\(localizedString("Uploading")):")
        (_, self.downloadField) = portalWithColorRow(view, color: self.downloadColor, title: "\(localizedString("Downloading")):")
        
        return view
    }
    
    private func detailsView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        self.localIPField = portalRow(view, title: "\(localizedString("Local IP")):", value: localizedString("Unknown"), isSelectable: true).1
        
        let publicIP = portalRow(view, title: "\(localizedString("Public IP")):", value: localizedString("Unknown"), isSelectable: true)
        self.publicIPField = publicIP.1
        self.publicIPView = publicIP.2
        self.publicIPView?.isHidden = !self.publicIPState
        
        return view
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            self.chart?.addValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
            
            guard (self.window?.isVisible ?? false) || !self.initialized else { return }
            self.initialized = true
            
            self.uploadField?.stringValue = Units(bytes: value.bandwidth.upload).getReadableSpeed(base: self.base, unit: self.speedUnit)
            self.downloadField?.stringValue = Units(bytes: value.bandwidth.download).getReadableSpeed(base: self.base, unit: self.speedUnit)
            
            if let chart = self.chart {
                chart.setBase(self.base)
                chart.setSpeedUnit(self.speedUnit)
                chart.setScale(self.chartScale, Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale)))
                chart.setColors(in: self.downloadColor, out: self.uploadColor)
            }
            
            if self.publicIPState, let view = self.publicIPView, view.isHidden {
                self.publicIPView?.isHidden = false
            } else if !self.publicIPState, let view = self.publicIPView, !view.isHidden {
                self.publicIPView?.isHidden = true
            }
            
            if let view = self.publicIPField, view.stringValue != value.raddr.v4 {
                if let addr = value.raddr.v4 {
                    var ip = addr
                    if let cc = value.raddr.countryCode, !cc.isEmpty {
                        if self.emojiCCState, let flag = countryFlag(cc) {
                            ip += " \(flag)"
                        } else {
                            ip += " (\(cc))"
                        }
                        view.toolTip = cc
                    }
                    view.stringValue = ip
                } else {
                    view.stringValue = localizedString("Unknown")
                }
                
                if let addr = value.raddr.v6 {
                    view.toolTip = "v6: \(addr)"
                } else {
                    view.toolTip = "v6: \(localizedString("Unknown"))"
                }
            }
            
            var privateIP = localizedString("Unknown")
            if let v4 = value.laddr.v4, !v4.isEmpty {
                privateIP = v4
            } else if let v6 = value.laddr.v6, !v6.isEmpty {
                privateIP = v6
            }
            if self.localIPField?.stringValue != privateIP {
                self.localIPField?.stringValue = privateIP
            }
        })
    }
}
