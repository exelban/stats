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
    private let chartHistory = LineChartData(capacity: 180)
    private var detailsHeight: CGFloat {
        get {
            var count: CGFloat = isARM ? 3 : 5
            if SystemKit.shared.device.info.cpu?.eCores != nil {
                count += 1
            }
            if SystemKit.shared.device.info.cpu?.sCores != nil {
                count += 1
            }
            if SystemKit.shared.device.info.cpu?.pCores != nil {
                count += 1
            }
            return (22*count) + Constants.Popup.separatorHeight
        }
    }
    private var frequencyHeight: CGFloat {
        get {
            var count: CGFloat = 1
            if SystemKit.shared.device.info.cpu?.eCores != nil {
                count += 1
            }
            if SystemKit.shared.device.info.cpu?.sCores != nil {
                count += 1
            }
            if SystemKit.shared.device.info.cpu?.pCores != nil {
                count += 1
            }
            return (22*count) + Constants.Popup.separatorHeight
        }
    }
    private let processHeight: CGFloat = 22
    
    private var temperatureField: NSTextField? = nil
    private var frequencyField: NSTextField? = nil
    private var uptimeField: NSTextField? = nil
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var shedulerLimitField: NSTextField? = nil
    private var speedLimitField: NSTextField? = nil
    private var eCoresField: NSTextField? = nil
    private var pCoresField: NSTextField? = nil
    private var sCoresField: NSTextField? = nil
    private var average1Field: NSTextField? = nil
    private var average5Field: NSTextField? = nil
    private var average15Field: NSTextField? = nil
    private var coresFreqField: NSTextField? = nil
    private var eCoresFreqField: NSTextField? = nil
    private var pCoresFreqField: NSTextField? = nil
    private var sCoresFreqField: NSTextField? = nil
    private var eCoresFreqColorView: NSView? = nil
    private var pCoresFreqColorView: NSView? = nil
    private var sCoresFreqColorView: NSView? = nil
    
    private var systemColorView: NSView? = nil
    private var userColorView: NSView? = nil
    private var idleColorView: NSView? = nil
    private var eCoresColorView: NSView? = nil
    private var pCoresColorView: NSView? = nil
    private var sCoresColorView: NSView? = nil
    
    private var chartPrefSection: PreferencesSection? = nil
    private var sliderView: NSView? = nil
    
    private var lineChart: LineChartView? = nil
    private var columnChart: ColumnChartView? = nil
    private var circle: PieChartView? = nil
    
    private let processCache = PopupCache<[TopProcess]>()
    private let loadCache = PopupCache<CPU_Load>()
    private let temperatureCache = PopupCache<Double?>()
    private let frequencyCache = PopupCache<CPU_Frequency?>()
    private let limitCache = PopupCache<CPU_Limit>()
    private let averageCache = PopupCache<CPU_AverageLoad>()
    
    private var processes: ProcessesView? = nil
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
    private var pCoresColorState: SColor = .indigo
    private var pCoresColor: NSColor { self.pCoresColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var sCoresColorState: SColor = .orange
    private var sCoresColor: NSColor { self.sCoresColorState.additional as? NSColor ?? NSColor.systemOrange }
    
    private var processesView: NSView? = nil
    
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
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.spacing = 0
        self.orientation = .vertical
        
        self.systemColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_systemColor", defaultValue: self.systemColorState.key))
        self.userColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_userColor", defaultValue: self.userColorState.key))
        self.idleColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_idleColor", defaultValue: self.idleColorState.key))
        self.chartColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_chartColor", defaultValue: self.chartColorState.key))
        self.eCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_eCoresColor", defaultValue: self.eCoresColorState.key))
        self.pCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_pCoresColor", defaultValue: self.pCoresColorState.key))
        self.sCoresColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_sCoresColor", defaultValue: self.sCoresColorState.key))
        self.lineChartHistory = Store.shared.int(key: "\(self.title)_lineChartHistory", defaultValue: self.lineChartHistory)
        self.chartHistory.resize(self.lineChartHistory)
        self.lineChartScale = Scale.fromString(Store.shared.string(key: "\(self.title)_lineChartScale", defaultValue: self.lineChartScale.key))
        self.lineChartFixedScale = Double(Store.shared.int(key: "\(self.title)_lineChartFixedScale", defaultValue: 100)) / 100
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadContent() {
        self.addSection(self.initDashboard())
        self.addSection(self.initChart())
        self.addSection(self.initDetails())
        self.addSection(self.initAverage())
        self.addSection(self.initProcesses())
        
        self.replay(self.frequencyCache, render: self.renderFrequency)
        
        self.resizeToFitContent()
    }
    
    public override func unloadContent() {
        self.temperatureField = nil
        self.frequencyField = nil
        self.uptimeField = nil
        self.systemField = nil
        self.userField = nil
        self.idleField = nil
        self.shedulerLimitField = nil
        self.speedLimitField = nil
        self.eCoresField = nil
        self.pCoresField = nil
        self.sCoresField = nil
        self.average1Field = nil
        self.average5Field = nil
        self.average15Field = nil
        self.coresFreqField = nil
        self.eCoresFreqField = nil
        self.pCoresFreqField = nil
        self.sCoresFreqField = nil
        self.eCoresFreqColorView = nil
        self.pCoresFreqColorView = nil
        self.sCoresFreqColorView = nil
        self.systemColorView = nil
        self.userColorView = nil
        self.idleColorView = nil
        self.eCoresColorView = nil
        self.pCoresColorView = nil
        self.sCoresColorView = nil
        self.lineChart = nil
        self.columnChart = nil
        self.circle = nil
        self.processes = nil
        self.processesView = nil
    }
    
    public override func appear() {
        self.uptimeField?.stringValue = self.uptimeValue
        self.replay(self.loadCache, render: self.renderLoad)
        self.replay(self.temperatureCache, render: self.renderTemperature)
        self.replay(self.frequencyCache, render: self.renderFrequency)
        self.replay(self.limitCache, render: self.renderLimit)
        self.replay(self.averageCache, render: self.renderAverage)
        self.replay(self.processCache, render: self.renderProcesses)
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    public override func updateLayer() {
        self.lineChart?.display()
    }
    
    // MARK: - Views
    
    private func initDashboard() -> NSView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: Constants.Popup.dashboardHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.margins
        view.edgeInsets = .init(top: Constants.Popup.margins, left: Constants.Popup.margins, bottom: Constants.Popup.margins, right: Constants.Popup.margins)
        
        let chart = PieChartView(drawValue: true, lineWidth: 10)
        chart.toolTip = localizedString("CPU usage")
        self.circle = chart
        
        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Constants.Popup.spacing*2
        
        let temperature = PopupDashboardDetailsRow(
            icon: "thermometer.variable",
            title: localizedString("Temperature"),
            dafaultValue: "n/a"
        )
        self.temperatureField = temperature.valueView
        let frequency = PopupDashboardDetailsRow(
            icon: "waveform.path.ecg",
            title: localizedString("Frequency"),
            dafaultValue: "n/a"
        )
        self.frequencyField = frequency.valueView
        let uptime = PopupDashboardDetailsRow(
            icon: "clock",
            title: localizedString("Uptime"),
            dafaultValue: self.uptimeValue
        )
        self.uptimeField = uptime.valueView
        
        details.addArrangedSubview(temperature)
        details.addArrangedSubview(frequency)
        details.addArrangedSubview(uptime)
        
        view.addArrangedSubview(chart)
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.alignment = .centerX
        view.spacing = Constants.Popup.spacing
        
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: 0), width: self.frame.width)
        view.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        
        let lineChart = LineChartView(color: self.chartColor, scale: self.lineChartScale, fixedScale: self.lineChartFixedScale, history: self.chartHistory)
        view.addArrangedSubview(lineChart)
        lineChart.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2).isActive = true
        lineChart.heightAnchor.constraint(equalToConstant: 70).isActive = true
        self.lineChart = lineChart
        
        if let cores = SystemKit.shared.device.info.cpu?.logicalCores {
            let inset = Constants.Popup.spacing
            let chart = ColumnChartView(num: Int(cores))
            view.addArrangedSubview(chart)
            
            view.setCustomSpacing(view.spacing + inset, after: lineChart)
            view.edgeInsets.bottom = inset
            
            chart.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2 * inset).isActive = true
            chart.heightAnchor.constraint(equalToConstant: 50 - 2 * inset).isActive = true
            
            self.columnChart = chart
        }
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
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
        if SystemKit.shared.device.info.cpu?.sCores != nil {
            (self.sCoresColorView, _, self.sCoresField) = popupWithColorRow(container, color: self.sCoresColor, title: "\(localizedString("Super cores")):", value: "")
        }
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initFrequency() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frequencyHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Frequency"), origin: NSPoint(x: 0, y: self.frequencyHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.coresFreqField = popupRow(container, title: "\(localizedString("All cores")):", value: "").1
        
        if isARM {
            if SystemKit.shared.device.info.cpu?.eCores != nil {
                (self.eCoresFreqColorView, _, self.eCoresFreqField) = popupWithColorRow(container, color: self.eCoresColor, title: "\(localizedString("Efficiency cores")):", value: "")
            }
            if SystemKit.shared.device.info.cpu?.pCores != nil {
                (self.pCoresFreqColorView, _, self.pCoresFreqField) = popupWithColorRow(container, color: self.pCoresColor, title: "\(localizedString("Performance cores")):", value: "")
            }
            if SystemKit.shared.device.info.cpu?.sCores != nil {
                (self.sCoresFreqColorView, _, self.sCoresFreqField) = popupWithColorRow(container, color: self.sCoresColor, title: "\(localizedString("Super cores")):", value: "")
            }
        }
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initAverage() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = Constants.Popup.spacing
        
        let separator = separatorView(localizedString("Average load"), width: self.frame.width)
        view.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        
        let blocks = PopupValuesBlocks()
        self.average1Field = blocks.addBlock(title: localizedString("1 minute"))
        self.average5Field = blocks.addBlock(title: localizedString("5 minutes"))
        self.average15Field = blocks.addBlock(title: localizedString("15 minutes"))
        view.addArrangedSubview(blocks)
        blocks.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        
        return view
    }
    
    private func initProcesses() -> NSView {
        if self.numberOfProcesses == 0 {
            let v = NSView()
            v.heightAnchor.constraint(equalToConstant: 0).isActive = true
            self.processesView = v
            return v
        }
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: ProcessesView = ProcessesView(
            frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y),
            values: [(localizedString("Usage"), nil)],
            n: self.numberOfProcesses
        )
        self.processes = container
        
        view.addSubview(separator)
        view.addSubview(container)
        
        self.processesView = view
        return view
    }
    
    // MARK: - Updates
    
    public func loadCallback(_ value: CPU_Load) {
        let date = Date()
        self.apply(value, to: self.loadCache, render: self.renderLoad)
        DispatchQueue.main.async {
            let sample = DoubleValue(value.totalUsage, at: date)
            self.chartHistory.append(sample)
            self.lineChart?.historyUpdated()
        }
    }
    
    private func renderLoad(_ value: CPU_Load) {
        self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
        self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
        self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
        
        self.circle?.toolTip = "\(localizedString("CPU usage")): \(Int(value.totalUsage.rounded(toPlaces: 2) * 100))%"
        self.circle?.setValue(value.totalUsage)
        self.circle?.setSegments([
            ColorValue(value.systemLoad, color: self.systemColor),
            ColorValue(value.userLoad, color: self.userColor)
        ])
        self.circle?.setNonActiveSegmentColor(self.idleColor)
        self.circle?.display()
        
        if let field = self.eCoresField, let usage = value.usageECores {
            field.stringValue = "\(Int(usage * 100))%"
        }
        if let field = self.pCoresField, let usage = value.usagePCores {
            field.stringValue = "\(Int(usage * 100))%"
        }
        if let field = self.sCoresField, let usage = value.usageSCores {
            field.stringValue = "\(Int(usage * 100))%"
        }
        
        var usagePerCore: [ColorValue] = []
        if let cores = SystemKit.shared.device.info.cpu?.cores, !cores.isEmpty {
            for i in 0..<value.usagePerCore.count {
                let core = cores.first(where: { $0.id == i })
                let color = core?.type == .efficiency ? self.eCoresColor : core?.type == .super ? self.sCoresColor : self.pCoresColor
                usagePerCore.append(ColorValue(value.usagePerCore[i], color: color))
            }
        } else {
            for i in 0..<value.usagePerCore.count {
                usagePerCore.append(ColorValue(value.usagePerCore[i], color: NSColor.systemBlue))
            }
        }
        self.columnChart?.setValues(usagePerCore)
        self.columnChart?.display()
        
        self.lineChart?.display()
    }
    
    public func temperatureCallback(_ value: Double?) {
        self.apply(value, to: self.temperatureCache, render: self.renderTemperature)
    }
    
    private func renderTemperature(_ value: Double?) {
        self.temperatureField?.stringValue = value.map { temperature($0) } ?? "—"
    }
    
    public func frequencyCallback(_ value: CPU_Frequency?) {
        self.apply(value, to: self.frequencyCache, render: self.renderFrequency)
    }
    
    private func renderFrequency(_ value: CPU_Frequency?) {
        self.frequencyField?.stringValue = value?.value.map { "\(($0/1000).rounded(toPlaces: 2)) GHz" } ?? "—"
        
        if self.coresFreqField == nil {
            guard let value, value.value != nil || value.eCore != nil || value.pCore != nil || value.sCore != nil else { return }
            self.addSection(self.initFrequency(), at: 3)
            self.resizeToFitContent()
        }
        
        self.coresFreqField?.stringValue = value?.value.map { "\(Int($0)) MHz" } ?? "—"
        self.eCoresFreqField?.stringValue = value?.eCore.map { "\(Int($0)) MHz" } ?? "—"
        self.pCoresFreqField?.stringValue = value?.pCore.map { "\(Int($0)) MHz" } ?? "—"
        self.sCoresFreqField?.stringValue = value?.sCore.map { "\(Int($0)) MHz" } ?? "—"
    }
    
    public func processCallback(_ list: [TopProcess]?) {
        guard let list else { return }
        self.apply(list, to: self.processCache, render: self.renderProcesses)
    }
    
    private func renderProcesses(_ list: [TopProcess]) {
        if list.count != self.processes?.count { self.processes?.clear() }
        
        for i in 0..<list.count {
            let process = list[i]
            self.processes?.set(i, process, ["\(process.usage)%"])
        }
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes?.count == self.numberOfProcesses { return }
        
        DispatchQueue.main.async(execute: {
            guard self.contentLoaded else { return }
            self.processesView?.removeFromSuperview()
            self.processesView = nil
            self.processes = nil
            self.addSection(self.initProcesses())
            self.processCache.initialized = false
            self.resizeToFitContent()
        })
    }
    
    public func limitCallback(_ value: CPU_Limit?) {
        guard let value else { return }
        self.apply(value, to: self.limitCache, render: self.renderLimit)
    }
    
    private func renderLimit(_ value: CPU_Limit) {
        self.shedulerLimitField?.stringValue = "\(value.scheduler)%"
        self.speedLimitField?.stringValue = "\(value.speed)%"
    }
    
    public func averageCallback(_ value: CPU_AverageLoad?) {
        guard let value else { return }
        self.apply(value, to: self.averageCache, render: self.renderAverage)
    }
    
    private func renderAverage(_ value: CPU_AverageLoad) {
        self.average1Field?.stringValue = "\(value.load1)"
        self.average5Field?.stringValue = "\(value.load5)"
        self.average15Field?.stringValue = "\(value.load15)"
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Keyboard shortcut"), component: KeyboardShartcutView(
                callback: self.setKeyboardShortcut,
                value: self.keyboardShortcut
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("System color"), component: self.colorSelectView(
                action: #selector(self.toggleSystemColor),
                items: SColor.allColors,
                selected: self.systemColorState.key
            )),
            PreferencesRow(localizedString("User color"), component: self.colorSelectView(
                action: #selector(self.toggleUserColor),
                items: SColor.allColors,
                selected: self.userColorState.key
            )),
            PreferencesRow(localizedString("Idle color"), component: self.colorSelectView(
                action: #selector(self.toggleIdleColor),
                items: SColor.allColors,
                selected: self.idleColorState.key
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Efficiency cores color"), component: self.colorSelectView(
                action: #selector(self.toggleECoresColor),
                items: SColor.allColors,
                selected: self.eCoresColorState.key
            )),
            PreferencesRow(localizedString("Performance cores color"), component: self.colorSelectView(
                action: #selector(self.togglePCoresColor),
                items: SColor.allColors,
                selected: self.pCoresColorState.key
            )),
            PreferencesRow(localizedString("Super cores color"), component: self.colorSelectView(
                action: #selector(self.toggleSCoresColor),
                items: SColor.allColors,
                selected: self.sCoresColorState.key
            ))
        ]))
        
        self.sliderView = self.sliderView(
            action: #selector(self.toggleLineChartFixedScale),
            value: Int(self.lineChartFixedScale * 100),
            initialValue: "\(Int(self.lineChartFixedScale * 100)) %"
        )
        self.chartPrefSection = PreferencesSection([
            PreferencesRow(localizedString("Chart color"), component: self.colorSelectView(
                action: #selector(self.toggleChartColor),
                items: SColor.allColors,
                selected: self.chartColorState.key
            )),
            PreferencesRow(localizedString("Chart history"), component: self.selectView(
                action: #selector(self.toggleLineChartHistory),
                items: LineChartHistory,
                selected: "\(self.lineChartHistory)"
            )),
            PreferencesRow(localizedString("Main chart scaling"), component: self.selectView(
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
        guard let key = sender.representedObject as? String else { return }
        self.systemColorState = SColor.fromString(key, defaultValue: self.systemColorState)
        Store.shared.set(key: "\(self.title)_systemColor", value: self.systemColorState.key)
        self.systemColorView?.layer?.backgroundColor = (self.systemColorState.additional as? NSColor)?.cgColor
    }
    @objc private func toggleUserColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.userColorState = SColor.fromString(key, defaultValue: self.userColorState)
        Store.shared.set(key: "\(self.title)_userColor", value: self.userColorState.key)
        self.userColorView?.layer?.backgroundColor = (self.userColorState.additional as? NSColor)?.cgColor
    }
    @objc private func toggleIdleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.idleColorState = SColor.fromString(key, defaultValue: self.idleColorState)
        Store.shared.set(key: "\(self.title)_idleColor", value: self.idleColorState.key)
        self.idleColorView?.layer?.backgroundColor = (self.idleColorState.additional as? NSColor)?.cgColor
    }
    @objc private func toggleChartColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.chartColorState = SColor.fromString(key, defaultValue: self.chartColorState)
        Store.shared.set(key: "\(self.title)_chartColor", value: self.chartColorState.key)
        if let color = self.chartColorState.additional as? NSColor {
            self.lineChart?.setColor(color)
        }
    }
    @objc private func toggleECoresColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.eCoresColorState = SColor.fromString(key, defaultValue: self.eCoresColorState)
        Store.shared.set(key: "\(self.title)_eCoresColor", value: self.eCoresColorState.key)
        if let color = (self.eCoresColorState.additional as? NSColor) {
            self.eCoresColorView?.layer?.backgroundColor = color.cgColor
            self.eCoresFreqColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func togglePCoresColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.pCoresColorState = SColor.fromString(key, defaultValue: self.pCoresColorState)
        Store.shared.set(key: "\(self.title)_pCoresColor", value: self.pCoresColorState.key)
        if let color = (self.pCoresColorState.additional as? NSColor) {
            self.pCoresColorView?.layer?.backgroundColor = color.cgColor
            self.pCoresFreqColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleSCoresColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.sCoresColorState = SColor.fromString(key, defaultValue: self.sCoresColorState)
        Store.shared.set(key: "\(self.title)_sCoresColor", value: self.sCoresColorState.key)
        if let color = (self.sCoresColorState.additional as? NSColor) {
            self.sCoresColorView?.layer?.backgroundColor = color.cgColor
            self.sCoresFreqColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleLineChartHistory(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.lineChartHistory = value
        self.chartHistory.resize(value)
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
