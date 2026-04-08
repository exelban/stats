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
    private var grid: NSGridView? = nil
    
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90 + Constants.Popup.separatorHeight
    private let detailsHeight: CGFloat = (22*6) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = 22
    
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var appField: NSTextField? = nil
    private var inactiveField: NSTextField? = nil
    private var wiredField: NSTextField? = nil
    private var compressedField: NSTextField? = nil
    private var swapField: NSTextField? = nil
    
    private var appColorView: NSView? = nil
    private var wiredColorView: NSView? = nil
    private var compressedColorView: NSView? = nil
    private var freeColorView: NSView? = nil
    private var sliderView: NSView? = nil
    
    private var chart: LineChartView? = nil
    private var circle: PieChartView? = nil
    private var level: PieChartView? = nil
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    
    private var processes: ProcessesView? = nil
    
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
        super.init(module, frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + chartHeight + detailsHeight
        ))
        self.setFrameSize(NSSize(width: self.frame.width, height: self.frame.height+self.processesHeight))
        
        self.appColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_appColor", defaultValue: self.appColorState.key))
        self.wiredColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_wiredColor", defaultValue: self.wiredColorState.key))
        self.compressedColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_compressedColor", defaultValue: self.compressedColorState.key))
        self.freeColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_freeColor", defaultValue: self.freeColorState.key))
        self.chartColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_chartColor", defaultValue: self.chartColorState.key))
        self.lineChartHistory = Store.shared.int(key: "\(self.title)_lineChartHistory", defaultValue: self.lineChartHistory)
        self.lineChartScale = Scale.fromString(Store.shared.string(key: "\(self.title)_lineChartScale", defaultValue: self.lineChartScale.key))
        self.lineChartFixedScale = Double(Store.shared.int(key: "\(self.title)_lineChartFixedScale", defaultValue: 100)) / 100
        
        let gridView: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        gridView.rowSpacing = 0
        gridView.yPlacement = .fill
        
        gridView.addRow(with: [self.initDashboard()])
        gridView.addRow(with: [self.initChart()])
        gridView.addRow(with: [self.initDetails()])
        gridView.addRow(with: [self.initProcesses()])
        
        gridView.row(at: 0).height = self.dashboardHeight
        gridView.row(at: 1).height = self.chartHeight
        gridView.row(at: 2).height = self.detailsHeight
        
        self.addSubview(gridView)
        self.grid = gridView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.chart?.display()
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes?.count == self.numberOfProcesses { return }
        
        DispatchQueue.main.async(execute: {
            let h: CGFloat = self.dashboardHeight + self.chartHeight + self.detailsHeight + self.processesHeight
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.row(at: 3).cell(at: 0).contentView?.removeFromSuperview()
            self.processes = nil
            self.grid?.removeRow(at: 3)
            self.grid?.addRow(with: [self.initProcesses()])
            self.processesInitialized = false
            
            self.sizeCallback?(self.frame.size)
        })
    }
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        
        let container: NSView = NSView(frame: NSRect(x: 0, y: 10, width: view.frame.width, height: self.dashboardHeight-20))
        self.circle = PieChartView(frame: NSRect(
            x: (container.frame.width - container.frame.height)/2,
            y: 0,
            width: container.frame.height,
            height: container.frame.height
        ), segments: [], drawValue: true)
        self.circle!.toolTip = localizedString("Memory usage")
        container.addSubview(self.circle!)
        
        let centralWidth: CGFloat = self.dashboardHeight-20
        let sideWidth: CGFloat = (view.frame.width - centralWidth - (Constants.Popup.margins*2))/2
        self.level = PieChartView(frame: NSRect(x: (sideWidth - 60)/2, y: 10, width: 60, height: 50), segments: [
            ColorValue(1/3, color: NSColor.systemGreen),
            ColorValue(1/3, color: NSColor.systemYellow),
            ColorValue(1/3, color: NSColor.systemRed)
        ], drawValue: true, drawNeedle: true, openCircle: true)
        self.level!.toolTip = localizedString("Memory pressure")
        
        view.addSubview(self.level!)
        view.addSubview(container)
        
        return view
    }
    
    private func initChart() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: self.chartHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = 3
        
        let chartFrame = NSRect(x: 1, y: 0, width: view.frame.width - 2, height: container.frame.height)
        self.chart = LineChartView(frame: chartFrame, num: self.lineChartHistory, scale: self.lineChartScale, fixedScale: self.lineChartFixedScale)
        self.chart?.color = self.chartColor
        container.addSubview(self.chart!)
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        let separator = separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.usedField = popupRow(container, title: "\(localizedString("Used")):", value: "").1
        (self.appColorView, _, self.appField) = popupWithColorRow(container, color: self.appColor, title: "\(localizedString("App")):", value: "")
        (self.wiredColorView, _, self.wiredField) = popupWithColorRow(container, color: self.wiredColor, title: "\(localizedString("Wired")):", value: "")
        (self.compressedColorView, _, self.compressedField) = popupWithColorRow(container, color: self.compressedColor, title: "\(localizedString("Compressed")):", value: "")
        (self.freeColorView, _, self.freeField) = popupWithColorRow(container, color: self.freeColor.withAlphaComponent(0.5), title: "\(localizedString("Free")):", value: "")
        self.swapField = popupRow(container, title: "\(localizedString("Swap")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView  {
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
                self.appField?.stringValue = Units(bytes: Int64(value.app)).getReadableMemory(style: .memory)
                self.inactiveField?.stringValue = Units(bytes: Int64(value.inactive)).getReadableMemory(style: .memory)
                self.wiredField?.stringValue = Units(bytes: Int64(value.wired)).getReadableMemory(style: .memory)
                self.compressedField?.stringValue = Units(bytes: Int64(value.compressed)).getReadableMemory(style: .memory)
                self.swapField?.stringValue = Units(bytes: Int64(value.swap.used)).getReadableMemory(style: .memory)
                
                self.usedField?.stringValue = Units(bytes: Int64(value.used)).getReadableMemory(style: .memory)
                self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory(style: .memory)
                
                self.circle?.toolTip = "\(localizedString("Memory usage")): \(Int(value.usage*100))%"
                self.circle?.setValue(value.usage)
                self.circle?.setSegments([
                    ColorValue(value.app/value.total, color: self.appColor),
                    ColorValue(value.wired/value.total, color: self.wiredColor),
                    ColorValue(value.compressed/value.total, color: self.compressedColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.freeColor)
                
                self.level?.setActiveSegment(value.pressure.value.number())
                self.level?.toolTip = "\(localizedString("Memory pressure")): \(value.pressure.value.rawValue)"
                
                self.initialized = true
            }
            self.chart?.addValue(value.usage)
        })
    }
    
    public func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.processesInitialized {
                return
            }
            let list = list.map { $0 }
            if list.count != self.processes?.count { self.processes?.clear() }
            
            for i in 0..<list.count {
                let process = list[i]
                self.processes?.set(i, process, [Units(bytes: Int64(process.usage)).getReadableMemory(style: .memory)])
            }
            
            self.processesInitialized = true
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
            PreferencesRow(localizedString("App color"), component: selectView(
                action: #selector(toggleAppColor),
                items: SColor.allColors,
                selected: self.appColorState.key
            )),
            PreferencesRow(localizedString("Wired color"), component: selectView(
                action: #selector(toggleWiredColor),
                items: SColor.allColors,
                selected: self.wiredColorState.key
            )),
            PreferencesRow(localizedString("Compressed color"), component: selectView(
                action: #selector(toggleCompressedColor),
                items: SColor.allColors,
                selected: self.compressedColorState.key
            )),
            PreferencesRow(localizedString("Free color"), component: selectView(
                action: #selector(toggleFreeColor),
                items: SColor.allColors,
                selected: self.freeColorState.key
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
        self.chartPrefSection?.setRowVisibility(3, newState: self.lineChartScale == .fixed)
        view.addArrangedSubview(self.chartPrefSection!)
        
        return view
    }
    
    @objc private func toggleAppColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.appColorState = newValue
        Store.shared.set(key: "\(self.title)_appColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.appColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleWiredColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.wiredColorState = newValue
        Store.shared.set(key: "\(self.title)_wiredColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.wiredColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleCompressedColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.compressedColorState = newValue
        Store.shared.set(key: "\(self.title)_compressedColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.compressedColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleFreeColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.freeColorState = newValue
        Store.shared.set(key: "\(self.title)_freeColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.freeColorView?.layer?.backgroundColor = color.cgColor
        }
    }
    @objc private func toggleChartColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = SColor.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.chartColorState = newValue
        Store.shared.set(key: "\(self.title)_chartColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.chart?.color = color
        }
    }
    @objc private func toggleLineChartHistory(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.lineChartHistory = value
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
