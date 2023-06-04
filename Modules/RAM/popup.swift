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
    private var title: String
    
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
    
    private var chart: LineChartView? = nil
    private var circle: PieChartView? = nil
    private var level: PressureView? = nil
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    
    private var processes: [ProcessView] = []
    
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
    
    private var appColorState: Color = .secondBlue
    private var appColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.appColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var wiredColorState: Color = .secondOrange
    private var wiredColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.wiredColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var compressedColorState: Color = .pink
    private var compressedColor: NSColor {
        var value = NSColor.lightGray
        if let color = self.compressedColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var freeColorState: Color = .lightGray
    private var freeColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.freeColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var chartColorState: Color = .systemAccent
    private var chartColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.chartColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    public init(_ title: String) {
        self.title = title
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + chartHeight + detailsHeight
        ))
        self.setFrameSize(NSSize(width: self.frame.width, height: self.frame.height+self.processesHeight))
        
        self.appColorState = Color.fromString(Store.shared.string(key: "\(self.title)_appColor", defaultValue: self.appColorState.key))
        self.wiredColorState = Color.fromString(Store.shared.string(key: "\(self.title)_wiredColor", defaultValue: self.wiredColorState.key))
        self.compressedColorState = Color.fromString(Store.shared.string(key: "\(self.title)_compressedColor", defaultValue: self.compressedColorState.key))
        self.freeColorState = Color.fromString(Store.shared.string(key: "\(self.title)_freeColor", defaultValue: self.freeColorState.key))
        self.chartColorState = Color.fromString(Store.shared.string(key: "\(self.title)_chartColor", defaultValue: self.chartColorState.key))
        
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
    
    public func numberOfProcessesUpdated() {
        if self.processes.count == self.numberOfProcesses {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.processes = []
            
            let h: CGFloat = self.dashboardHeight + self.chartHeight + self.detailsHeight + self.processesHeight
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.row(at: 3).cell(at: 0).contentView?.removeFromSuperview()
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
        self.level = PressureView(frame: NSRect(x: (sideWidth - 60)/2, y: 10, width: 60, height: 50))
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
        
        self.chart = LineChartView(frame: NSRect(x: 1, y: 0, width: view.frame.width, height: container.frame.height), num: 120)
        self.chart?.color = self.chartColor
        container.addSubview(self.chart!)
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        let separator = separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        self.usedField = popupRow(container, n: 5, title: "\(localizedString("Used")):", value: "").1
        (self.appColorView, _, self.appField) = popupWithColorRow(container, color: self.appColor, n: 4, title: "\(localizedString("App")):", value: "")
        (self.wiredColorView, _, self.wiredField) = popupWithColorRow(container, color: self.wiredColor, n: 3, title: "\(localizedString("Wired")):", value: "")
        (self.compressedColorView, _, self.compressedField) = popupWithColorRow(container, color: self.compressedColor, n: 2, title: "\(localizedString("Compressed")):", value: "")
        (self.freeColorView, _, self.freeField) = popupWithColorRow(container, color: self.freeColor.withAlphaComponent(0.5), n: 1, title: "\(localizedString("Free")):", value: "")
        self.swapField = popupRow(container, n: 0, title: "\(localizedString("Swap")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView  {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        for _ in 0..<self.numberOfProcesses {
            let processView = ProcessView()
            self.processes.append(processView)
            container.addArrangedSubview(processView)
        }
        
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
                self.appField?.stringValue = Units(bytes: Int64(value.app)).getReadableMemory()
                self.inactiveField?.stringValue = Units(bytes: Int64(value.inactive)).getReadableMemory()
                self.wiredField?.stringValue = Units(bytes: Int64(value.wired)).getReadableMemory()
                self.compressedField?.stringValue = Units(bytes: Int64(value.compressed)).getReadableMemory()
                self.swapField?.stringValue = Units(bytes: Int64(value.swap.used)).getReadableMemory()
                
                self.usedField?.stringValue = Units(bytes: Int64(value.used)).getReadableMemory()
                self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory()
                
                self.circle?.setValue(value.usage)
                self.circle?.setSegments([
                    circle_segment(value: value.app/value.total, color: self.appColor),
                    circle_segment(value: value.wired/value.total, color: self.wiredColor),
                    circle_segment(value: value.compressed/value.total, color: self.compressedColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.freeColor)
                self.level?.setLevel(value.pressureLevel)
                
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
            
            if list.count != self.processes.count {
                self.processes.forEach { processView in
                    processView.clear()
                }
            }
            
            for i in 0..<list.count {
                self.processes[i].set(list[i], Units(bytes: Int64(list[i].usage)).getReadableMemory())
            }
            
            self.processesInitialized = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("App color"),
            action: #selector(toggleAppColor),
            items: Color.allColors,
            selected: self.appColorState.key
        ))
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Wired color"),
            action: #selector(toggleWiredColor),
            items: Color.allColors,
            selected: self.wiredColorState.key
        ))
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Compressed color"),
            action: #selector(toggleCompressedColor),
            items: Color.allColors,
            selected: self.compressedColorState.key
        ))
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Free color"),
            action: #selector(toggleFreeColor),
            items: Color.allColors,
            selected: self.freeColorState.key
        ))
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Chart color"),
            action: #selector(toggleChartColor),
            items: Color.allColors,
            selected: self.chartColorState.key
        ))
        
        return view
    }
    
    @objc private func toggleAppColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
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
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
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
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
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
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
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
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.chartColorState = newValue
        Store.shared.set(key: "\(self.title)_chartColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.chart?.color = color
        }
    }
}

