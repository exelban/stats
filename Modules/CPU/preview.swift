//
//  preview.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09/03/2026
//  Using Swift 6.0
//  Running on macOS 26.3
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Preview: NSStackView, Preview_v {
    private var initialized: Bool = false
    private var initializedAverage: Bool = false
    private var initializedFrequency: Bool = false
    
    private var systemColorState: SColor = .secondRed
    private var systemColor: NSColor { self.systemColorState.additional as? NSColor ?? NSColor.systemRed }
    private var userColorState: SColor = .secondBlue
    private var userColor: NSColor { self.userColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var idleColorState: SColor = .lightGray
    private var idleColor: NSColor { self.idleColorState.additional as? NSColor ?? NSColor.lightGray }
    private var chartColorState: SColor = .systemAccent
    private var chartColor: NSColor { self.chartColorState.additional as? NSColor ?? NSColor.systemBlue }
    
    private var eCoresColor: NSColor {
        let color = SColor.teal
        let key = Store.shared.string(key: "CPU_eCoresColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var pCoresColor: NSColor {
        let color = SColor.indigo
        let key = Store.shared.string(key: "CPU_pCoresColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var sCoresColor: NSColor {
        let color = SColor.orange
        let key = Store.shared.string(key: "CPU_sCoresColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    
    private var circle: PieChartView? = nil
    private var bar: BarChartView? = nil
    private var loadLineChart: LineChartView? = nil
    
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var average1Field: NSTextField? = nil
    private var average5Field: NSTextField? = nil
    private var average15Field: NSTextField? = nil
    private var coresFreqField: NSTextField? = nil
    private var eCoresFreqField: NSTextField? = nil
    private var sCoresFreqField: NSTextField? = nil
    private var pCoresFreqField: NSTextField? = nil
    
    private var cores: [CoreView] = []
    
    private var loadLineChartHistory: Int = 180
    private var loadLineChartScale: Scale = .none
    private var loadLineChartFixedScale: Double = 1
    
    public init(_ module: ModuleType) {
        super.init(frame: NSRect.zero)
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.translatesAutoresizingMaskIntoConstraints = false
        self.spacing = Constants.Settings.margin
        
        self.addArrangedSubview(PreferencesSection([self.totalView()]))
        self.addArrangedSubview(PreferencesSection(label: localizedString("Usage history"), [self.historyView()]))
        self.addArrangedSubview(PreferencesSection(label: localizedString("Load per core"), [self.coresView()]))
        
        let splitView = NSStackView()
        splitView.orientation = .horizontal
        splitView.distribution = .fillEqually
        splitView.addArrangedSubview(PreferencesSection(label: localizedString("Average load"), [self.averageView()]))
        splitView.addArrangedSubview(PreferencesSection(label: localizedString("Frequency"), [self.frequencyView()]))
        
        self.addArrangedSubview(splitView)
        self.addArrangedSubview(NSView())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func totalView() -> NSView {
        let view = NSStackView()
        view.distribution = .fill
        view.orientation = .horizontal
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 90).isActive = true
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = Constants.Settings.margin
        
        let circle = PieChartView(drawValue: true)
        circle.widthAnchor.constraint(equalToConstant: 90).isActive = true
        circle.toolTip = localizedString("CPU usage")
        self.circle = circle
        
        let details: NSView = {
            let view = NSStackView()
            view.orientation = .vertical
            view.distribution = .fillEqually
            
            var titleValue = localizedString("Unknown")
            if let cpu = SystemKit.shared.device.info.cpu {
                if let name = cpu.name {
                    titleValue = name
                }
                if let eCores = cpu.eCores, let pCores = cpu.pCores {
                    titleValue.append(" (\(eCores)E/\(pCores)P)")
                } else if let eCores = cpu.eCores {
                    titleValue.append(" (\(eCores)E)")
                } else if let pCores = cpu.pCores {
                    titleValue.append(" (\(pCores)P)")
                }
            }
            
            let title = NSStackView()
            title.addArrangedSubview(LabelField(titleValue))
            title.addArrangedSubview(NSView())
            
            let bar = BarChartView(size: 11, horizontal: true)
            self.bar = bar
            
            let levels = NSStackView()
            levels.orientation = .horizontal
            levels.distribution = .fill
            
            self.systemField = previewRow(levels, space: false, color: self.systemColor, title: "\(localizedString("System")):", value: "")
            self.userField = previewRow(levels, space: false, color: self.userColor, title: "\(localizedString("User")):", value: "")
            self.idleField = previewRow(levels, space: false, color: self.idleColor, title: "\(localizedString("Idle")):", value: "")
            levels.addArrangedSubview(NSView())
            
            view.addArrangedSubview(title)
            view.addArrangedSubview(bar)
            view.addArrangedSubview(levels)
            
            return view
        }()
        
        view.addArrangedSubview(circle)
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func historyView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin*2
        view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        let chart = LineChartView(num: self.loadLineChartHistory, scale: self.loadLineChartScale, fixedScale: self.loadLineChartFixedScale)
        chart.color = self.chartColor
        self.loadLineChart = chart
        view.addArrangedSubview(chart)
        
        return view
    }
    
    private func coresView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin
        
        let leftColumn: NSStackView = NSStackView()
        leftColumn.orientation = .vertical
        leftColumn.distribution = .fillEqually
        leftColumn.spacing = Constants.Settings.margin
        
        let rightColumn: NSStackView = NSStackView()
        rightColumn.orientation = .vertical
        rightColumn.distribution = .fillEqually
        rightColumn.spacing = Constants.Settings.margin
        
        if let cpu = SystemKit.shared.device.info.cpu, let cores = cpu.cores {
            var e = 0
            var p = 0
            
            for (i, core) in cores.enumerated() {
                var num = i
                
                if core.type == .efficiency {
                    e += 1
                    num = e
                } else if core.type == .performance {
                    p += 1
                    num = p
                }
                
                let c = CoreView(core, num: num)
                if i % 2 == 0 {
                    leftColumn.addArrangedSubview(c)
                } else {
                    rightColumn.addArrangedSubview(c)
                }
                self.cores.append(c)
            }
        }
        
        view.addArrangedSubview(leftColumn)
        view.addArrangedSubview(rightColumn)
        
        return view
    }
    
    private func averageView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.average1Field = previewRow(view, title: "\(localizedString("1 minute")):", value: "")
        self.average5Field = previewRow(view, title: "\(localizedString("5 minutes")):", value: "")
        self.average15Field = previewRow(view, title: "\(localizedString("15 minutes")):", value: "")
        
        return view
    }
    
    private func frequencyView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.coresFreqField = previewRow(view, title: "\(localizedString("All cores")):", value: "")
        
        if isARM {
            if SystemKit.shared.device.info.cpu?.eCores != nil {
                self.eCoresFreqField = previewRow(view, color: self.eCoresColor, title: "\(localizedString("Efficiency cores")):", value: "")
            }
            if SystemKit.shared.device.info.cpu?.pCores != nil {
                self.pCoresFreqField = previewRow(view, color: self.pCoresColor, title: "\(localizedString("Performance cores")):", value: "")
            }
            if SystemKit.shared.device.info.cpu?.sCores != nil {
                self.sCoresFreqField = previewRow(view, color: self.sCoresColor, title: "\(localizedString("Super cores")):", value: "")
            }
        }
        
        return view
    }
    
    internal func loadCallback(_ value: CPU_Load) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.circle?.toolTip = "\(localizedString("CPU usage")): \(Int(value.totalUsage.rounded(toPlaces: 2) * 100))%"
                self.circle?.setValue(value.totalUsage)
                self.circle?.setSegments([
                    ColorValue(value.systemLoad, color: self.systemColor),
                    ColorValue(value.userLoad, color: self.userColor)
                ])
                self.circle?.setNonActiveSegmentColor(self.idleColor)
                
                self.systemField?.stringValue = "\(Int(value.systemLoad.rounded(toPlaces: 2) * 100))%"
                self.userField?.stringValue = "\(Int(value.userLoad.rounded(toPlaces: 2) * 100))%"
                self.idleField?.stringValue = "\(Int(value.idleLoad.rounded(toPlaces: 2) * 100))%"
                
                self.bar?.setValues([
                    ColorValue(value.systemLoad, color: self.systemColor),
                    ColorValue(value.userLoad, color: self.userColor)
                ])
                
                for (i, v) in value.usagePerCore.enumerated() {
                    if let core = self.cores.first(where: {$0.identifier?.rawValue == "\(i)" }) {
                        core.setValue(v)
                    }
                }
                
                self.initialized = true
            }
            self.loadLineChart?.addValue(value.totalUsage)
        })
    }
    
    public func averageCallback(_ value: CPU_AverageLoad?) {
        guard let value else { return }
        
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initializedFrequency {
                self.average1Field?.stringValue = "\(value.load1)"
                self.average5Field?.stringValue = "\(value.load5)"
                self.average15Field?.stringValue = "\(value.load15)"
                
                self.initializedAverage = true
            }
        })
    }
    
    public func frequencyCallback(_ value: CPU_Frequency?) {
        guard let value else { return }
        
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initializedFrequency {
                if let v = value.value {
                    self.coresFreqField?.stringValue = "\(Int(v)) MHz"
                }
                if let v = value.eCore {
                    self.eCoresFreqField?.stringValue = "\(Int(v)) MHz"
                }
                if let v = value.pCore {
                    self.pCoresFreqField?.stringValue = "\(Int(v)) MHz"
                }
                if let v = value.sCore {
                    self.sCoresFreqField?.stringValue = "\(Int(v)) MHz"
                }
                
                self.initializedFrequency = true
            }
        })
    }
}

