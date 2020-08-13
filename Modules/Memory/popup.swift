//
//  popup.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 18/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSView {
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90
    private let detailsHeight: CGFloat = 22*6
    private let processesHeight: CGFloat = 22*5
    
    private var totalField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var activeField: NSTextField? = nil
    private var inactiveField: NSTextField? = nil
    private var wiredField: NSTextField? = nil
    private var compressedField: NSTextField? = nil
    
    private var chart: LineChartView? = nil
    private var circle: CircleGraphView? = nil
    private var initialized: Bool = false
    
    private var processes: [ProcessView] = []
    
    public init() {
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
        self.circle!.toolTip = "RAM usage"
        container.addSubview(self.circle!)
        
        view.addSubview(container)
        self.addSubview(view)
    }
    
    private func initChart() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - Constants.Popup.separatorHeight
        let separator = SeparatorView("History", origin: NSPoint(x: 0, y: y), width: self.frame.width)
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
        let separator = SeparatorView("Details", origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.detailsHeight, width: self.frame.width, height: self.detailsHeight))
        
        self.totalField = PopupRow(view, n: 5, title: "Total:", value: "")
        self.usedField = PopupRow(view, n: 4, title: "Used:", value: "")
        
        self.activeField = PopupWithColorRow(view, color: NSColor.systemBlue, n: 3, title: "App:", value: "")
        self.wiredField = PopupWithColorRow(view, color: NSColor.systemOrange, n: 2, title: "Wired:", value: "")
        self.compressedField = PopupWithColorRow(view, color: NSColor.systemPink, n: 1, title: "Compressed:", value: "")
        self.freeField = PopupWithColorRow(view, color: NSColor.lightGray.withAlphaComponent(0.5), n: 0, title: "Free:", value: "")
        
        self.addSubview(view)
    }
    
    private func initProcesses() {
        let separator = SeparatorView("Top processes", origin: NSPoint(x: 0, y: self.processesHeight), width: self.frame.width)
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
    
    public func loadCallback(_ value: RAM_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.activeField?.stringValue = Units(bytes: Int64(value.active)).getReadableMemory()
                self.inactiveField?.stringValue = Units(bytes: Int64(value.inactive)).getReadableMemory()
                self.wiredField?.stringValue = Units(bytes: Int64(value.wired)).getReadableMemory()
                self.compressedField?.stringValue = Units(bytes: Int64(value.compressed)).getReadableMemory()

                self.totalField?.stringValue = Units(bytes: Int64(value.total)).getReadableMemory()
                self.usedField?.stringValue = Units(bytes: Int64(value.used)).getReadableMemory()
                self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory()
                self.initialized = true
            }
            
            self.circle?.setValue(value.usage)
            self.circle?.setSegments([
                circle_segment(value: value.active/value.total, color: NSColor.systemBlue),
                circle_segment(value: value.wired/value.total, color: NSColor.systemOrange),
                circle_segment(value: value.compressed/value.total, color: NSColor.systemPink)
            ])
            self.chart?.addValue(value.usage)
        })
    }
    
    public func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            for i in 0..<list.count {
                let process = list[i]
                let index = list.count-i-1
                if self.processes.indices.contains(index) {
                    self.processes[index].label = process.name != nil ? process.name! : process.command
                    self.processes[index].value = Units(bytes: Int64(process.usage)).getReadableMemory()
                    self.processes[index].icon = process.icon
                }
            }
        })
    }
}
