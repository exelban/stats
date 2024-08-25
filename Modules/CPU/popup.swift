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

internal class Popup: PopupWrapper {
    private var title: String
    
    private var grid: NSGridView? = nil
    
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 120 + Constants.Popup.separatorHeight
    private var detailsHeight: CGFloat {
        get {
            var count: CGFloat = isARM ? 4 : 6
            if SystemKit.shared.device.info.cpu?.eCores != nil {
                count += 1
            }
            if SystemKit.shared.device.info.cpu?.pCores != nil {
                count += 1
            }
            return (22*count) + Constants.Popup.separatorHeight
        }
    }
    private let averageHeight: CGFloat = (22*3) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = 22
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var shedulerLimitField: NSTextField? = nil
    private var speedLimitField: NSTextField? = nil
    private var eCoresField: NSTextField? = nil
    private var pCoresField: NSTextField? = nil
    private var uptimeField: NSTextField? = nil
    private var average1Field: NSTextField? = nil
    private var average5Field: NSTextField? = nil
    private var average15Field: NSTextField? = nil
    
    private var systemColorView: NSView? = nil
    private var userColorView: NSView? = nil
    private var idleColorView: NSView? = nil
    private var eCoresColorView: NSView? = nil
    private var pCoresColorView: NSView? = nil
    
    private var chartPrefSection: PreferencesSection? = nil
    private var sliderView: NSView? = nil
    
    private var lineChart: LineChartView? = nil
    private var barChart: BarChartView? = nil
    private var circle: PieChartView? = nil
    private var temperatureCircle: HalfCircleGraphView? = nil
    private var frequencyCircle: HalfCircleGraphView? = nil
    private var initialized: Bool = false
    private var initializedTemperature: Bool = false
    private var initializedFrequency: Bool = false
    private var initializedProcesses: Bool = false
    private var initializedLimits: Bool = false
    private var initializedAverage: Bool = false
    
    private var processes: ProcessesView? = nil
    private var maxFreq: Double = 0
    private var lineChartHistory: Int = 180
    private var lineChartScale: Scale = .none
    private var lineChartFixedScale: Double = 1
    
