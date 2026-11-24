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
import Kit

internal class Popup: PopupWrapper {
    private let chartHistory = LineChartData(capacity: 180)
    private let memoryHistory = LineChartData(capacity: 180)
    private let chartHeight: CGFloat = 90
    
    private let loadCache = PopupCache<GPU_Info>()
    private let processesCache = PopupCache<[TopProcess]>()
    private var processes: ProcessesView? = nil
    private var processesView: NSView? = nil
    
    private var numberOfProcesses: Int {
        #if arch(arm64)
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        #else
        0
        #endif
    }
    private var processesHeight: CGFloat {
        (22*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    
    private var usageCircle: PieChartView? = nil
    
    private var chart: LineChartView? = nil
    private var memoryChart: LineChartView? = nil
    private var lineChartHistory: Int = 180
    private var lineChartScale: Scale = .none
    private var lineChartFixedScale: Double = 1
    
    private var aneField: NSTextField? = nil
    private var memoryField: NSTextField? = nil
    private var fpsField: NSTextField? = nil
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadContent() {
        self.addSection(self.initDashboard())
        self.addSection(self.initChart())
        self.addSection(self.initProcesses())
        
        self.resizeToFitContent()
    }
    
    public override func unloadContent() {
        self.processes = nil
        self.processesView = nil
        self.usageCircle = nil
        self.aneField = nil
        self.memoryField = nil
        self.fpsField = nil
        self.chart = nil
        self.memoryChart = nil
    }
    
    public override func appear() {
        self.replay(self.loadCache, render: self.renderLoad)
        self.replay(self.processesCache, render: self.renderProcesses)
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    public override func updateLayer() {
        self.chart?.display()
        self.memoryChart?.display()
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
        chart.toolTip = localizedString("GPU utilization")
        self.usageCircle = chart
        
        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Constants.Popup.spacing*2
        
        let ane = PopupDashboardDetailsRow(
            icon: "cpu",
            title: localizedString("ANE utilization"),
            dafaultValue: "n/a"
        )
        self.aneField = ane.valueView
        let memory = PopupDashboardDetailsRow(
            icon: "memorychip",
            title: localizedString("Memory usage"),
            dafaultValue: "n/a"
        )
        self.memoryField = memory.valueView
        let fps = PopupDashboardDetailsRow(
            icon: "waveform.path.ecg",
            title: "FPS",
            dafaultValue: "n/a"
        )
        self.fpsField = fps.valueView
        
        details.addArrangedSubview(ane)
        details.addArrangedSubview(memory)
        details.addArrangedSubview(fps)
        
        view.addArrangedSubview(chart)
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.alignment = .centerX
        view.spacing = Constants.Popup.spacing
        
        let separator = separatorView(localizedString("Usage history"), width: self.frame.width)
        let chart = LineChartView(scale: self.lineChartScale, fixedScale: self.lineChartFixedScale, history: self.chartHistory)
        self.chart = chart
        
        let memorySeparator = separatorView(localizedString("Memory usage history"), width: self.frame.width)
        let memoryChart = LineChartView(scale: .linear, history: self.memoryHistory)
        memoryChart.setToolTipFunc { value in
            Units(bytes: Int64(value.value)).getReadableMemory(style: .memory)
        }
        self.memoryChart = memoryChart
        
        view.addArrangedSubview(separator)
        view.addArrangedSubview(chart)
        view.addArrangedSubview(memorySeparator)
        view.addArrangedSubview(memoryChart)
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalTo: view.widthAnchor),
            chart.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2),
            chart.heightAnchor.constraint(equalToConstant: self.chartHeight),
            memorySeparator.widthAnchor.constraint(equalTo: view.widthAnchor),
            memoryChart.widthAnchor.constraint(equalTo: chart.widthAnchor),
            memoryChart.heightAnchor.constraint(equalTo: chart.heightAnchor, multiplier: 0.5)
        ])
        
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
        view.heightAnchor.constraint(equalToConstant: self.processesHeight).isActive = true
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
    
    public func processCallback(_ list: [TopProcess]?) {
        guard let list else { return }
        self.apply(list, to: self.processesCache, render: self.renderProcesses)
    }
    
    private func renderProcesses(_ list: [TopProcess]) {
        guard let view = self.processes else { return }
        
        for i in 0..<view.count {
            if list.indices.contains(i) {
                let process = list[i]
                view.set(i, process, [String(format: "%.1f%%", process.usage)])
            } else {
                view.set(i, nil, [])
            }
        }
    }
    
    public func numberOfProcessesUpdated() {
        guard self.contentLoaded else { return }
        if self.processes?.count == self.numberOfProcesses { return }
        
        self.processesView?.removeFromSuperview()
        self.processesView = nil
        self.processes = nil
        self.addSection(self.initProcesses())
        self.replay(self.processesCache, render: self.renderProcesses)
        self.resizeToFitContent()
    }
    
    public func loadCallback(_ value: GPU_Info) {
        let date = Date()
        self.apply(value, to: self.loadCache, render: self.renderLoad)
        DispatchQueue.main.async {
            if let utilization = value.utilization {
                let sample = DoubleValue(utilization, at: date)
                self.chartHistory.append(sample)
                self.chart?.historyUpdated()
            }
            if let memory = value.memory {
                self.memoryHistory.append(DoubleValue(memory, at: date))
                self.memoryChart?.historyUpdated()
            }
        }
    }
    
    private func renderLoad(_ value: GPU_Info) {
        if let utilization = value.utilization {
            self.usageCircle?.toolTip = "\(localizedString("GPU utilization")): \(Int(utilization.rounded(toPlaces: 2) * 100))%"
            self.usageCircle?.setValue(utilization)
            self.usageCircle?.display()
        }
        self.aneField?.stringValue = value.aneUtilization.map { "\(Int($0*100))%" } ?? "n/a"
        self.memoryField?.stringValue = value.memory.map { Units(bytes: Int64($0)).getReadableMemory(style: .memory) } ?? "n/a"
        self.fpsField?.stringValue = value.fps.map { "\(Int($0.rounded()))" } ?? "n/a"
        
        self.chart?.display()
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
        
        return view
    }
}
