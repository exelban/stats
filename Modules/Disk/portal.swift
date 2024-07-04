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
    private var circle: PieChartView? = nil
    private var chart: NetworkChartView? = nil
    
    private var nameField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var valueColorState: SColor = .secondBlue
    private var valueColor: NSColor { self.valueColorState.additional as? NSColor ?? NSColor.systemBlue }
    
    private var readColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_readColor", defaultValue: SColor.secondBlue.key)).additional as! NSColor
    }
    private var writeColor: NSColor {
        SColor.fromString(Store.shared.string(key: "\(self.name)_writeColor", defaultValue: SColor.secondRed.key)).additional as! NSColor
    }
    
    private var initialized: Bool = false
    
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
    }
    
    private func loadColors() {
        self.valueColorState = SColor.fromString(Store.shared.string(key: "\(self.name)_valueColor", defaultValue: self.valueColorState.key))
    }
    
    private func charts() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.spacing*4,
            left: Constants.Popup.spacing*4,
            bottom: Constants.Popup.spacing*4,
            right: Constants.Popup.spacing*4
        )
        
        let chart = PieChartView(frame: NSRect.zero, segments: [], drawValue: true)
        chart.toolTip = localizedString("Disk usage")
        view.addArrangedSubview(chart)
        self.circle = chart
        
        return view
    }
    
    private func details() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        self.nameField = portalRow(view, title: "\(localizedString("Name")):")
        self.usedField = portalRow(view, title: "\(localizedString("Used")):")
        self.freeField = portalRow(view, title: "\(localizedString("Free")):")
        
        let chart = NetworkChartView(frame: NSRect.zero, num: 120, minMax: false, outColor: self.writeColor, inColor: self.readColor)
        chart.heightAnchor.constraint(equalToConstant: 26).isActive = true
        self.chart = chart
        view.addArrangedSubview(chart)
        
        return view
    }
    
    internal func utilizationCallback(_ value: drive) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.nameField?.stringValue = value.mediaName
                self.usedField?.stringValue = DiskSize(value.size - value.free).getReadableMemory()
                self.freeField?.stringValue = DiskSize(value.free).getReadableMemory()
                
                self.circle?.setValue(value.percentage)
                self.circle?.setSegments([
                    circle_segment(value: value.percentage, color: self.valueColor)
                ])
                self.initialized = true
            }
        })
    }
    
    internal func activityCallback(_ value: drive) {
        DispatchQueue.main.async(execute: {
            self.chart?.addValue(upload: Double(value.activity.write), download: Double(value.activity.read))
        })
    }
}
