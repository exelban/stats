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

internal class Popup: NSView, Popup_p {
    private var title: String
    
    private var grid: NSGridView? = nil
    
    private let dashboardHeight: CGFloat = 90

    private let detailsHeight: CGFloat = (22 * 5) + Constants.Popup.separatorHeight
    private let batteryHeight: CGFloat = (22 * 4) + Constants.Popup.separatorHeight
    private let adapterHeight: CGFloat = (22 * 2) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = (22 * 1)
    
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
    private var cyclesField: NSTextField? = nil
    
    private var amperageField: NSTextField? = nil
    private var voltageField: NSTextField? = nil
    private var batteryPowerField: NSTextField? = nil
    private var temperatureField: NSTextField? = nil
    
    private var powerField: NSTextField? = nil
    private var chargingStateField: NSTextField? = nil
    
    private var processes: [ProcessView] = []
    private var processesInitialized: Bool = false
    
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
    private var timeFormat: String {
        get {
            return Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: "short")
        }
    }
    
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    public init(_ title: String) {
        self.title = title
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: self.dashboardHeight + self.detailsHeight + self.batteryHeight + self.adapterHeight
        ))
        self.setFrameSize(NSSize(width: self.frame.width, height: self.frame.height+self.processesHeight))
        
        let gridView: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        gridView.rowSpacing = 0
        gridView.yPlacement = .fill
        
        gridView.addRow(with: [self.initDashboard()])
        gridView.addRow(with: [self.initDetails()])
        gridView.addRow(with: [self.initBattery()])
        gridView.addRow(with: [self.initAdapter()])
        gridView.addRow(with: [self.initProcesses()])
        
        gridView.row(at: 0).height = self.dashboardHeight
        gridView.row(at: 1).height = self.detailsHeight
        gridView.row(at: 2).height = self.batteryHeight
        gridView.row(at: 3).height = self.adapterHeight
        
        self.addSubview(gridView)
        self.grid = gridView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes.count == self.numberOfProcesses {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.processes = []
            
            let h: CGFloat = self.dashboardHeight + self.detailsHeight + self.batteryHeight + self.adapterHeight + self.processesHeight
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.row(at: 4).cell(at: 0).contentView?.removeFromSuperview()
            self.grid?.removeRow(at: 4)
            self.grid?.addRow(with: [self.initProcesses()])
            self.processesInitialized = false
            
            self.sizeCallback?(self.frame.size)
        })
    }
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: self.dashboardHeight))
        
        self.dashboardBatteryView = BatteryView(frame: NSRect(x: Constants.Popup.margins, y: Constants.Popup.margins, width: view.frame.width - (Constants.Popup.margins*2), height: view.frame.height - (Constants.Popup.margins*2)))
        container.addSubview(self.dashboardBatteryView!)
        
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        let separator = SeparatorView(LocalizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))

        self.levelField = PopupRow(container, n: 4, title: "\(LocalizedString("Level")):", value: "").1
        self.sourceField = PopupRow(container, n: 3, title: "\(LocalizedString("Source")):", value: "").1
        let t = self.labelValue(container, n: 2, title: "\(LocalizedString("Time")):", value: "")
        self.timeLabelField = t.0
        self.timeField = t.1
        self.healthField = PopupRow(container, n: 1, title: "\(LocalizedString("Health")):", value: "").1
        self.cyclesField = PopupRow(container, n: 0, title: "\(LocalizedString("Cycles")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initBattery() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.batteryHeight))
        let separator = SeparatorView(LocalizedString("Battery"), origin: NSPoint(x: 0, y: self.batteryHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        self.amperageField = PopupRow(container, n: 3, title: "\(LocalizedString("Amperage")):", value: "").1
        self.voltageField = PopupRow(container, n: 2, title: "\(LocalizedString("Voltage")):", value: "").1
        self.batteryPowerField = PopupRow(container, n: 1, title: "\(LocalizedString("Power")):", value: "").1
        self.temperatureField = PopupRow(container, n: 0, title: "\(LocalizedString("Temperature")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initAdapter() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.adapterHeight))
        let separator = SeparatorView(LocalizedString("Power adapter"), origin: NSPoint(x: 0, y: self.adapterHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        self.powerField = PopupRow(container, n: 1, title: "\(LocalizedString("Power")):", value: "").1
        self.chargingStateField = PopupRow(container, n: 0, title: "\(LocalizedString("Is charging")):", value: "").1
        
        self.adapterView = view
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = SeparatorView(LocalizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        for i in 0..<self.numberOfProcesses {
            let processView = ProcessView(CGFloat(i))
            self.processes.append(processView)
            container.addSubview(processView)
        }
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
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
    
    public func usageCallback(_ value: Battery_Usage) {
        DispatchQueue.main.async(execute: {
            self.dashboardBatteryView?.setValue(abs(value.level))
            
            self.levelField?.stringValue = "\(Int(abs(value.level) * 100)) %"
            self.sourceField?.stringValue = LocalizedString(value.powerSource)
            self.timeField?.stringValue = ""
            
            if value.powerSource == "Battery Power" {
                self.timeLabelField?.stringValue = "\(LocalizedString("Time to discharge")):"
                if value.timeToEmpty != -1 && value.timeToEmpty != 0 {
                    self.timeField?.stringValue = Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds(short: self.timeFormat == "short")
                }
            } else {
                self.timeLabelField?.stringValue = "\(LocalizedString("Time to charge")):"
                if value.timeToCharge != -1 && value.timeToCharge != 0 {
                    self.timeField?.stringValue = Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds(short: self.timeFormat == "short")
                }
            }
            
            if value.timeToEmpty == -1 || value.timeToCharge == -1 {
                self.timeField?.stringValue = LocalizedString("Calculating")
            }
            
            if value.isCharged {
                self.timeField?.stringValue = LocalizedString("Fully charged")
            }
            
            self.healthField?.stringValue = "\(value.health)%"
            if let state = value.state {
                self.healthField?.stringValue += " (\(state))"
            }
            self.cyclesField?.stringValue = "\(value.cycles)"
            
            self.amperageField?.stringValue = "\(abs(value.amperage)) mA"
            self.voltageField?.stringValue = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
            let batteryPower = value.voltage * (Double(abs(value.amperage))/1000)
            self.batteryPowerField?.stringValue = "\(batteryPower.roundTo(decimalPlaces: 2)) W"
            self.temperatureField?.stringValue = "\(value.temperature) °C"
            
            self.powerField?.stringValue = value.powerSource == "Battery Power" ? LocalizedString("Not connected") : "\(value.ACwatts) W"
            self.chargingStateField?.stringValue = value.isCharging ? LocalizedString("Yes") : LocalizedString("No")
        })
    }
    
    public func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.processesInitialized {
                return
            }
            
            if list.count != self.processes.count {
                self.processes.forEach { processView in
                    processView.clear()
                }
            }
            
            for i in 0..<list.count {
                let process = list[i]
                let index = list.count-i-1
                self.processes[index].attachProcess(process)
                self.processes[index].value = "\(process.usage)%"
            }
            
            self.processesInitialized = true
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
