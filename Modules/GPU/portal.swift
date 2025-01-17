//
//  portal.swift
//  GPU
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
    private var circle: HalfCircleGraphView? = nil
    
    private var usageField: NSTextField? = nil
    private var renderField: NSTextField? = nil
    private var tilerField: NSTextField? = nil
    
    private var initialized: Bool = false
    
    public override func load() {
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
        
        let chart = HalfCircleGraphView()
        chart.toolTip = localizedString("GPU usage")
        view.addArrangedSubview(chart)
        self.circle = chart
        
        return view
    }
    
    private func details() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        
        self.usageField = portalRow(view, title: "\(localizedString("Usage")):").1
        self.renderField = portalRow(view, title: "\(localizedString("Render")):").1
        self.tilerField = portalRow(view, title: "\(localizedString("Tiler")):").1
        
        return view
    }
    
    internal func callback(_ value: GPU_Info) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                if let value = value.utilization {
                    self.usageField?.stringValue = "\(Int(value*100))%"
                }
                if let value = value.renderUtilization {
                    self.renderField?.stringValue = "\(Int(value*100))%"
                }
                if let value = value.tilerUtilization {
                    self.tilerField?.stringValue = "\(Int(value*100))%"
                }
                
                self.circle?.toolTip = "\(localizedString("GPU usage")): \(Int(value.utilization!*100))%"
                self.circle?.setValue(value.utilization!)
                self.circle?.setText("\(Int(value.utilization!*100))%")
                self.initialized = true
            }
        })
    }
}
