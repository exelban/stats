//
//  PieChart.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 30/11/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class PieChart: WidgetWrapper {
    private var chart: PieChartView = PieChartView(
        frame: NSRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.height,
            height: Constants.Widget.height
        ),
        segments: [], filled: true, drawValue: false
    )
    
    private let size: CGFloat = Constants.Widget.height - (Constants.Widget.margin.y*2) + (Constants.Widget.margin.x*2)
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            if let titleFromConfig = config!["Title"] as? String {
                widgetTitle = titleFromConfig
            }
        }
        
        super.init(.pieChart, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: self.size,
            height: Constants.Widget.height - (Constants.Widget.margin.y*2)
        ))
        
        self.canDrawConcurrently = true
        
        if preview {
            if self.title == "CPU" {
                self.chart.setSegments([
                    circle_segment(value: 0.16, color: NSColor.systemRed),
                    circle_segment(value: 0.28, color: NSColor.systemBlue)
                ])
            } else if self.title == "RAM" {
                self.chart.setSegments([
                    circle_segment(value: 0.36, color: NSColor.systemBlue),
                    circle_segment(value: 0.12, color: NSColor.systemOrange),
                    circle_segment(value: 0.08, color: NSColor.systemPink)
                ])
            }
        }
        
        self.draw()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func draw() {
        self.addSubview(self.chart)
        
        var frame = self.chart.frame
        frame = NSRect(x: 0, y: 0, width: self.frame.size.height, height: self.frame.size.height)
        self.chart.frame = frame
        
        self.setFrameSize(NSSize(width: self.size, height: self.frame.size.height))
        self.setWidth(self.size)
    }
    
    public func setValue(_ segments: [circle_segment]) {
        DispatchQueue.main.async(execute: {
            self.chart.setSegments(segments)
        })
    }
}
