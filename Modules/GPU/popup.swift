//
//  popup.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/08/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit

internal class Popup: NSView {
    private var list: [String: GPUView] = [:]
    private let gpuViewHeight: CGFloat = 162
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func infoCallback(_ value: GPUs) {
        if self.list.count != value.list.count {
            DispatchQueue.main.async(execute: {
                self.subviews.forEach{ $0.removeFromSuperview() }
            })
            self.list = [:]
        }
        
        value.list.forEach { (gpu: GPU_Info) in
            if self.list[gpu.name] == nil {
                DispatchQueue.main.async(execute: {
                    self.list[gpu.name] = GPUView(
                        NSRect(x: 0, y: (self.gpuViewHeight + Constants.Popup.margins) * CGFloat(self.list.count), width: self.frame.width, height: self.gpuViewHeight),
                        gpu: gpu
                    )
                    self.addSubview(self.list[gpu.name]!)
                })
            } else {
                self.list[gpu.name]?.update(gpu)
            }
        }
        
        DispatchQueue.main.async(execute: {
            let h: CGFloat = ((self.gpuViewHeight + Constants.Popup.margins) * CGFloat(self.list.count)) - Constants.Popup.margins
            if self.frame.size.height != h {
                self.setFrameSize(NSSize(width: self.frame.width, height: h))
                NotificationCenter.default.post(name: .updatePopupSize, object: nil, userInfo: ["module": "GPU"])
            }
        })
    }
}

private class GPUView: NSView {
    private let height: CGFloat = 60
    private let margin: CGFloat = 4
    
    private var name: String
    private var state: Bool
    
    private var chart: LineChartView? = nil
    private var utilization: HalfCircleGraphView? = nil
    private var temperature: HalfCircleGraphView? = nil
    
    private var stateView: NSView? = nil
    
    public init(_ frame: NSRect, gpu: GPU_Info) {
        self.name = gpu.name
        self.state = gpu.state
        
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.initName()
        self.initCircles()
        self.initChart()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initName() {
        let y: CGFloat = self.frame.height - Constants.Popup.separatorHeight
        let width: CGFloat = self.name.widthOfString(usingFont: NSFont.systemFont(ofSize: 12, weight: .medium)) + 16
        
        let view: NSView = NSView(frame: NSRect(x: (self.frame.width - width)/2, y: y, width: width, height: 30))
        
        let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-15)/2, width: width - 8, height: 15))
        labelView.alignment = .center
        labelView.textColor = .secondaryLabelColor
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        labelView.stringValue = self.name
        
        let stateView: NSView = NSView(frame: NSRect(x: width - 8, y: (view.frame.height-7)/2, width: 6, height: 6))
        stateView.wantsLayer = true
        stateView.layer?.backgroundColor = (self.state ? NSColor.systemGreen : NSColor.systemRed).cgColor
        stateView.toolTip = "GPU \(self.state ? "enabled" : "disabled")"
        stateView.layer?.cornerRadius = 4
        
        view.addSubview(labelView)
        view.addSubview(stateView)
        
        self.addSubview(view)
        self.stateView = stateView
    }
    
    private func initCircles() {
        let view: NSView = NSView(frame: NSRect(
            x: self.margin,
            y: self.height + (self.margin*2),
            width: self.frame.width - (self.margin*2),
            height: self.height
        ))
        
        let circleSize: CGFloat = 50
        self.temperature = HalfCircleGraphView(frame: NSRect(
            x: ((view.frame.width/2) - circleSize)/2 + 10,
            y: 5,
            width: circleSize,
            height: circleSize
        ))
        self.temperature!.toolTip = "GPU temperature"
        self.utilization = HalfCircleGraphView(frame: NSRect(
            x: (view.frame.width/2) + (((view.frame.width/2) - circleSize)/2) - 10,
            y: 5,
            width: circleSize,
            height: circleSize
        ))
        self.utilization!.toolTip = "GPU utilization"
        
        view.addSubview(self.temperature!)
        view.addSubview(self.utilization!)
        
        self.addSubview(view)
    }
    
    private func initChart() {
        let view: NSView = NSView(frame: NSRect(x: self.margin, y: self.margin, width: self.frame.width - (self.margin*2), height: self.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        view.layer?.cornerRadius = 3
        
        self.chart = LineChartView(frame: NSRect(x: 1, y: 0, width: view.frame.width, height: view.frame.height), num: 120)
        
        view.addSubview(self.chart!)
        self.addSubview(view)
    }
    
    public func update(_ gpu: GPU_Info) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) {
                self.stateView?.layer?.backgroundColor = (gpu.state ? NSColor.systemGreen : NSColor.systemRed).cgColor
                self.stateView?.toolTip = "GPU \(gpu.state ? "enabled" : "disabled")"
                
                self.utilization?.setValue(gpu.utilization)
                self.utilization?.setText("\(Int(gpu.utilization*100))%")
                self.temperature?.setValue(Double(gpu.temperature))
                
                let formatter = MeasurementFormatter()
                formatter.numberFormatter.maximumFractionDigits = 0
                let measurement = Measurement(value: Double(gpu.temperature), unit: UnitTemperature.celsius)
                self.temperature?.setText(formatter.string(from: measurement))
                
                self.chart?.addValue(gpu.utilization)
            }
        })
    }
}