    private var systemColorState: SColor = .secondRed
    private var systemColor: NSColor { self.systemColorState.additional as? NSColor ?? NSColor.systemRed }
    private var userColorState: SColor = .secondBlue
    private var userColor: NSColor { self.userColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var idleColorState: SColor = .lightGray
    private var idleColor: NSColor { self.idleColorState.additional as? NSColor ?? NSColor.lightGray }
    private var chartColorState: SColor = .systemAccent
    private var chartColor: NSColor { self.chartColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var eCoresColorState: SColor = .teal
    private var eCoresColor: NSColor { self.eCoresColorState.additional as? NSColor ?? NSColor.systemTeal }
    private var pCoresColorState: SColor = .secondBlue
    private var pCoresColor: NSColor { self.pCoresColorState.additional as? NSColor ?? NSColor.systemBlue }
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (self.processHeight*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    private var uptimeValue: String {
        let form = DateComponentsFormatter()
        form.maximumUnitCount = 2
        form.unitsStyle = .full
        form.allowedUnits = [.day, .hour, .minute]
        var value = localizedString("Unknown")
        if let bootDate = SystemKit.shared.device.bootDate {
            if let duration = form.string(from: bootDate, to: Date()) {
                value = duration
            }
        }
        return value
    }
    
    public init(_ module: ModuleType) {
        self.title = module.rawValue
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: self.dashboardHeight + self.chartHeight + self.averageHeight
        ))
        self.setFrameSize(NSSize(width: self.frame.width, height: self.frame.height + self.detailsHeight + self.processesHeight))
        
        self.systemColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_systemColor", defaultValue: self.systemColorState.key))
        self.userColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_userColor", defaultValue: self.userColorState.key))
        self.idleColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_idleColor", defaultValue: self.idleColorState.key))
        self.chartColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_chartColor", defaultValue: self.chartColorState.key))
        self.eCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_eCoresColor", defaultValue: self.eCoresColorState.key))
        self.pCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_pCoresColor", defaultValue: self.pCoresColorState.key))
        self.lineChartHistory = Store.shared.int(key: "\(self.title)_lineChartHistory", defaultValue: self.lineChartHistory)
        self.lineChartScale = Scale.fromString(Store.shared.string(key: "\(self.title)_lineChartScale", defaultValue: self.lineChartScale.key))
        self.lineChartFixedScale = Double(Store.shared.int(key: "\(self.title)_lineChartFixedScale", defaultValue: 100)) / 100
        
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
        self.lineChart?.display()
    }
    
    public override func appear() {
        self.uptimeField?.stringValue = self.uptimeValue
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes?.count == self.numberOfProcesses { return }
        
        DispatchQueue.main.async(execute: {
            let h: CGFloat = self.dashboardHeight + self.chartHeight + self.detailsHeight + self.averageHeight + self.processesHeight
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.row(at: 4).cell(at: 0).contentView?.removeFromSuperview()
            self.processes = nil
            self.grid?.removeRow(at: 4)
            self.grid?.addRow(with: [self.initProcesses()])
            self.initializedProcesses = false
            
            self.sizeCallback?(self.frame.size)
        })
    }
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.dashboardHeight))
        
        let usageSize = self.dashboardHeight-20
        let usageX = (view.frame.width - usageSize)/2
        
        let usage = NSView(frame: NSRect(x: usageX, y: (view.frame.height - usageSize)/2, width: usageSize, height: usageSize))
        let temperature = NSView(frame: NSRect(x: (usageX - 50)/2, y: (view.frame.height - 50)/2 - 3, width: 50, height: 50))
        let frequency = NSView(frame: NSRect(x: (usageX+usageSize) + (usageX - 50)/2, y: (view.frame.height - 50)/2 - 3, width: 50, height: 50))
        
        self.circle = PieChartView(frame: NSRect(x: 0, y: 0, width: usage.frame.width, height: usage.frame.height), segments: [], drawValue: true)
        self.circle!.toolTip = localizedString("CPU usage")
        usage.addSubview(self.circle!)
        
        self.temperatureCircle = HalfCircleGraphView(frame: NSRect(x: 0, y: 0, width: temperature.frame.width, height: temperature.frame.height))
        self.temperatureCircle!.toolTip = localizedString("CPU temperature")
        (self.temperatureCircle! as NSView).isHidden = true
        temperature.addSubview(self.temperatureCircle!)
        
        self.frequencyCircle = HalfCircleGraphView(frame: NSRect(x: 0, y: 0, width: frequency.frame.width, height: frequency.frame.height))
        self.frequencyCircle!.toolTip = localizedString("CPU frequency")
        (self.frequencyCircle! as NSView).isHidden = true
        frequency.addSubview(self.frequencyCircle!)
        
        view.addSubview(temperature)
        view.addSubview(usage)
        view.addSubview(frequency)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        view.orientation = .vertical
        view.spacing = 0
        
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: 0), width: self.frame.width)
        
        let lineChartContainer: NSView = {
            let box: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 70))
            box.heightAnchor.constraint(equalToConstant: box.frame.height).isActive = true
            box.wantsLayer = true
            box.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
            box.layer?.cornerRadius = 3
            
            let chartFrame = NSRect(x: 1, y: 0, width: box.frame.width, height: box.frame.height)
            self.lineChart = LineChartView(frame: chartFrame, num: self.lineChartHistory, scale: self.lineChartScale, fixedScale: self.lineChartFixedScale)
            self.lineChart?.color = self.chartColor
            box.addSubview(self.lineChart!)
            
            return box
        }()
        
        view.addArrangedSubview(separator)
        view.addArrangedSubview(lineChartContainer)
        
        if let cores = SystemKit.shared.device.info.cpu?.logicalCores {
            let barChartContainer: NSView = {
                let box: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 50))
                box.heightAnchor.constraint(equalToConstant: box.frame.height).isActive = true
                box.wantsLayer = true
                box.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
                box.layer?.cornerRadius = 3
                
                let chart = BarChartView(frame: NSRect(
                    x: Constants.Popup.spacing,
                    y: Constants.Popup.spacing,
                    width: view.frame.width - (Constants.Popup.spacing*2),
                    height: box.frame.height - (Constants.Popup.spacing*2)
                ), num: Int(cores))
                self.barChart = chart
                
                box.addSubview(chart)
                
                return box
            }()
            view.addArrangedSubview(barChartContainer)
        }
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        let separator = separatorView(localizedString("Details"), origin: NSPoint(
            x: 0,
            y: self.detailsHeight-Constants.Popup.separatorHeight
        ), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        (self.systemColorView, _, self.systemField) = popupWithColorRow(container, color: self.systemColor, title: "\(localizedString("System")):", value: "")
        (self.userColorView, _, self.userField) = popupWithColorRow(container, color: self.userColor, title: "\(localizedString("User")):", value: "")
        (self.idleColorView, _, self.idleField) = popupWithColorRow(container, color: self.idleColor.withAlphaComponent(0.5), title: "\(localizedString("Idle")):", value: "")
        
        if !isARM {
            self.shedulerLimitField = popupRow(container, title: "\(localizedString("Scheduler limit")):", value: "").1
            self.speedLimitField = popupRow(container, title: "\(localizedString("Speed limit")):", value: "").1
        }
        
        if SystemKit.shared.device.info.cpu?.eCores != nil {
            (self.eCoresColorView, _, self.eCoresField) = popupWithColorRow(container, color: self.eCoresColor, title: "\(localizedString("Efficiency cores")):", value: "")
        }
        if SystemKit.shared.device.info.cpu?.pCores != nil {
            (self.pCoresColorView, _, self.pCoresField) = popupWithColorRow(container, color: self.pCoresColor, title: "\(localizedString("Performance cores")):", value: "")
        }
        
        self.uptimeField = popupRow(container, title: "\(localizedString("Uptime")):", value: self.uptimeValue).1
        self.uptimeField?.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initAverage() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.averageHeight))
        let separator = separatorView(localizedString("Average load"), origin: NSPoint(x: 0, y: self.averageHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.average1Field = popupRow(container, title: "\(localizedString("1 minute")):", value: "").1
        self.average5Field = popupRow(container, title: "\(localizedString("5 minutes")):", value: "").1
        self.average15Field = popupRow(container, title: "\(localizedString("15 minutes")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView {
        if self.numberOfProcesses == 0 { return NSView() }
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: ProcessesView = ProcessesView(
            frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y),
            values: [(localizedString("Usage"), nil)],
            n: self.numberOfProcesses
        )
        self.processes = container
        
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
                    circle_segment(value: value.systemLoad, color: self.systemColor),
                    circle_segment(value: value.userLoad, color: self.userColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.idleColor)
                
                if let field = self.eCoresField, let usage = value.usageECores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                if let field = self.pCoresField, let usage = value.usagePCores {
                    field.stringValue = "\(Int(usage * 100))%"
                }
                
                var usagePerCore: [ColorValue] = []
                if let cores = SystemKit.shared.device.info.cpu?.cores, cores.count == value.usagePerCore.count {
                    for i in 0..<value.usagePerCore.count {
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: cores[i].type == .efficiency ? self.eCoresColor : self.pCoresColor))
                    }
                } else {
                    for i in 0..<value.usagePerCore.count {
                        usagePerCore.append(ColorValue(value.usagePerCore[i], color: NSColor.systemBlue))
                    }
                }
                self.barChart?.setValues(usagePerCore)
                
                self.initialized = true
            }
            self.lineChart?.addValue(value.totalUsage)
        })
    }
    
    public func temperatureCallback(_ value: Double?) {
        guard let value else { return }
        
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initializedTemperature {
                if let view = self.temperatureCircle, (view as NSView).isHidden {
                    view.isHidden = false
                }
                
                self.temperatureCircle?.setValue(value)
                self.temperatureCircle?.setText(temperature(value))
                self.initializedTemperature = true
            }
        })
    }
    
    public func frequencyCallback(_ value: Double?) {
        guard let value else { return }
        
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
                    freqCircle.setText("\((value/1000).rounded(toPlaces: 2))")
                }
                
                self.initializedFrequency = true
            }
        })
    }
    
    public func processCallback(_ list: [TopProcess]?) {
        guard let list else { return }
        
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initializedProcesses {
                return
            }
            let list = list.map { $0 }
            if list.count != self.processes?.count { self.processes?.clear() }
            
            for i in 0..<list.count {
                let process = list[i]
                self.processes?.set(i, process, ["\(process.usage)%"])
            }
            
            self.initializedProcesses = true
        })
    }
    
    public func limitCallback(_ value: CPU_Limit?) {
        guard let value else { return }
        
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initializedLimits {
                return
            }
            
            self.shedulerLimitField?.stringValue = "\(value.scheduler)%"
            self.speedLimitField?.stringValue = "\(value.speed)%"
            
            self.initializedLimits = true
        })
    }
    
    public func averageCallback(_ value: [Double]?) {
        guard let value, value.count == 3 else { return }
        
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
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("System color"), component: selectView(
                action: #selector(self.toggleSystemColor),
                items: SColor.allColors,
                selected: self.systemColorState.key
            )),
            PreferencesRow(localizedString("User color"), component: selectView(
                action: #selector(self.toggleUserColor),
                items: SColor.allColors,
                selected: self.userColorState.key
            )),
            PreferencesRow(localizedString("Idle color"), component: selectView(
                action: #selector(self.toggleIdleColor),
                items: SColor.allColors,
                selected: self.idleColorState.key
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Efficiency cores color"), component: selectView(
                action: #selector(self.toggleECoresColor),
                items: SColor.allColors,
                selected: self.eCoresColorState.key
            )),
            PreferencesRow(localizedString("Performance cores color"), component: selectView(
                action: #selector(self.togglePCoresColor),
                items: SColor.allColors,
                selected: self.pCoresColorState.key
            ))
        ]))
        
        self.sliderView = sliderView(
            action: #selector(self.toggleLineChartFixedScale),
            value: Int(self.lineChartFixedScale * 100),
            initialValue: "\(Int(self.lineChartFixedScale * 100)) %"
        )
        self.chartPrefSection = PreferencesSection([
            PreferencesRow(localizedString("Chart color"), component: selectView(
                action: #selector(self.toggleChartColor),
                items: SColor.allColors,
                selected: self.chartColorState.key
            )),
            PreferencesRow(localizedString("Chart history"), component: selectView(
                action: #selector(self.toggleLineChartHistory),
                items: LineChartHistory,
                selected: "\(self.lineChartHistory)"
            )),
            PreferencesRow(localizedString("Main chart scaling"), component: selectView(
                action: #selector(self.toggleLineChartScale),
                items: Scale.allCases,
                selected: self.lineChartScale.key
            )),
            PreferencesRow(localizedString("Scale value"), component: self.sliderView!)
        ])
        view.addArrangedSubview(self.chartPrefSection!)
        self.chartPrefSection?.setRowVisibility(3, newState: self.lineChartScale == .fixed)
        
        return view
    }
    
    @objc private func toggleSystemColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.systemColorState = newValue
        Store.shared.set(key: "\(self.title)_systemColor", value: key)
        self.systemColorView?.layer?.backgroundColor = (newValue.additional as? NSColor)?.cgColor
    }
    @objc private func toggleUserColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.userColorState = newValue
        Store.shared.set(key: "\(self.title)_userColor", value: key)
        self.userColorView?.layer?.backgroundColor = (newValue.additional as? NSColor)?.cgColor
    }
    @objc private func toggleIdleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.idleColorState = newValue
        Store.shared.set(key: "\(self.title)_idleColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.idleColorView?.layer?.backgroundColor = color.cgColor
        }
        self.idleColorView?.layer?.backgroundColor = (newValue.additional as? NSColor)?.cgColor
    }
    @objc private func toggleChartColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.chartColorState = newValue
        Store.shared.set(key: "\(self.title)_chartColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.lineChart?.color = color
        }
    }
    @objc private func toggleECoresColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.eCoresColorState = newValue
        Store.shared.set(key: "\(self.title)_eCoresColor", value: key)
        self.eCoresColorView?.layer?.backgroundColor = (newValue.additional as? NSColor)?.cgColor
    }
    @objc private func togglePCoresColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.pCoresColorState = newValue
        Store.shared.set(key: "\(self.title)_pCoresColor", value: key)
        self.pCoresColorView?.layer?.backgroundColor = (newValue.additional as? NSColor)?.cgColor
    }
    @objc private func toggleLineChartHistory(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.lineChartHistory = value
        Store.shared.set(key: "\(self.title)_lineChartHistory", value: value)
        self.lineChart?.reinit(self.lineChartHistory)
    }
    @objc private func toggleLineChartScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.chartPrefSection?.setRowVisibility(3, newState: value == .fixed)
        self.lineChartScale = value
        self.lineChart?.setScale(self.lineChartScale, fixedScale: self.lineChartFixedScale)
        Store.shared.set(key: "\(self.title)_lineChartScale", value: key)
        self.display()
    }
    @objc private func toggleLineChartFixedScale(_ sender: NSSlider) {
        let value = Int(sender.doubleValue)
        
        if let field = self.sliderView?.subviews.first(where: { $0 is NSTextField }), let view = field as? NSTextField {
            view.stringValue = "\(value) %"
        }
        
        self.lineChartFixedScale = sender.doubleValue / 100
        self.lineChart?.setScale(self.lineChartScale, fixedScale: self.lineChartFixedScale)
        Store.shared.set(key: "\(self.title)_lineChartFixedScale", value: value)
    }
}
