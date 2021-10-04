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
import Kit

internal class Popup: NSView, Popup_p {
    private var title: String
    
    private var grid: NSGridView? = nil
    
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90 + Constants.Popup.separatorHeight
    private let detailsHeight: CGFloat = (22*5) + Constants.Popup.separatorHeight
    private let averageHeight: CGFloat = (22*3) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = 22
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var shedulerLimitField: NSTextField? = nil
    private var speedLimitField: NSTextField? = nil
    private var average1Field: NSTextField? = nil
    private var average5Field: NSTextField? = nil
    private var average15Field: NSTextField? = nil
    
    private var chart: LineChartView? = nil
    private var circle: PieChartView? = nil
    private var temperatureCircle: HalfCircleGraphView? = nil
    private var frequencyCircle: HalfCircleGraphView? = nil
    private var initialized: Bool = false
    private var initializedTemperature: Bool = false
    private var initializedFrequency: Bool = false
    private var initializedProcesses: Bool = false
    private var initializedLimits: Bool = false
    private var initializedAverage: Bool = false
    
    private var processes: [ProcessView] = []
    private var maxFreq: Double = 0
    
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    private var processesHeight: CGFloat {
        get {
            let num = self.numberOfProcesses
            return (self.processHeight*CGFloat(num)) + (num == 0 ? 0 : Constants.Popup.separatorHeight)
        }
    }
    
