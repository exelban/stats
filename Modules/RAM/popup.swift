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
import Kit

internal class Popup: PopupWrapper {
    private let chartHistory = LineChartData(capacity: 180)
    
    private let chartHeight: CGFloat = 90 + Constants.Popup.separatorHeight
    private let detailsHeight: CGFloat = (22*6) + Constants.Popup.separatorHeight + 16
    private let processHeight: CGFloat = 22
    
    private var usageField: NSTextField? = nil
    private var pressurePercentageField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var appField: NSTextField? = nil
    private var inactiveField: NSTextField? = nil
    private var wiredField: NSTextField? = nil
    private var compressedField: NSTextField? = nil
    private var swapField: NSTextField? = nil
    private var pressureField: NSTextField? = nil
    
    private var appColorView: NSView? = nil
    private var wiredColorView: NSView? = nil
    private var compressedColorView: NSView? = nil
    private var freeColorView: NSView? = nil
    private var sliderView: NSView? = nil
    
    private var chart: LineChartView? = nil
    private var bar: BarChartView? = nil
    private var circle: PieChartView? = nil
    private let processesCache = PopupCache<[TopProcess]>()
    
    private let loadCache = PopupCache<RAM_Usage>()
    
    private var processes: ProcessesView? = nil
    private var processesView: NSView? = nil
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (self.processHeight*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    
    private var lineChartHistory: Int = 180
    private var lineChartScale: Scale = .none
    private var lineChartFixedScale: Double = 1
    private var chartPrefSection: PreferencesSection? = nil
    
    private var appColorState: SColor = .secondBlue
    private var appColor: NSColor { self.appColorState.additional as? NSColor ?? NSColor.systemRed }
    private var wiredColorState: SColor = .secondOrange
    private var wiredColor: NSColor { self.wiredColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var compressedColorState: SColor = .pink
    private var compressedColor: NSColor { self.compressedColorState.additional as? NSColor ?? NSColor.lightGray }
    private var freeColorState: SColor = .lightGray
    private var freeColor: NSColor { self.freeColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var chartColorState: SColor = .systemAccent
    private var chartColor: NSColor { self.chartColorState.additional as? NSColor ?? NSColor.systemBlue }
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        
        self.appColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_appColor", defaultValue: self.appColorState.key))
        self.wiredColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_wiredColor", defaultValue: self.wiredColorState.key))
        self.compressedColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_compressedColor", defaultValue: self.compressedColorState.key))
        self.freeColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_freeColor", defaultValue: self.freeColorState.key))
        self.chartColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_chartColor", defaultValue: self.chartColorState.key))
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
        self.addSection(self.initProcesses())
        
        self.resizeToFitContent()
    }
    
    public override func unloadContent() {
        self.usageField = nil
        self.pressurePercentageField = nil
        self.usedField = nil
        self.freeField = nil
        self.appField = nil
        self.inactiveField = nil
        self.wiredField = nil
        self.compressedField = nil
        self.swapField = nil
        self.pressureField = nil
        self.appColorView = nil
        self.wiredColorView = nil
        self.compressedColorView = nil
        self.freeColorView = nil
        self.chart = nil
        self.bar = nil
        self.circle = nil
        self.processes = nil
        self.processesView = nil
    }
    
    public override func appear() {
        self.replay(self.processesCache, render: self.renderProcesses)
        self.replay(self.loadCache, render: self.renderLoad)
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    public override func updateLayer() {
        self.chart?.display()
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
        chart.toolTip = localizedString("Memory usage")
        self.circle = chart
        
        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Constants.Popup.spacing*2
        
        let usage = PopupDashboardDetailsRow(
            icon: "memorychip",
            title: localizedString("Usage"),
            dafaultValue: "n/a"
        )
        self.usageField = usage.valueView
        let pressure = PopupDashboardDetailsRow(
            icon: "waveform.path.ecg",
            title: localizedString("Memory pressure"),
            dafaultValue: "n/a"
        )
        self.pressurePercentageField = pressure.valueView
        let swap = PopupDashboardDetailsRow(
            icon: "clock",
            title: "SWAP",
            dafaultValue: "n/a"
        )
        self.swapField = swap.valueView
        
        details.addArrangedSubview(usage)
        details.addArrangedSubview(pressure)
        details.addArrangedSubview(swap)
        
        view.addArrangedSubview(chart)
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func initChart() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        view.heightAnchor.constraint(equalToConstant: self.chartHeight).isActive = true
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: self.chartHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let chartFrame = NSRect(x: 1, y: 0, width: view.frame.width - 2, height: separator.frame.origin.y)
        let chart = LineChartView(frame: chartFrame, color: self.chartColor, scale: self.lineChartScale, fixedScale: self.lineChartFixedScale, history: self.chartHistory)
        self.chart = chart
        
        view.addSubview(separator)
        view.addSubview(chart)
        
        return view
    }
    
    private func initDetails() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        view.heightAnchor.constraint(equalToConstant: self.detailsHeight).isActive = true
        let separator = separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.usedField = popupRow(container, title: "\(localizedString("Used")):", value: "").1
        let bar = BarChartView(size: 10, horizontal: true)
        container.addArrangedSubview(bar)
        self.bar = bar
        (self.appColorView, _, self.appField) = popupWithColorRow(container, color: self.appColor, title: "\(localizedString("App")):", value: "")
        (self.wiredColorView, _, self.wiredField) = popupWithColorRow(container, color: self.wiredColor, title: "\(localizedString("Wired")):", value: "")
        (self.compressedColorView, _, self.compressedField) = popupWithColorRow(container, color: self.compressedColor, title: "\(localizedString("Compressed")):", value: "")
        (self.freeColorView, _, self.freeField) = popupWithColorRow(container, color: self.freeColor.withAlphaComponent(0.5), title: "\(localizedString("Free")):", value: "")
        self.pressureField = popupRow(container, title: "\(localizedString("Memory pressure")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        view.heightAnchor.constraint(equalToConstant: view.frame.height).isActive = true
        self.processesView = view
        guard self.numberOfProcesses != 0 else { return view }
        
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
    
    // MARK: - Updates
    
    public func loadCallback(_ value: RAM_Usage) {
        let date = Date()
        self.apply(value, to: self.loadCache, render: self.renderLoad)
        DispatchQueue.main.async {
            let sample = DoubleValue(value.usage, at: date)
            self.chartHistory.append(sample)
            self.chart?.historyUpdated()
        }
    }
    
    private func renderLoad(_ value: RAM_Usage) {
        self.appField?.stringValue = Units(bytes: Int64(value.app)).getReadableMemory(style: .memory)
        self.inactiveField?.stringValue = Units(bytes: Int64(value.inactive)).getReadableMemory(style: .memory)
        self.wiredField?.stringValue = Units(bytes: Int64(value.wired)).getReadableMemory(style: .memory)
        self.compressedField?.stringValue = Units(bytes: Int64(value.compressed)).getReadableMemory(style: .memory)
        self.swapField?.stringValue = Units(bytes: Int64(value.swap.used)).getReadableMemory(style: .memory)
        self.pressurePercentageField?.stringValue = value.pressure.percentage.map { "\($0)%" } ?? "n/a"
        self.pressureField?.stringValue = localizedString(value.pressure.value.rawValue.capitalized)
        
        let used = Units(bytes: Int64(value.used)).getReadableMemory(style: .memory)
        self.usageField?.stringValue = used
        self.usedField?.stringValue = used
        self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory(style: .memory)
        
        let values = [
            ColorValue(value.app/value.total, color: self.appColor),
            ColorValue(value.wired/value.total, color: self.wiredColor),
            ColorValue(value.compressed/value.total, color: self.compressedColor)
        ]
        
        self.circle?.toolTip = "\(localizedString("Memory usage")): \(Int(value.usage*100))%"
        self.circle?.setValue(value.usage)
        self.circle?.setSegments(values)
        self.circle?.setNonActiveSegmentColor(self.freeColor)
        self.circle?.display()
        
        self.bar?.setValues(values)
        
        self.chart?.display()
    }
    
    public func processCallback(_ list: [TopProcess]) {
        self.apply(list, to: self.processesCache, render: self.renderProcesses)
    }
    
    private func renderProcesses(_ list: [TopProcess]) {
        if list.count != self.processes?.count { self.processes?.clear() }
        
        for i in 0..<list.count {
            let process = list[i]
            self.processes?.set(i, process, [Units(bytes: Int64(process.usage)).getReadableMemory(style: .memory)])
        }
    }
    
    public func numberOfProcessesUpdated() {
        DispatchQueue.main.async(execute: {
            guard self.contentLoaded, (self.processes?.count ?? 0) != self.numberOfProcesses else { return }
            
            self.processesView?.removeFromSuperview()
            self.processes = nil
            self.addSection(self.initProcesses())
            self.replay(self.processesCache, render: self.renderProcesses)
            self.resizeToFitContent()
        })
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
            PreferencesRow(localizedString("App color"), component: self.colorSelectView(
                action: #selector(self.toggleAppColor),
                items: SColor.allColors,
                selected: self.appColorState.key
            )),
            PreferencesRow(localizedString("Wired color"), component: self.colorSelectView(
                action: #selector(self.toggleWiredColor),
                items: SColor.allColors,
                selected: self.wiredColorState.key
            )),
            PreferencesRow(localizedString("Compressed color"), component: self.colorSelectView(
                action: #selector(self.toggleCompressedColor),
                items: SColor.allColors,
                selected: self.compressedColorState.key
            )),
            PreferencesRow(localizedString("Free color"), component: self.colorSelectView(
                action: #selector(self.toggleFreeColor),
                items: SColor.allColors,
                selected: self.freeColorState.key
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
        self.chartPrefSection?.setRowVisibility(3, newState: self.lineChartScale == .fixed)
        view.addArrangedSubview(self.chartPrefSection!)
        
        return view
    }
    
    @objc private func toggleAppColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.appColorState = SColor.fromString(key, defaultValue: self.appColorState)
        Store.shared.set(key: "\(self.title)_appColor", value: self.appColorState.key)
        if let color = self.appColorState.additional as? NSColor {
            self.appColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleWiredColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.wiredColorState = SColor.fromString(key, defaultValue: self.wiredColorState)
        Store.shared.set(key: "\(self.title)_wiredColor", value: self.wiredColorState.key)
        if let color = self.wiredColorState.additional as? NSColor {
            self.wiredColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleCompressedColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.compressedColorState = SColor.fromString(key, defaultValue: self.compressedColorState)
        Store.shared.set(key: "\(self.title)_compressedColor", value: self.compressedColorState.key)
        if let color = self.compressedColorState.additional as? NSColor {
            self.compressedColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleFreeColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.freeColorState = SColor.fromString(key, defaultValue: self.freeColorState)
        Store.shared.set(key: "\(self.title)_freeColor", value: self.freeColorState.key)
        if let color = self.freeColorState.additional as? NSColor {
            self.freeColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleChartColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.chartColorState = SColor.fromString(key, defaultValue: self.chartColorState)
        Store.shared.set(key: "\(self.title)_chartColor", value: self.chartColorState.key)
        if let color = self.chartColorState.additional as? NSColor {
            self.chart?.setColor(color)
        }
    }
    @objc private func toggleLineChartHistory(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.lineChartHistory = value
        self.chartHistory.resize(value)
        Store.shared.set(key: "\(self.title)_lineChartHistory", value: value)
        self.chart?.reinit(self.lineChartHistory)
    }
    @objc private func toggleLineChartScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.chartPrefSection?.setRowVisibility(3, newState: value == .fixed)
        self.lineChartScale = value
        self.chart?.setScale(self.lineChartScale, fixedScale: self.lineChartFixedScale)
        Store.shared.set(key: "\(self.title)_lineChartScale", value: key)
        self.display()
    }
    @objc private func toggleLineChartFixedScale(_ sender: NSSlider) {
        let value = Int(sender.doubleValue)
        
        if let field = self.sliderView?.subviews.first(where: { $0 is NSTextField }), let view = field as? NSTextField {
            view.stringValue = "\(value) %"
        }
        
        self.lineChartFixedScale = sender.doubleValue / 100
        self.chart?.setScale(self.lineChartScale, fixedScale: self.lineChartFixedScale)
        Store.shared.set(key: "\(self.title)_lineChartFixedScale", value: value)
    }
}
