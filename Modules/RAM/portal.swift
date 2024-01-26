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

public class Portal: PortalWrapper {
    private var circle: PieChartView? = nil
    
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    private var swapField: NSTextField? = nil
    private var pressureLevelField: NSTextField? = nil
    
    private var initialized: Bool = false
    
    private var appColorState: Color = .secondBlue
    private var appColor: NSColor { self.appColorState.additional as? NSColor ?? NSColor.systemRed }
    private var wiredColorState: Color = .secondOrange
    private var wiredColor: NSColor { self.wiredColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var compressedColorState: Color = .pink
    private var compressedColor: NSColor { self.compressedColorState.additional as? NSColor ?? NSColor.lightGray }
    private var freeColorState: Color = .lightGray
    private var freeColor: NSColor { self.freeColorState.additional as? NSColor ?? NSColor.systemBlue }
    
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
    
    public func loadColors() {
        self.appColorState = Color.fromString(Store.shared.string(key: "\(self.name)_appColor", defaultValue: self.appColorState.key))
        self.wiredColorState = Color.fromString(Store.shared.string(key: "\(self.name)_wiredColor", defaultValue: self.wiredColorState.key))
        self.compressedColorState = Color.fromString(Store.shared.string(key: "\(self.name)_compressedColor", defaultValue: self.compressedColorState.key))
        self.freeColorState = Color.fromString(Store.shared.string(key: "\(self.name)_freeColor", defaultValue: self.freeColorState.key))
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
        chart.toolTip = localizedString("Memory usage")
        view.addArrangedSubview(chart)
        self.circle = chart
        
        return view
    }
    
    private func details() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        self.usedField = portalRow(view, title: "\(localizedString("Used")):")
        self.freeField = portalRow(view, title: "\(localizedString("Free")):")
        self.swapField = portalRow(view, title: "\(localizedString("Swap")):")
        self.pressureLevelField = portalRow(view, title: "\(localizedString("Memory pressure")):")
        
        return view
    }
    
    internal func callback(_ value: RAM_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.usedField?.stringValue = Units(bytes: Int64(value.used)).getReadableMemory()
                self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory()
                self.swapField?.stringValue = Units(bytes: Int64(value.swap.used)).getReadableMemory()
                self.pressureLevelField?.stringValue = "\(value.pressureLevel.rawValue)"
                
                self.usedField?.toolTip = "\(Int(value.usage.rounded(toPlaces: 2) * 100))%"
                self.freeField?.toolTip = "\(Int((1-value.usage).rounded(toPlaces: 2) * 100))%"
                if let level = memoryPressureLevels.first(where: { $0.additional as? DispatchSource.MemoryPressureEvent == value.pressureLevel }) {
                    self.pressureLevelField?.toolTip = localizedString(level.value)
                }
                
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