    public init(_ title: String) {
        self.title = title
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: self.dashboardHeight + self.chartHeight + self.detailsHeight + self.averageHeight
        ))
        self.setFrameSize(NSSize(width: self.frame.width, height: self.frame.height+self.processesHeight))
        
        let gridView: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        gridView.rowSpacing = 0
        gridView.yPlacement = .fill
        
        gridView.addRow(with: [self.initDashboard()])
        gridView.addRow(with: [self.initChart()])
        gridView.addRow(with: [self.initDetails()])
        gridView.addRow(with: [self.initAverage()])
        gridView.addRow(with: [self.initProcesses()])
        
        gridView.row(at: 0).height = self.dashboardHeight
        gridView.row(at: 1).height = self.chartHeight
        gridView.row(at: 2).height = self.detailsHeight
        gridView.row(at: 3).height = self.averageHeight
        
        self.addSubview(gridView)
        self.grid = gridView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.chart?.display()
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes.count == self.numberOfProcesses {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.processes = []
            
            let h: CGFloat = self.dashboardHeight + self.chartHeight + self.detailsHeight + self.processesHeight
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.row(at: 3).cell(at: 0).contentView?.removeFromSuperview()
            self.grid?.removeRow(at: 3)
            self.grid?.addRow(with: [self.initProcesses()])
            self.initializedProcesses = false
            
            self.sizeCallback?(self.frame.size)
        })
    }
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.dashboardHeight))
        
        let container: NSView = NSView(frame: NSRect(x: 0, y: 10, width: view.frame.width, height: self.dashboardHeight-20))
        self.circle = PieChartView(frame: NSRect(
            x: (container.frame.width - container.frame.height)/2,
            y: 0,
            width: container.frame.height,
            height: container.frame.height
        ), segments: [], drawValue: true)
        self.circle!.toolTip = localizedString("CPU usage")
        container.addSubview(self.circle!)
        
        let centralWidth: CGFloat = self.dashboardHeight-20
        let sideWidth: CGFloat = (view.frame.width - centralWidth - (Constants.Popup.margins*2))/2
        self.temperatureCircle = HalfCircleGraphView(frame: NSRect(x: (sideWidth - 60)/2, y: 10, width: 60, height: 50))
        self.temperatureCircle!.toolTip = localizedString("CPU temperature")
        (self.temperatureCircle! as NSView).isHidden = true
        
        self.frequencyCircle = HalfCircleGraphView(frame: NSRect(x: view.frame.width - 60 - Constants.Popup.margins*2, y: 10, width: 60, height: 50))
        self.frequencyCircle!.toolTip = localizedString("CPU frequency")
        (self.frequencyCircle! as NSView).isHidden = true
        
        view.addSubview(self.temperatureCircle!)
        view.addSubview(container)
        view.addSubview(self.frequencyCircle!)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: self.chartHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = 3
        
        self.chart = LineChartView(frame: NSRect(x: 1, y: 0, width: view.frame.width, height: container.frame.height), num: 120)
        container.addSubview(self.chart!)
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        let separator = separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        self.systemField = popupWithColorRow(container, color: NSColor.systemRed, n: 4, title: "\(localizedString("System")):", value: "")
        self.userField = popupWithColorRow(container, color: NSColor.systemBlue, n: 3, title: "\(localizedString("User")):", value: "")
        self.idleField = popupWithColorRow(container, color: NSColor.lightGray.withAlphaComponent(0.5), n: 2, title: "\(localizedString("Idle")):", value: "")
        self.shedulerLimitField = popupRow(container, n: 1, title: "\(localizedString("Scheduler limit")):", value: "").1
        self.speedLimitField = popupRow(container, n: 0, title: "\(localizedString("Speed limit")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initAverage() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.averageHeight))
        let separator = separatorView(localizedString("Average load"), origin: NSPoint(x: 0, y: self.averageHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        self.average1Field = popupRow(container, n: 2, title: "\(localizedString("1 minute")):", value: "").1
        self.average5Field = popupRow(container, n: 1, title: "\(localizedString("5 minutes")):", value: "").1
        self.average15Field = popupRow(container, n: 0, title: "\(localizedString("15 minutes")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        for _ in 0..<self.numberOfProcesses {
            let processView = ProcessView()
            self.processes.append(processView)
            container.addArrangedSubview(processView)
        }
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    public func loadCallback(_ value: CPU_Load) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
                self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
                self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
                
                self.circle?.setValue(value.totalUsage)
                self.circle?.setSegments([
                    circle_segment(value: value.systemLoad, color: NSColor.systemRed),
                    circle_segment(value: value.userLoad, color: NSColor.systemBlue)
                ])
                
                self.initialized = true
            }
            self.chart?.addValue(value.totalUsage)
        })
    }
    
    public func temperatureCallback(_ value: Double) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initializedTemperature {
                if let view = self.temperatureCircle, (view as NSView).isHidden {
                    view.isHidden = false
                }
                
                self.temperatureCircle?.setValue(value)
                self.temperatureCircle?.setText(Temperature(value))
                self.initializedTemperature = true
            }
        })
    }
    
    public func frequencyCallback(_ value: Double) {
        DispatchQueue.main.async(execute: {
            if let view = self.frequencyCircle, (view as NSView).isHidden {
                view.isHidden = false
            }
            
            if (self.window?.isVisible ?? false) || !self.initializedFrequency {
                if value > self.maxFreq {
                    self.maxFreq = value
                }
                
                if let freqCircle = self.frequencyCircle {
                    freqCircle.setValue((100*value)/self.maxFreq)
                    freqCircle.setText("\((value/1000).rounded(toPlaces: 2))\nGHz")
                }
                
                self.initializedFrequency = true
            }
        })
    }
    
    public func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initializedProcesses {
                return
            }
            
            if list.count != self.processes.count {
                self.processes.forEach { processView in
                    processView.clear()
                }
            }
            
            for i in 0..<list.count {
                self.processes[i].set(list[i])
                self.processes[i].value = "\(list[i].usage)%"
            }
            
            self.initializedProcesses = true
        })
    }
    
    public func limitCallback(_ value: CPU_Limit) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initializedLimits {
                return
            }
            
            self.shedulerLimitField?.stringValue = "\(value.scheduler)%"
            self.speedLimitField?.stringValue = "\(value.speed)%"
            
            self.initializedLimits = true
        })
    }
    
    public func averageCallback(_ value: [Double]) {
        guard value.count == 3 else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initializedAverage {
                return
            }
            
            self.average1Field?.stringValue = "\(value[0])"
            self.average5Field?.stringValue = "\(value[1])"
            self.average15Field?.stringValue = "\(value[2])"
            
            self.initializedAverage = true
        })
    }
    
    public func toggleFrequency(state: Bool) {
        DispatchQueue.main.async(execute: {
            if let view = self.frequencyCircle {
                view.isHidden = !state
            }
            self.initializedFrequency = false
        })
    }
}
