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
import ModuleKit
import StatsKit

internal class Popup: NSView {
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90
    private let detailsHeight: CGFloat = 22*6
    private let processesHeight: CGFloat = 22*5
    
    private var totalField: NSTextField? = nil
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var activeField: NSTextField? = nil
    private var inactiveField: NSTextField? = nil
    private var wiredField: NSTextField? = nil
    private var compressedField: NSTextField? = nil
    
    private var chart: LineChartView? = nil
    private var circle: CircleGraphView? = nil
    private var level: PressureView? = nil
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    
    private var processes: [ProcessView] = []
    
    public init() {
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + chartHeight + detailsHeight + processesHeight + (Constants.Popup.separatorHeight*3)
        ))
        
        initDashboard()
        initChart()
        initDetails()
        initProcesses()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.chart?.display()
    }
    
    private func initDashboard() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        view.wantsLayer = true
        
        let container: NSView = NSView(frame: NSRect(x: 0, y: 10, width: view.frame.width, height: self.dashboardHeight-20))
        self.circle = CircleGraphView(frame: NSRect(x: (container.frame.width - container.frame.height)/2, y: 0, width: container.frame.height, height: container.frame.height), segments: [])
        self.circle!.toolTip = LocalizedString("Memory usage")
        container.addSubview(self.circle!)
        
        let centralWidth: CGFloat = self.dashboardHeight-20
        let sideWidth: CGFloat = (view.frame.width - centralWidth - (Constants.Popup.margins*2))/2
        self.level = PressureView(frame: NSRect(x: (sideWidth - 60)/2, y: 10, width: 60, height: 50))
        self.level!.toolTip = LocalizedString("Memory pressure")
        
        view.addSubview(self.level!)
        view.addSubview(container)
        
        self.addSubview(view)
    }
    
    private func initChart() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - Constants.Popup.separatorHeight
        let separator = SeparatorView(LocalizedString("Usage history"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: y -  self.chartHeight, width: self.frame.width, height: self.chartHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        view.layer?.cornerRadius = 3
        
        self.chart = LineChartView(frame: NSRect(x: 1, y: 0, width: view.frame.width, height: view.frame.height), num: 120)
        
        view.addSubview(self.chart!)
        
        self.addSubview(view)
    }
    
    private func initDetails() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - self.chartHeight - (Constants.Popup.separatorHeight*2)
        let separator = SeparatorView(LocalizedString("Details"), origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.detailsHeight, width: self.frame.width, height: self.detailsHeight))
        
        self.totalField = PopupRow(view, n: 5, title: "\(LocalizedString("Total")):", value: "")
        self.usedField = PopupRow(view, n: 4, title: "\(LocalizedString("Used")):", value: "")
        
        self.activeField = PopupWithColorRow(view, color: NSColor.systemBlue, n: 3, title: "\(LocalizedString("App")):", value: "")
        self.wiredField = PopupWithColorRow(view, color: NSColor.systemOrange, n: 2, title: "\(LocalizedString("Wired")):", value: "")
        self.compressedField = PopupWithColorRow(view, color: NSColor.systemPink, n: 1, title: "\(LocalizedString("Compressed")):", value: "")
        self.freeField = PopupWithColorRow(view, color: NSColor.lightGray.withAlphaComponent(0.5), n: 0, title: "\(LocalizedString("Free")):", value: "")
        
        self.addSubview(view)
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
                self.activeField?.stringValue = Units(bytes: Int64(value.active)).getReadableMemory()
                self.inactiveField?.stringValue = Units(bytes: Int64(value.inactive)).getReadableMemory()
                self.wiredField?.stringValue = Units(bytes: Int64(value.wired)).getReadableMemory()
                self.compressedField?.stringValue = Units(bytes: Int64(value.compressed)).getReadableMemory()
                
                self.totalField?.stringValue = Units(bytes: Int64(value.total)).getReadableMemory()
                self.usedField?.stringValue = Units(bytes: Int64(value.used)).getReadableMemory()
                self.freeField?.stringValue = Units(bytes: Int64(value.free)).getReadableMemory()
                
                self.circle?.setValue(value.usage)
                self.circle?.setSegments([
                    circle_segment(value: value.active/value.total, color: NSColor.systemBlue),
                    circle_segment(value: value.wired/value.total, color: NSColor.systemOrange),
                    circle_segment(value: value.compressed/value.total, color: NSColor.systemPink)
                ])
                self.level?.setLevel(value.pressureLevel)
                
                self.initialized = true
            }
            self.chart?.addValue(value.usage)
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
                        self.processes[index].value = Units(bytes: Int64(process.usage)).getReadableMemory()
                        self.processes[index].icon = process.icon
                    }
                }
                
                self.processesInitialized = true
            }
        })
    }
}

public class PressureView: NSView {
    private let segments: [circle_segment] = [
        circle_segment(value: 1/3, color: NSColor.systemGreen),
        circle_segment(value: 1/3, color: NSColor.systemYellow),
        circle_segment(value: 1/3, color: NSColor.systemRed),
    ]
    
    private var level: Int = 1
    
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
        case 1:
            needlePath.move(to: CGPoint(x: self.bounds.width * 0.15, y: self.bounds.width * 0.40))
            needlePath.line(to: CGPoint(x: self.bounds.width/2 , y: self.bounds.height/2 - needleEndSize))
            needlePath.line(to: CGPoint(x: self.bounds.width/2, y: self.bounds.height/2 + needleEndSize))
        case 2:
            needlePath.move(to: CGPoint(x: self.bounds.width/2, y: self.bounds.width * 0.85))
            needlePath.line(to: CGPoint(x: self.bounds.width/2 - needleEndSize, y: self.bounds.height/2))
            needlePath.line(to: CGPoint(x: self.bounds.width/2 + needleEndSize, y: self.bounds.height/2))
        case 3:
            needlePath.move(to: CGPoint(x: self.bounds.width * 0.85, y: self.bounds.width * 0.40))
            needlePath.line(to: CGPoint(x: self.bounds.width/2 , y: self.bounds.height/2 - needleEndSize))
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
        let str = NSAttributedString.init(string: "\(self.level)", attributes: stringAttributes)
        str.draw(with: rect)
    }
    
    public func setLevel(_ level: Int) {
        self.level = level
        if self.window?.isVisible ?? true {
            self.display()
        }
    }
}
