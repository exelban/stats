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

public class Popup: NSView {
    private let firstHeight: CGFloat = 90
    private let secondHeight: CGFloat = 92 // -26
    private let thirdHeight: CGFloat = 136 // -26
    
    private var loadField: NSTextField? = nil
    private var frequencyField: NSTextField? = nil
    private var temperatureField: NSTextField? = nil
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    
//    private var processes: [ProcessView] = [ProcessView(0), ProcessView(1), ProcessView(2), ProcessView(3), ProcessView(4)]
    
    public var chart: LineChartView? = nil
    private var ready: Bool = false
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: firstHeight + secondHeight + (Constants.Popup.margins*2)))
        
        initFirstView()
        initDescription()
//        initProcessesView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initProcessesView() {
        let y: CGFloat = Constants.Popup.margins*1
        let view: NSView = NSView(frame: NSRect(x: 0, y: y, width: self.frame.width, height: self.thirdHeight))
        
        addTitleSeparator("Top processes", view)
        
//        self.processes.forEach { (process: ProcessView) in
//            process.width = view.frame.width
//            view.addSubview(process)
//        }
        
        self.addSubview(view)
    }
    
    private func initDescription() {
        let y: CGFloat = self.frame.height - self.firstHeight - self.secondHeight - (Constants.Popup.margins*1)
        let view: NSView = NSView(frame: NSRect(x: 0, y: y, width: self.frame.width, height: self.secondHeight))
        
        addTitleSeparator("Overview", view)
        
        self.systemField = addSecondRow(mView: view, y: 44, title: "System:", value: "")
        self.userField = addSecondRow(mView: view, y: 22, title: "User:", value: "")
        self.idleField = addSecondRow(mView: view, y: 0, title: "Idle:", value: "")
        
        self.addSubview(view)
    }
    
    private func initFirstView() {
        let rightWidth: CGFloat = 110
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.firstHeight, width: self.frame.width, height: self.firstHeight))
        
        let leftPanel = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width - rightWidth - Constants.Popup.margins, height: view.frame.height))
        
        self.chart = LineChartView(frame: NSRect(x: 4, y: 3, width: leftPanel.frame.width, height: leftPanel.frame.height), num: 120)
        leftPanel.addSubview(self.chart!)
        
        let rightPanel: NSView = NSView(frame: NSRect(x: view.frame.width - rightWidth, y: 0, width: rightWidth, height: view.frame.height))
        self.loadField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)+20, title: "Load:", value: "")
        self.frequencyField = addFirstRow(mView: rightPanel, y: (rightPanel.frame.height - 16)/2, title: "Frequency:", value: "")
        self.temperatureField = addFirstRow(mView: rightPanel, y: ((rightPanel.frame.height - 16)/2)-20, title: "Temperature:", value: "")
        
        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
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
    
    private func addTitleSeparator(_ title: String, _ mView: NSView) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: mView.frame.height - 26, width: mView.frame.width, height: 26))
        
        let labelView: NSTextField = TextView(frame: NSRect(x: 0, y: (view.frame.height-15)/2, width: view.frame.width, height: 15))
        labelView.stringValue = title
        labelView.alignment = .center
        labelView.textColor = .secondaryLabelColor
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        labelView.stringValue = title
        
        view.addSubview(labelView)
        mView.addSubview(view)
    }
    
    private func addSecondRow(mView: NSView, y: CGFloat, title: String, value: String) -> NSTextField {
        let rowView: NSView = NSView(frame: NSRect(x: Constants.Popup.margins, y: y, width: mView.frame.width - (Constants.Popup.margins*2), height: 16))
        
        let labelWidth = title.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .regular)) + 5
        let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: 0.5, width: labelWidth, height: 15), title)
        let valueView: ValueField = ValueField(frame: NSRect(x: labelWidth, y: 0, width: rowView.frame.width - labelWidth, height: 16), value)
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        mView.addSubview(rowView)
        
        return valueView
    }
    
    public func loadCallback(_ value: CPULoad, freqValue: Double?, tempValue: Double?) {
        var frequency: String = "0 GHz"
        var temperature: String = "Unknown"
        
        DispatchQueue.main.async(execute: {
            if self.window!.isVisible || !self.ready {
                if tempValue != nil {
                    let formatter = MeasurementFormatter()
                    let measurement = Measurement(value: tempValue!.rounded(toPlaces: 0), unit: UnitTemperature.celsius)
                    temperature = formatter.string(from: measurement)
                }
                
                if freqValue != nil {
                    frequency = "\((freqValue!/1000).rounded(toPlaces: 2))GHz"
                }
                
                self.frequencyField?.stringValue = frequency
                self.temperatureField?.stringValue = temperature
                    
                self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
                self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
                self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
                    
                let v = Int(value.totalUsage.rounded(toPlaces: 2) * 100)
                self.loadField?.stringValue = "\(v)%"
                self.ready = true
            }
            
            self.chart?.addValue(value.totalUsage)
        })
    }
    
//    public func processesCallback(_ list: [TopProcess]) {
//        DispatchQueue.main.async(execute: {
//            for i in 0...self.processes.count-1 {
//                let process = self.processes[i]
//                process.label = list[i].command
//                process.value = "\(list[i].usage.roundTo(decimalPlaces: 2)) %"
//            }
//        })
//    }
}

private class ProcessView: NSView {
    public var width: CGFloat {
        get { return 0 }
        set {
            self.setFrameSize(NSSize(width: newValue, height: self.frame.height))
        }
    }
    
    public var label: String {
        get { return "" }
        set {
            self.labelView?.stringValue = newValue
        }
    }
    public var value: String {
        get { return "" }
        set {
            self.valueView?.stringValue = newValue
        }
    }
    
    private var labelView: LabelField? = nil
    private var valueView: ValueField? = nil
    
    init(_ n: CGFloat) {
        super.init(frame: NSRect(x: 0, y: n*22, width: Constants.Popup.width, height: 16))
        
        let rowView: NSView = NSView(frame: NSRect(x: Constants.Popup.margins, y: 0, width: self.frame.width - (Constants.Popup.margins*2), height: 16))
        
        let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: 0.5, width: 50, height: 15), "")
        let valueView: ValueField = ValueField(frame: NSRect(x: 50, y: 0, width: rowView.frame.width - 50, height: 16), "")
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        
        self.labelView = labelView
        self.valueView = valueView
        
        self.addSubview(rowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
