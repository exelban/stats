//
//  preview.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 11/04/2026
//  Using Swift 6.0
//  Running on macOS 26.4
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//  

import Cocoa
import Kit

internal class Preview: PreviewWrapper {
    private var initialized: Bool = false
    
    private var fpsField: NSTextField? = nil
    
    private var utilizationBar: BarChartView? = nil
    private var utilizationField: NSTextField? = nil
    
    private var renderBar: BarChartView? = nil
    private var renderField: NSTextField? = nil
    
    private var tilerBar: BarChartView? = nil
    private var tilerField: NSTextField? = nil
    
    private var aneBar: BarChartView? = nil
    private var aneField: NSTextField? = nil
    
    private var utilizationLineChart: LineChartView? = nil
    private var aneLineChart: LineChartView? = nil
    private var renderLineChart: LineChartView? = nil
    private var tilerLineChart: LineChartView? = nil
    private var fpsLineChart: LineChartView? = nil
    
    private var selectedGPU: String {
        Store.shared.string(key: "\(self.module.stringValue)_gpu", defaultValue: "")
    }
    
    public init(_ module: ModuleType) {
        super.init(type: module)
        
        self.addArrangedSubview(PreferencesSection([self.quickView()]))
        
        let (historyView, historyChart) = self.historyView()
        self.utilizationLineChart = historyChart
        
        let (aneHistoryView, aneHistoryChart) = self.historyView()
        self.aneLineChart = aneHistoryChart
        
        let (renderHistoryView, renderHistoryChart) = self.historyView()
        self.renderLineChart = renderHistoryChart
        
        let (tilerHistoryView, tilerHistoryChart) = self.historyView()
        self.tilerLineChart = tilerHistoryChart
        
        let (fpsHistoryView, fpsHistoryChart) = self.historyView()
        fpsHistoryChart.setSuffix(" fps")
        self.fpsLineChart = fpsHistoryChart
        
        let firstSplitView = NSStackView()
        firstSplitView.orientation = .horizontal
        firstSplitView.distribution = .fillEqually
        firstSplitView.addArrangedSubview(PreferencesSection(label: localizedString("GPU utilization history"), [historyView]))
        firstSplitView.addArrangedSubview(PreferencesSection(label: localizedString("ANE utilization history"), [aneHistoryView]))
        
        let secondSplitView = NSStackView()
        secondSplitView.orientation = .horizontal
        secondSplitView.distribution = .fillEqually
        secondSplitView.addArrangedSubview(PreferencesSection(label: localizedString("Render utilization history"), [renderHistoryView]))
        secondSplitView.addArrangedSubview(PreferencesSection(label: localizedString("Tiler utilization history"), [tilerHistoryView]))
        
        self.addArrangedSubview(firstSplitView)
        self.addArrangedSubview(secondSplitView)
        self.addArrangedSubview(PreferencesSection(label: localizedString("FPS history"), [fpsHistoryView]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func quickView() -> NSView {
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
        
        let details: NSView = {
            let view = NSStackView()
            view.orientation = .vertical
            view.distribution = .fillEqually
            view.spacing = 2
            
            var titleValue = localizedString("Unknown")
            let gpu = SystemKit.shared.device.info.gpu?.first{ $0.id == self.selectedGPU } ?? SystemKit.shared.device.info.gpu?.first
            if let gpu {
                if let name = gpu.name {
                    titleValue = name
                }
                if let cores = gpu.cores {
                    titleValue.append(" (\(cores) cores)")
                }
            }
            
            let fpsField = LabelField("0 FPS")
            self.fpsField = fpsField
            
            let title = NSStackView()
            title.addArrangedSubview(LabelField(titleValue))
            title.addArrangedSubview(NSView())
            title.addArrangedSubview(fpsField)
            
            let bars: NSView = {
                let view = NSStackView()
                view.orientation = .horizontal
                view.distribution = .fillEqually
                view.spacing = 4
                
                let left: NSView = {
                    let view = NSStackView()
                    view.orientation = .vertical
                    view.distribution = .fillEqually
                    view.spacing = 2
                    
                    let utilization = self.barView(title: localizedString("GPU utilization"))
                    self.utilizationBar = utilization.1
                    self.utilizationField = utilization.2
                    let render = self.barView(title: localizedString("Render utilization"))
                    self.renderBar = render.1
                    self.renderField = render.2
                    
                    view.addArrangedSubview(utilization.0)
                    view.addArrangedSubview(render.0)
                    
                    return view
                }()
                
                let right: NSView = {
                    let view = NSStackView()
                    view.orientation = .vertical
                    view.distribution = .fillEqually
                    view.spacing = 2
                    
                    let ane = self.barView(title: localizedString("ANE utilization"))
                    self.aneBar = ane.1
                    self.aneField = ane.2
                    let tiler = self.barView(title: localizedString("Tiler utilization"))
                    self.tilerBar = tiler.1
                    self.tilerField = tiler.2
                    
                    view.addArrangedSubview(ane.0)
                    view.addArrangedSubview(tiler.0)
                    
                    return view
                }()
                
                view.addArrangedSubview(left)
                view.addArrangedSubview(right)
                
                return view
            }()
            
            view.addArrangedSubview(title)
            view.addArrangedSubview(bars)
            
            return view
        }()
        
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func historyView() -> (NSView, LineChartView) {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin*2
        view.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let chart = LineChartView(num: 600)
        chart.setLegend(x: true, y: true)
        view.addArrangedSubview(chart)
        
        return (view, chart)
    }
    
    private func barView(title: String) -> (NSView, BarChartView, NSTextField) {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        let titleField = LabelField(title)
        titleField.font = .systemFont(ofSize: 10, weight: .regular)
        let valueField = ValueField()
        valueField.font = .systemFont(ofSize: 10, weight: .regular)
        
        let header: NSStackView = NSStackView()
        header.orientation = .horizontal
        header.distribution = .fill
        
        header.addArrangedSubview(titleField)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(valueField)
        
        let bar = BarChartView(size: 8, horizontal: true)
        bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        
        view.addArrangedSubview(header)
        view.addArrangedSubview(bar)
        
        return (view, bar, valueField)
    }
    
    internal func loadCallback(_ value: GPU_Info) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                if let value = value.utilization {
                    self.utilizationField?.stringValue = "\(Int(value.rounded(toPlaces: 2) * 100))%"
                    self.utilizationBar?.setValue(ColorValue(value))
                }
                if let value = value.renderUtilization {
                    self.renderField?.stringValue = "\(Int(value.rounded(toPlaces: 2) * 100))%"
                    self.renderBar?.setValue(ColorValue(value))
                }
                if let value = value.tilerUtilization {
                    self.tilerField?.stringValue = "\(Int(value.rounded(toPlaces: 2) * 100))%"
                    self.tilerBar?.setValue(ColorValue(value))
                }
                if let value = value.aneUtilization {
                    self.aneField?.stringValue = "\(Int(value.rounded(toPlaces: 2) * 100))%"
                    self.aneBar?.setValue(ColorValue(value))
                }
                if let value = value.fps {
                    self.fpsField?.stringValue = "\(Int(value)) FPS"
                }
                self.initialized = true
            }
            if let value = value.utilization {
                self.utilizationLineChart?.addValue(value)
            }
            if let value = value.aneUtilization {
                self.aneLineChart?.addValue(value)
            }
            if let value = value.renderUtilization {
                self.renderLineChart?.addValue(value)
            }
            if let value = value.tilerUtilization {
                self.tilerLineChart?.addValue(value)
            }
            if let value = value.fps {
                self.fpsLineChart?.addValue(value/100)
            }
        })
    }
}
