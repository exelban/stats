//
//  Tachometer.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 11/10/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class Tachometer: WidgetWrapper {
    private var labelState: Bool = false
    
    private var chart: TachometerGraphView = TachometerGraphView(
        frame: NSRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.height,
            height: Constants.Widget.height
        ), segments: []
    )
    private var labelView: NSView? = nil
    
    private let size: CGFloat = Constants.Widget.height - (Constants.Widget.margin.y*2) + (Constants.Widget.margin.x*2)
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        let widgetTitle: String = title
        
        super.init(.battery, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: self.size,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if preview {
            self.chart.setSegments([
                circle_segment(value: 0.20, color: NSColor.systemRed),
                circle_segment(value: 0.57, color: NSColor.systemBlue)
            ])
        } else {
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
        }
        
        self.draw()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func draw() {
        let x: CGFloat = self.labelState ? 8 + Constants.Widget.spacing : 0
        
        self.labelView = WidgetLabelView(self.title, height: self.frame.height)
        self.labelView!.isHidden = !self.labelState
        
        self.addSubview(self.labelView!)
        self.addSubview(self.chart)
        
        self.chart.setFrame(NSRect(x: x, y: 0, width: self.frame.size.height, height: self.frame.size.height))
        
        self.setFrameSize(NSSize(width: self.size + x, height: self.frame.size.height))
        self.setWidth(self.size + x)
    }
    
    public func setValue(_ segments: [circle_segment]) {
        DispatchQueue.main.async(execute: {
            self.chart.setSegments(segments)
        })
    }
    
    // MARK: - Settings
    
    public override func settings(width: CGFloat) -> NSView {
        let view = SettingsContainerView(width: width)
        
        view.addArrangedSubview(toggleTitleRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Settings.row),
            title: localizedString("Label"),
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        return view
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.labelState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        
        let x = self.labelState ? 6 + Constants.Widget.spacing : 0
        self.labelView!.isHidden = !self.labelState
        self.chart.setFrameOrigin(NSPoint(x: x, y: 0))
        self.setWidth(self.labelState ? self.size+x : self.size)
    }
}