public class PressureView: NSView {
    private let segments: [circle_segment] = [
        circle_segment(value: 1/3, color: NSColor.systemGreen),
        circle_segment(value: 1/3, color: NSColor.systemYellow),
        circle_segment(value: 1/3, color: NSColor.systemRed)
    ]
    
    private var level: DispatchSource.MemoryPressureEvent = .normal
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = 7.0
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = (min(rect.width, rect.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        let startAngle: CGFloat = -(1/4)*CGFloat.pi
        let endCircle: CGFloat = (7/4)*CGFloat.pi - (1/4)*CGFloat.pi
        var previousAngle = startAngle
        
        context.saveGState()
        context.translateBy(x: rect.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        
        for segment in self.segments {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * endCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
        
        context.restoreGState()
        
        let needleEndSize: CGFloat = 2
        let needlePath =  NSBezierPath()
        
        switch self.level {
        case .normal:
            needlePath.move(to: CGPoint(x: self.bounds.width * 0.15, y: self.bounds.width * 0.40))
            needlePath.line(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/2 - needleEndSize))
            needlePath.line(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/2 + needleEndSize))
        case .warning:
            needlePath.move(to: CGPoint(x: self.bounds.width/2, y: self.bounds.width * 0.85))
            needlePath.line(to: CGPoint(x: self.bounds.width/2 - needleEndSize, y: self.bounds.height/2))
            needlePath.line(to: CGPoint(x: self.bounds.width/2 + needleEndSize, y: self.bounds.height/2))
        case .critical:
            needlePath.move(to: CGPoint(x: self.bounds.width * 0.85, y: self.bounds.width * 0.40))
            needlePath.line(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/2 - needleEndSize))
            needlePath.line(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/2 + needleEndSize))
        default: break
        }
        
        needlePath.close()
        
        let needleCirclePath = NSBezierPath(
            roundedRect: NSRect(x: self.bounds.width/2-needleEndSize, y: self.bounds.height/2-needleEndSize, width: needleEndSize*2, height: needleEndSize*2),
            xRadius: needleEndSize*2,
            yRadius: needleEndSize*2
        )
        needleCirclePath.close()
        
        NSColor.systemBlue.setFill()
        needlePath.fill()
        needleCirclePath.fill()
        
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
            NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
        ]
        
        let rect = CGRect(x: (self.frame.width-6)/2, y: (self.frame.height-26)/2, width: 6, height: 12)
        let str = NSAttributedString.init(string: "\(self.level.rawValue)", attributes: stringAttributes)
        str.draw(with: rect)
    }
    
    public func setLevel(_ level: DispatchSource.MemoryPressureEvent) {
        self.level = level
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
}
