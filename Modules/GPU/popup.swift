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
    
    private var value: GPU_Info
    
    private var temperatureChart: LineChartView? = nil
    private var utilizationChart: LineChartView? = nil
    private var temperatureCirle: HalfCircleGraphView? = nil
    private var utilizationCircle: HalfCircleGraphView? = nil
    
    private var stateView: NSView? = nil
    
    public init(_ frame: NSRect, gpu: GPU_Info) {
        self.value = gpu
        
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.initName()
        self.initTemperature()
        self.initUtilization()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initName() {
        let y: CGFloat = self.frame.height - 23
        let width: CGFloat = self.value.name.widthOfString(usingFont: NSFont.systemFont(ofSize: 12, weight: .medium)) + 16
        
        let view: NSView = NSView(frame: NSRect(x: (self.frame.width - width)/2, y: y, width: width, height: 20))
        
        let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-15)/2, width: width - 8, height: 15))
        labelView.alignment = .center
        labelView.textColor = .secondaryLabelColor
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        labelView.stringValue = self.value.name
        
        let stateView: NSView = NSView(frame: NSRect(x: width - 8, y: (view.frame.height-7)/2, width: 6, height: 6))
        stateView.wantsLayer = true
        stateView.layer?.backgroundColor = (self.value.state ? NSColor.systemGreen : NSColor.systemRed).cgColor
        stateView.toolTip = "GPU \(self.value.state ? "enabled" : "disabled")"
        stateView.layer?.cornerRadius = 4
        
        view.addSubview(labelView)
        view.addSubview(stateView)
        
        self.addSubview(view)
        self.stateView = stateView
    }
    
    private func initTemperature() {
        let view: NSView = NSView(frame: NSRect(
            x: self.margin,
            y: self.height + (self.margin*2),
            width: self.frame.width - (self.margin*2),
            height: self.height
        ))
        
        let circleWidth: CGFloat = 70
        let circleSize: CGFloat = 44
        
        let chartView: NSView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: view.frame.width - circleWidth,
            height: view.frame.height
        ))
        chartView.wantsLayer = true
        chartView.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        chartView.layer?.cornerRadius = 3
        self.temperatureChart = LineChartView(frame: NSRect(x: 0, y: 0, width: chartView.frame.width, height: chartView.frame.height), num: 120)
        chartView.addSubview(self.temperatureChart!)
        
        self.temperatureCirle = HalfCircleGraphView(frame: NSRect(
            x: (view.frame.width - circleWidth) + (circleWidth - circleSize)/2,
            y: (view.frame.height - circleSize)/2 - 3,
            width: circleSize,
            height: circleSize
        ))
        self.temperatureCirle!.toolTip = LocalizedString("GPU temperature")
        
        view.addSubview(chartView)
        view.addSubview(self.temperatureCirle!)
        
        self.temperatureCirle?.setValue(Double(self.value.temperature))
        self.temperatureCirle?.setText(Temperature(Double(self.value.temperature)))
        self.temperatureChart?.addValue(Double(self.value.temperature) / 100)
        
        self.addSubview(view)
    }
    
    private func initUtilization() {
        let view: NSView = NSView(frame: NSRect(
            x: self.margin,
            y: self.margin,
            width: self.frame.width - (self.margin*2),
            height: self.height
        ))
        
        let circleWidth: CGFloat = 70
        let circleSize: CGFloat = 44
        
        let chartView: NSView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: view.frame.width - circleWidth,
            height: view.frame.height
        ))
        chartView.wantsLayer = true
        chartView.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        chartView.layer?.cornerRadius = 3
        self.utilizationChart = LineChartView(frame: NSRect(x: 0, y: 0, width: chartView.frame.width, height: chartView.frame.height), num: 120)
        chartView.addSubview(self.utilizationChart!)
        
        self.utilizationCircle = HalfCircleGraphView(frame: NSRect(
            x: (view.frame.width - circleWidth) + (circleWidth - circleSize)/2,
            y: (view.frame.height - circleSize)/2 - 3,
            width: circleSize,
            height: circleSize
        ))
        self.utilizationCircle!.toolTip = LocalizedString("GPU utilization")
        
        view.addSubview(chartView)
        view.addSubview(self.utilizationCircle!)
        
        self.utilizationCircle?.setValue(self.value.utilization)
        self.utilizationCircle?.setText("\(Int(self.value.utilization*100))%")
        self.utilizationChart?.addValue(self.value.utilization)
        
        self.addSubview(view)
    }
    
    public func update(_ gpu: GPU_Info) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) {
                self.stateView?.layer?.backgroundColor = (gpu.state ? NSColor.systemGreen : NSColor.systemRed).cgColor
                self.stateView?.toolTip = "GPU \(gpu.state ? "enabled" : "disabled")"
                
                self.temperatureCirle?.setValue(Double(gpu.temperature))
                self.temperatureCirle?.setText(Temperature(Double(gpu.temperature)))
                
                self.utilizationCircle?.setValue(gpu.utilization)
                self.utilizationCircle?.setText("\(Int(gpu.utilization*100))%")
            }
            
            self.temperatureChart?.addValue(Double(gpu.temperature) / 100)
            self.utilizationChart?.addValue(gpu.utilization)
        })
    }
}
