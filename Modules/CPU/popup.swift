//
//  popup.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSView {
    private var store: UnsafePointer<Store>
    private var title: String
    
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90
    private let detailsHeight: CGFloat = 22*3
    private let processesHeight: CGFloat = 22*5
    
    private var loadField: NSTextField? = nil
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    
    private var chart: LineChartView? = nil
    private var circle: CircleGraphView? = nil
    private var temperatureCircle: HalfCircleGraphView? = nil
    private var frequencyCircle: HalfCircleGraphView? = nil
    private var initialized: Bool = false
    private var initializedAdditional: Bool = false
    private var processesInitialized: Bool = false
    
    private var processes: [ProcessView] = []
    private var maxFreq: Double = 0
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.store = store
        self.title = title
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + chartHeight + detailsHeight + processesHeight + (Constants.Popup.separatorHeight*3)
        ))
        
        initDashboard()
        initChart()
        initDetails()
        initProcesses()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.chart?.display()
    }
    
    private func initDashboard() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        view.wantsLayer = true
        
        let container: NSView = NSView(frame: NSRect(x: 0, y: 10, width: view.frame.width, height: self.dashboardHeight-20))
        self.circle = CircleGraphView(frame: NSRect(x: (container.frame.width - container.frame.height)/2, y: 0, width: container.frame.height, height: container.frame.height), segments: [])
        self.circle!.toolTip = LocalizedString("CPU usage")
        container.addSubview(self.circle!)
        
        let centralWidth: CGFloat = self.dashboardHeight-20
        let sideWidth: CGFloat = (view.frame.width - centralWidth - (Constants.Popup.margins*2))/2
        self.temperatureCircle = HalfCircleGraphView(frame: NSRect(x: (sideWidth - 60)/2, y: 10, width: 60, height: 50))
        self.temperatureCircle!.toolTip = LocalizedString("CPU temperature")
        
        self.frequencyCircle = HalfCircleGraphView(frame: NSRect(x: view.frame.width - 60 - Constants.Popup.margins*2, y: 10, width: 60, height: 50))
        self.frequencyCircle!.toolTip = LocalizedString("CPU frequency")
        (self.frequencyCircle! as NSView).isHidden = true
        
        view.addSubview(self.temperatureCircle!)
        view.addSubview(container)
        view.addSubview(self.frequencyCircle!)
        
        self.addSubview(view)
    }
    
    private func initChart() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - Constants.Popup.separatorHeight
        let separator = SeparatorView(LocalizedString("Usage history"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: y -  self.chartHeight, width: self.frame.width, height: self.chartHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        view.layer?.cornerRadius = 3
        
        self.chart = LineChartView(frame: NSRect(x: 1, y: 0, width: view.frame.width, height: view.frame.height), num: 120)
        
        view.addSubview(self.chart!)
        
        self.addSubview(view)
    }
    
    private func initDetails() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - self.chartHeight - (Constants.Popup.separatorHeight*2)
        let separator = SeparatorView(LocalizedString("Details"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.detailsHeight, width: self.frame.width, height: self.detailsHeight))
        
        self.systemField = PopupWithColorRow(view, color: NSColor.systemRed, n: 2, title: "\(LocalizedString("System")):", value: "")
        self.userField = PopupWithColorRow(view, color: NSColor.systemBlue, n: 1, title: "\(LocalizedString("User")):", value: "")
        self.idleField = PopupWithColorRow(view, color: NSColor.lightGray.withAlphaComponent(0.5), n: 0, title: "\(LocalizedString("Idle")):", value: "")
        
        self.addSubview(view)
    }
    
    private func initProcesses() {
        let separator = SeparatorView(LocalizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        
        self.processes.append(ProcessView(0))
        self.processes.append(ProcessView(1))
        self.processes.append(ProcessView(2))
        self.processes.append(ProcessView(3))
        self.processes.append(ProcessView(4))
        
        self.processes.forEach{ view.addSubview($0) }
        
        self.addSubview(view)
    }
    
    private func addFirstRow(mView: NSView, y: CGFloat, title: String, value: String) -> NSTextField {
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: y, width: mView.frame.width, height: 16))
        
        let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 10, weight: .light)) + 4
        let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: 1.5, width: labelWidth, height: 13))
        labelView.stringValue = title
        labelView.alignment = .natural
        labelView.font = NSFont.systemFont(ofSize: 10, weight: .light)
        
        let valueView: NSTextField = TextView(frame: NSRect(x: labelWidth, y: 1, width: mView.frame.width - labelWidth, height: 14))
        valueView.stringValue = value
        valueView.alignment = .right
        valueView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        mView.addSubview(rowView)
        
        return valueView
    }
    
    public func loadCallback(_ value: CPU_Load) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100)) %"
                self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100)) %"
                self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100)) %"
                
                let v = Int(value.totalUsage.rounded(toPlaces: 2) * 100)
                self.loadField?.stringValue = "\(v) %"
                self.initialized = true
                
                self.circle?.setValue(value.totalUsage)
                self.circle?.setSegments([
                    circle_segment(value: value.systemLoad, color: NSColor.systemRed),
                    circle_segment(value: value.userLoad, color: NSColor.systemBlue),
                ])
            }
            self.chart?.addValue(value.totalUsage)
        })
    }
    
    public func additionalCallback(_ value: CPU_additional) {
        DispatchQueue.main.async(execute: {
            if value.frequency != nil && (self.frequencyCircle! as NSView).isHidden {
                (self.frequencyCircle! as NSView).isHidden = false
            }
            
            if (self.window?.isVisible ?? false) || !self.initializedAdditional {
                if let temperature = value.temperature {
                    self.temperatureCircle?.setValue(temperature)
                    self.temperatureCircle?.setText(Temperature(temperature))
                }
                if let freq = value.frequency {
                    if freq > self.maxFreq {
                        self.maxFreq = freq
                    }
                    
                    if let freqCircle = self.frequencyCircle {
                        freqCircle.setValue((100*freq)/self.maxFreq)
                        freqCircle.setText("\((freq/1000).rounded(toPlaces: 2))\nGHz")
                    }
                }
                
                self.initializedAdditional = true
            }
        })
    }
    
    public func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.processesInitialized {
                for i in 0..<list.count {
                    let process = list[i]
                    let index = list.count-i-1
                    if self.processes.indices.contains(index) {
                        self.processes[index].label = process.name != nil ? process.name! : process.command
                        self.processes[index].value = "\(process.usage)%"
                        self.processes[index].icon = process.icon
                    }
                }
                
                self.processesInitialized = true
            }
        })
    }
}
