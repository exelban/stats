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

public class Portal: PortalWrapper {
    private var circle: PieChartView = PieChartView(drawValue: true)
    private var chart: NetworkChartView? = nil
    
    private var nameField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var readField: NSTextField? = nil
    private var writeField: NSTextField? = nil
    
    private var valueColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_valueColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var readColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_readColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var writeColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_writeColor", defaultValue: SColor.secondRed.key)).additional as! NSColor
    }
    
    public var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(ModuleType.disk.stringValue)_base", defaultValue: "byte")) ?? .byte
    }
    public var speedUnit: String {
        networkSpeedUnit(from: Store.shared.string(key: "\(ModuleType.disk.stringValue)_speedUnit", defaultValue: NetworkSpeedUnitAuto)).key
    }
    
    private var initialized: Bool = false
    
    public override func load() {
        self.body.orientation = .vertical
        self.body.distribution = .fill
        
        var top: NSStackView {
            let view = NSStackView()
            
            view.orientation = .horizontal
            view.distribution = .fillEqually
            view.spacing = Constants.Popup.spacing*2
            
            let chart: NSView = self.circleView()
            let details: NSView = self.detailsView()
            
            view.addArrangedSubview(chart)
            view.addArrangedSubview(details)
            
            return view
        }
        
        var bottom: NSStackView {
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
        
        self.body.addArrangedSubview(top)
        self.body.addArrangedSubview(bottom)
    }
    
    private func circleView() -> NSView {
        let view = NSStackView()
        
        view.heightAnchor.constraint(equalToConstant: 70).isActive = true
        view.edgeInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        view.addArrangedSubview(self.circle)
        
        return view
    }
    
    private func detailsView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        self.nameField = portalRow(view, title: "\(localizedString("Name")):").1
        self.usedField = portalRow(view, title: "\(localizedString("Used")):").1
        self.freeField = portalRow(view, title: "\(localizedString("Free")):").1
        
        return view
    }
    
    private func chartView() -> NSView {
        let view = NSStackView()
        view.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 5)
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        view.layer?.cornerRadius = Constants.Popup.radius
        
        let chart = NetworkChartView(num: 120, minMax: false, outColor: self.writeColor, inColor: self.readColor)
        self.chart = chart
        
        view.addArrangedSubview(chart)
        
        return view
    }
    
    private func ioView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        (_, self.writeField) = portalWithColorRow(view, color: self.writeColor, title: "\(localizedString("Write")):")
        (_, self.readField) = portalWithColorRow(view, color: self.readColor, title: "\(localizedString("Read")):")
        
        return view
    }
    
    internal func utilizationCallback(_ value: drive) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.nameField?.stringValue = value.mediaName
                self.usedField?.stringValue = DiskSize(value.size - value.free).getReadableMemory()
                self.freeField?.stringValue = DiskSize(value.free).getReadableMemory()
                
                self.circle.toolTip = "\(localizedString("Disk usage")): \(Int(value.percentage*100))%"
                self.circle.setValue(value.percentage)
                self.circle.setSegments([
                    ColorValue(value.percentage, color: self.valueColor)
                ])
                self.initialized = true
            }
        })
    }
    
    internal func activityCallback(_ value: drive) {
        DispatchQueue.main.async(execute: {
            self.chart?.addValue(upload: Double(value.activity.write), download: Double(value.activity.read))
            
            self.writeField?.stringValue = Units(bytes: value.activity.write).getReadableSpeed(base: self.base, unit: self.speedUnit)
            self.readField?.stringValue = Units(bytes: value.activity.read).getReadableSpeed(base: self.base, unit: self.speedUnit)
        })
    }
}
