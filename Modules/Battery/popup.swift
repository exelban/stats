//
//  popup.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
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
    private let detailsHeight: CGFloat = 88
    private let batteryHeight: CGFloat = 66
    private let adapterHeight: CGFloat = 44
    private let processesHeight: CGFloat = 22*5
    
    private var dashboardView: NSView? = nil
    private var dashboardBatteryView: BatteryView? = nil
    private var detailsView: NSView? = nil
    private var batteryView: NSView? = nil
    private var adapterView: NSView? = nil
    
    private var levelField: NSTextField? = nil
    private var sourceField: NSTextField? = nil
    private var timeLabelField: NSTextField? = nil
    private var timeField: NSTextField? = nil
    private var healthField: NSTextField? = nil
    
    private var amperageField: NSTextField? = nil
    private var voltageField: NSTextField? = nil
    private var temperatureField: NSTextField? = nil
    
    private var powerField: NSTextField? = nil
    private var chargingStateField: NSTextField? = nil
    
    private var processes: [ProcessView] = []
    private var processesInitialized: Bool = false
    
    public init() {
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + detailsHeight + batteryHeight + adapterHeight + (Constants.Popup.separatorHeight * 4) + processesHeight
        ))
        
        self.initDashboard()
        self.initDetails()
        self.initBattery()
        self.initAdapter()
        self.initProcesses()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initDashboard() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        
        let batteryView: BatteryView = BatteryView(frame: NSRect(x: Constants.Popup.margins, y: Constants.Popup.margins, width: view.frame.width - (Constants.Popup.margins*2), height: view.frame.height - (Constants.Popup.margins*2)))
        view.addSubview(batteryView)
        
        self.addSubview(view)
        self.dashboardView = view
        self.dashboardBatteryView = batteryView
    }
    
    private func initDetails() {
        let y: CGFloat = self.dashboardView!.frame.origin.y - Constants.Popup.separatorHeight
        let separator = SeparatorView(LocalizedString("Details"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.detailsHeight, width: self.frame.width, height: self.detailsHeight))
        
        self.levelField = PopupRow(view, n: 3, title: "\(LocalizedString("Details"))Level:", value: "")
        self.sourceField = PopupRow(view, n: 2, title: "\(LocalizedString("Source")):", value: "")
        let t = self.labelValue(view, n: 1, title: "\(LocalizedString("Time")):", value: "")
        self.timeLabelField = t.0
        self.timeField = t.1
        self.healthField = PopupRow(view, n: 0, title: "\(LocalizedString("Health")):", value: "")
        
        self.addSubview(view)
        self.detailsView = view
    }

    private func labelValue(_ view: NSView, n: CGFloat, title: String, value: String) -> (NSTextField, NSTextField) {
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: 22*n, width: view.frame.width, height: 22))
        
        let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: (22-15)/2, width: view.frame.width/2, height: 15), title)
        let valueView: ValueField = ValueField(frame: NSRect(x: view.frame.width/2, y: (22-16)/2, width: view.frame.width/2, height: 16), value)
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        view.addSubview(rowView)
        
        return (labelView, valueView)
    }
    
    private func initBattery() {
        let y: CGFloat = self.detailsView!.frame.origin.y - Constants.Popup.separatorHeight
        let separator = SeparatorView(LocalizedString("Battery"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.batteryHeight, width: self.frame.width, height: self.batteryHeight))
        
        self.amperageField = PopupRow(view, n: 2, title: "\(LocalizedString("Amperage")):", value: "")
        self.voltageField = PopupRow(view, n: 1, title: "\(LocalizedString("Voltage")):", value: "")
        self.temperatureField = PopupRow(view, n: 0, title: "\(LocalizedString("Temperature")):", value: "")
        
        self.addSubview(view)
        self.batteryView = view
    }
    
    private func initAdapter() {
        let y: CGFloat = self.batteryView!.frame.origin.y - Constants.Popup.separatorHeight
        let separator = SeparatorView(LocalizedString("Power adapter"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.adapterHeight, width: self.frame.width, height: self.adapterHeight))
        
        self.powerField = PopupRow(view, n: 1, title: "\(LocalizedString("Power")):", value: "")
        self.chargingStateField = PopupRow(view, n: 0, title: "\(LocalizedString("Is charging")):", value: "")
        
        self.addSubview(view)
        self.adapterView = view
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
    
    public func usageCallback(_ value: Battery_Usage) {
        DispatchQueue.main.async(execute: {
            self.dashboardBatteryView?.setValue(abs(value.level))
            
            self.levelField?.stringValue = "\(Int(abs(value.level) * 100)) %"
            self.sourceField?.stringValue = value.powerSource
            self.timeField?.stringValue = ""
            
            if value.powerSource == "Battery Power" {
                self.timeLabelField?.stringValue = "\(LocalizedString("Time to discharge")):"
                if value.timeToEmpty != -1 && value.timeToEmpty != 0 {
                    self.timeField?.stringValue = Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()
                }
            } else {
                self.timeLabelField?.stringValue = "\(LocalizedString("Time to charge")):"
                if value.timeToCharge != -1 && value.timeToCharge != 0 {
                    self.timeField?.stringValue = Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds()
                }
            }
            
            if value.timeToEmpty == -1 || value.timeToCharge == -1 {
                self.timeField?.stringValue = LocalizedString("Calculating")
            }
            
            if value.isCharged {
                self.timeField?.stringValue = LocalizedString("Fully charged")
            }
            
            self.healthField?.stringValue = "\(value.health) % (\(value.state))"
            
            self.amperageField?.stringValue = "\(abs(value.amperage)) mA"
            self.voltageField?.stringValue = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
            self.temperatureField?.stringValue = "\(value.temperature) °C"
            
            self.powerField?.stringValue = value.powerSource == "Battery Power" ? LocalizedString("Not connected") : "\(value.ACwatts) W"
            self.chargingStateField?.stringValue = value.isCharging ? LocalizedString("Yes") : LocalizedString("No")
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

private class BatteryView: NSView {
    private var percentage: Double = 0
    
    public override init(frame: NSRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let w: CGFloat = 130
        let h: CGFloat = 50
        let x: CGFloat = (dirtyRect.width - w)/2
        let y: CGFloat = (dirtyRect.size.height - h) / 2
        let radius: CGFloat = 3
        let batteryFrame = NSBezierPath(roundedRect: NSRect(x: x+1, y: y, width: w, height: h), xRadius: radius, yRadius: radius)
        NSColor.textColor.set()
        
        let bPX: CGFloat = x+w+1
        let bPY: CGFloat = (dirtyRect.size.height / 2) - 4
        let batteryPoint = NSBezierPath(roundedRect: NSRect(x: bPX, y: bPY, width: 4, height: 8), xRadius: radius, yRadius: radius)
        batteryPoint.lineWidth = 1.1
        batteryPoint.stroke()
        batteryPoint.fill()
        
        batteryFrame.lineWidth = 1
        batteryFrame.stroke()
        
        let maxWidth = w-2
        let inner = NSBezierPath(roundedRect: NSRect(x: x+2, y: y+1, width: maxWidth * CGFloat(self.percentage), height: h-2), xRadius: radius, yRadius: radius)
        self.percentage.batteryColor(color: true).set()
        inner.lineWidth = 0
        inner.stroke()
        inner.close()
        inner.fill()
    }
    
    public func setValue(_ value: Double) {
        if self.percentage == value {
            return
        }
        
        self.percentage = value
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
