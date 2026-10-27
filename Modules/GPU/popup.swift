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
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90 + Constants.Popup.separatorHeight
    private let detailsHeight: CGFloat = (22*7) + Constants.Popup.separatorHeight
    
    private let loadCache = PopupCache<GPU_Info>()
    private let processesCache = PopupCache<[TopProcess]>()
    private var processes: ProcessesView? = nil
    private var processesView: NSView? = nil
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (22*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    
    private var usageCircle: PieChartView? = nil
    private var renderCircle: PieChartView? = nil
    private var tilerCircle: PieChartView? = nil
    
    private var chart: LineChartView? = nil
    private var lineChartHistory: Int = 180
    private var lineChartScale: Scale = .none
    private var lineChartFixedScale: Double = 1
    
    private var modelField: NSTextField? = nil
    private var coresField: NSTextField? = nil
    private var utilizationField: NSTextField? = nil
    private var renderField: NSTextField? = nil
    private var tilerField: NSTextField? = nil
    private var aneField: NSTextField? = nil
    private var fpsField: NSTextField? = nil
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        
        self.addArrangedSubview(self.initDashboard())
        self.addArrangedSubview(self.initChart())
        self.addArrangedSubview(self.initDetails())
        self.addArrangedSubview(self.initProcesses())
        
        self.recalculateHeight()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.chart?.display()
    }
    
    public override func appear() {
        self.replay(self.loadCache, render: self.renderLoad)
        self.replay(self.processesCache, render: self.renderProcesses)
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    private func recalculateHeight() {
        let h = self.dashboardHeight + self.chartHeight + self.detailsHeight + self.processesHeight
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.dashboardHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let usageSize = self.dashboardHeight-20
        let usageX = (view.frame.width - usageSize)/2
        
        let usage = NSView(frame: NSRect(x: usageX, y: (view.frame.height - usageSize)/2, width: usageSize, height: usageSize))
        let render = NSView(frame: NSRect(x: (usageX - 50)/2, y: (view.frame.height - 50)/2 - 3, width: 50, height: 50))
        let tiler = NSView(frame: NSRect(x: (usageX+usageSize) + (usageX - 50)/2, y: 0, width: 50, height: self.dashboardHeight))
        
        self.usageCircle = PieChartView(frame: NSRect(x: 0, y: 0, width: usage.frame.width, height: usage.frame.height), drawValue: true)
        self.usageCircle!.toolTip = localizedString("Utilization")
        usage.addSubview(self.usageCircle!)
        
        self.renderCircle = PieChartView(frame: NSRect(x: 0, y: 0, width: render.frame.width, height: render.frame.height), drawValue: true)
        self.renderCircle!.toolTip = localizedString("Renderer utilization")
        render.addSubview(self.renderCircle!)
        
        self.tilerCircle = PieChartView(frame: NSRect(x: 0, y: 0, width: tiler.frame.width, height: tiler.frame.height), drawValue: true)
        self.tilerCircle!.toolTip = localizedString("Tiler utilization")
        tiler.addSubview(self.tilerCircle!)
        
        view.addSubview(render)
        view.addSubview(usage)
        view.addSubview(tiler)
        
        return view
    }
    
    private func initChart() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        view.heightAnchor.constraint(equalToConstant: 90 + Constants.Popup.separatorHeight).isActive = true
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: self.chartHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = Constants.Popup.radius
        
        let chartFrame = NSRect(x: 1, y: 0, width: view.frame.width - 2, height: container.frame.height)
        self.chart = LineChartView(frame: chartFrame, num: self.lineChartHistory, scale: self.lineChartScale, fixedScale: self.lineChartFixedScale)
        container.addSubview(self.chart!)
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        view.heightAnchor.constraint(equalToConstant: self.detailsHeight).isActive = true
        let separator = separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.modelField = popupRow(container, title: "\(localizedString("Model")):", value: "").1
        self.coresField = popupRow(container, title: "\(localizedString("Cores")):", value: localizedString("Unknown")).1
        self.utilizationField = popupRow(container, title: "\(localizedString("Utilization")):", value: "").1
        self.renderField = popupRow(container, title: "\(localizedString("Renderer utilization")):", value: "").1
        self.tilerField = popupRow(container, title: "\(localizedString("Tiler utilization")):", value: "").1
        self.aneField = popupRow(container, title: "\(localizedString("ANE utilization")):", value: "").1
        self.fpsField = popupRow(container, title: "\("FPS"):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
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
    
    // MARK: - Callback
    
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
        if self.processes?.count == self.numberOfProcesses { return }
        
        self.processesView?.removeFromSuperview()
        self.processesView = nil
        self.processes = nil
        self.addArrangedSubview(self.initProcesses())
        self.replay(self.processesCache, render: self.renderProcesses)
        self.recalculateHeight()
    }
    
    public func loadCallback(_ value: GPU_Info) {
        self.apply(value, to: self.loadCache, render: self.renderLoad)
        if let utilization = value.utilization {
            self.chart?.addValue(utilization)
        }
    }
    
    private func renderLoad(_ value: GPU_Info) {
        self.modelField?.stringValue = value.model
        
        if let cores = value.cores {
            self.coresField?.stringValue = "\(cores)"
        }
        
        if let utilization = value.utilization {
            self.usageCircle?.toolTip = "\(localizedString("GPU utilization")): \(Int(utilization.rounded(toPlaces: 2) * 100))%"
            self.usageCircle?.setValue(utilization)
            self.usageCircle?.display()
            self.utilizationField?.stringValue = "\(Int(utilization*100))%"
        }
        if let utilization = value.renderUtilization {
            self.renderCircle?.toolTip = "\(localizedString("Renderer utilization")): \(Int(utilization.rounded(toPlaces: 2) * 100))%"
            self.renderCircle?.setValue(utilization)
            self.renderCircle?.display()
            self.renderField?.stringValue = "\(Int(utilization*100))%"
        }
        if let utilization = value.tilerUtilization {
            self.tilerCircle?.toolTip = "\(localizedString("Tiler utilization")): \(Int(utilization.rounded(toPlaces: 2) * 100))%"
            self.tilerCircle?.setValue(utilization)
            self.tilerCircle?.display()
            self.tilerField?.stringValue = "\(Int(utilization*100))%"
        }
        if let utilization = value.aneUtilization {
            self.aneField?.stringValue = "\(Int(utilization*100))%"
        }
        if let fps = value.fps {
            self.fpsField?.stringValue = "\(Int(fps.rounded()))"
        }
        
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