class CoreView: NSStackView {
    private let core: core_s
    
    private let valueField = ValueField()
    private var bar: BarChartView = BarChartView(size: 8, horizontal: true)
    
    private var eCoresColor: NSColor {
        let color = SColor.teal
        let key = Store.shared.string(key: "CPU_eCoresColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var pCoresColor: NSColor {
        let color = SColor.indigo
        let key = Store.shared.string(key: "CPU_pCoresColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var sCoresColor: NSColor {
        let color = SColor.orange
        let key = Store.shared.string(key: "CPU_sCoresColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    
    public init(_ core: core_s, num: Int) {
        self.core = core
        
        super.init(frame: .zero)
        
        self.heightAnchor.constraint(equalToConstant: 24).isActive = true
        self.orientation = .vertical
        self.distribution = .fillEqually
        self.identifier = NSUserInterfaceItemIdentifier("\(core.id)")
        
        self.bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        self.valueField.font = .systemFont(ofSize: 12)
        
        let header: NSStackView = NSStackView()
        header.orientation = .horizontal
        header.distribution = .fill
        
        var title: String
        switch core.type {
        case .efficiency: title = localizedString("Efficiency core")
        case .performance: title = localizedString("Performance core")
        case .super: title = localizedString("Super core")
        default: title = localizedString("Core")
        }
        title += " \(num)"
        
        header.addArrangedSubview(LabelField(title))
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(self.valueField)
        
        self.addArrangedSubview(header)
        self.addArrangedSubview(self.bar)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setValue(_ newValue: Double) {
        self.valueField.stringValue = "\(Int(newValue.rounded(toPlaces: 2) * 100))%"
        let color = self.core.type == .efficiency ? self.eCoresColor : self.core.type == .super ? self.sCoresColor : self.pCoresColor
        self.bar.setValue(ColorValue(newValue, color: color))
    }
}
