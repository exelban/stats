//
//  RAMPopup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

extension RAM {
    public func initPopup() {
        self.popup.view.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
        
        makeChart()
        makeOverview()
        makeProcesses()
    }
    
    private func makeChart() {
        let lineColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 1.0)
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)
        
        self.chart = LineChartView(frame: CGRect(x: 0, y: TabHeight - 110, width: TabWidth, height: 102))
        self.chart.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInCubic)
        self.chart.backgroundColor = .white
        self.chart.noDataText = "No \(self.name) usage data"
        self.chart.legend.enabled = false
        self.chart.scaleXEnabled = false
        self.chart.scaleYEnabled = false
        self.chart.pinchZoomEnabled = false
        self.chart.doubleTapToZoomEnabled = false
        self.chart.drawBordersEnabled = false
        self.chart.autoScaleMinMaxEnabled = true
        
        self.chart.rightAxis.enabled = false
        
        let v = self.readers.filter{ $0 is RAMUsageReader }.first as! RAMUsageReader
        self.chart.leftAxis.axisMinimum = 0
        self.chart.leftAxis.axisMaximum = Units(bytes: Int64(v.totalSize)).gigabytes
        self.chart.leftAxis.labelCount = Units(bytes: Int64(v.totalSize)).gigabytes > 16 ? 6 : 4
        self.chart.leftAxis.drawGridLinesEnabled = false
        self.chart.leftAxis.drawAxisLineEnabled = false
        
        self.chart.leftAxis.gridColor = NSColor(red:220/255, green:220/255, blue:220/255, alpha:1)
        self.chart.leftAxis.gridLineWidth = 0.5
        self.chart.leftAxis.drawGridLinesEnabled = true
        self.chart.leftAxis.labelTextColor = NSColor(red:150/255, green:150/255, blue:150/255, alpha:1)
        
        self.chart.xAxis.drawAxisLineEnabled = false
        self.chart.xAxis.drawLimitLinesBehindDataEnabled = false
        self.chart.xAxis.gridLineWidth = 0.5
        self.chart.xAxis.drawGridLinesEnabled = false
        self.chart.xAxis.drawLabelsEnabled = false
        
        let marker = ChartMarker()
        marker.chartView = self.chart
        self.chart.marker = marker
        
        var lineChartEntry  = [ChartDataEntry]()
        lineChartEntry.append(ChartDataEntry(x: 0, y: 0))
        let chartDataSet = LineChartDataSet(entries: lineChartEntry, label: "\(self.name) Usage")
        chartDataSet.drawCirclesEnabled = false
        chartDataSet.mode = .cubicBezier
        chartDataSet.cubicIntensity = 0.1
        chartDataSet.colors = [lineColor]
        chartDataSet.fillColor = gradientColor
        chartDataSet.drawFilledEnabled = true
        
        let data = LineChartData()
        data.addDataSet(chartDataSet)
        data.setDrawValues(false)
        
        self.chart.data = LineChartData(dataSet: chartDataSet)
        
        self.popup.view.view?.addSubview(self.chart)
    }
    
    public func chartUpdater(value: RAMUsage) {
        if self.chart.data == nil { return }

        let index = Double((self.chart.data?.getDataSetByIndex(0)?.entryCount)!)
        let usage = Units(bytes: Int64(value.used)).getReadableTuple().0
        self.chart.data?.addEntry(ChartDataEntry(x: index, y: usage), dataSetIndex: 0)

        if index > 120 {
            self.chart.xAxis.axisMinimum = index - 120
        }
        self.chart.xAxis.axisMaximum = index
        
        if self.popup.active {
            self.chart.notifyDataSetChanged()
            self.chart.moveViewToX(index)
        }
    }
    
    private func makeOverview() {
        let overviewLabel: NSView = NSView(frame: NSRect(x: 0, y: TabHeight - 140, width: TabWidth, height: 25))
        
        overviewLabel.wantsLayer = true
        overviewLabel.layer?.backgroundColor = NSColor(hexString: "#eeeeee", alpha: 0.5).cgColor
        
        let overviewText: NSTextField = NSTextField(string: "Overview")
        overviewText.frame = NSRect(x: 0, y: 0, width: TabWidth, height: overviewLabel.frame.size.height - 4)
        overviewText.isEditable = false
        overviewText.isSelectable = false
        overviewText.isBezeled = false
        overviewText.wantsLayer = true
        overviewText.textColor = .darkGray
        overviewText.canDrawSubviewsIntoLayer = true
        overviewText.alignment = .center
        overviewText.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        overviewText.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        overviewLabel.addSubview(overviewText)
        self.popup.view.view?.addSubview(overviewLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 147, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let total: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        total.orientation = .horizontal
        total.distribution = .equalCentering
        let totalLabel = LabelField(string: "Total")
        self.totalValue = ValueField(string: "0 GB")
        total.addView(totalLabel, in: .center)
        total.addView(self.totalValue, in: .center)
        
        let used: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        used.orientation = .horizontal
        used.distribution = .equalCentering
        let usedLabel = LabelField(string: "Used")
        self.usedValue = ValueField(string: "0 GB")
        used.addView(usedLabel, in: .center)
        used.addView(self.usedValue, in: .center)
        
        let free: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        free.orientation = .horizontal
        free.distribution = .equalCentering
        let freeLabel = LabelField(string: "Free")
        self.freeValue = ValueField(string: "0 GB")
        free.addView(freeLabel, in: .center)
        free.addView(self.freeValue, in: .center)
        
        vertical.addSubview(total)
        vertical.addSubview(used)
        vertical.addSubview(free)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    public func overviewUpdater(value: RAMUsage) {
        if !self.popup.active && self.popup.initialized { return }
        
        self.totalValue.stringValue = Units(bytes: Int64(value.total)).getReadableMemory()
        self.usedValue.stringValue = Units(bytes: Int64(value.used)).getReadableMemory()
        self.freeValue.stringValue = Units(bytes: Int64(value.free)).getReadableMemory()
    }
    
    private func makeProcesses() {
        let label: NSView = NSView(frame: NSRect(x: 0, y: 0, width: TabWidth, height: 25))
        
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor(hexString: "#eeeeee", alpha: 0.5).cgColor
        
        let text: NSTextField = NSTextField(string: "Top Processes")
        text.frame = NSRect(x: 0, y: 0, width: TabWidth, height: label.frame.size.height - 4)
        text.isEditable = false
        text.isSelectable = false
        text.isBezeled = false
        text.wantsLayer = true
        text.textColor = .darkGray
        text.canDrawSubviewsIntoLayer = true
        text.alignment = .center
        text.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        text.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        label.addSubview(text)
        self.popup.view.view?.addSubview(label)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 4, width: TabWidth, height: stackHeight*5))
        vertical.orientation = .vertical
        vertical.distribution = .fill
        
        self.processViewList = []
        let process_1 = makeProcessView(num: 4, height: stackHeight, label: "", value: "")
        let process_2 = makeProcessView(num: 3, height: stackHeight, label: "", value: "")
        let process_3 = makeProcessView(num: 2, height: stackHeight, label: "", value: "")
        let process_4 = makeProcessView(num: 1, height: stackHeight, label: "", value: "")
        let process_5 = makeProcessView(num: 0, height: stackHeight, label: "", value: "")
        
        self.processViewList.append(process_1)
        self.processViewList.append(process_2)
        self.processViewList.append(process_3)
        self.processViewList.append(process_4)
        self.processViewList.append(process_5)
        
        vertical.addSubview(process_1)
        vertical.addSubview(process_2)
        vertical.addSubview(process_3)
        vertical.addSubview(process_4)
        vertical.addSubview(process_5)
        self.popup.view.view?.addSubview(vertical)
        
        label.frame = NSRect(x: 0, y: vertical.frame.origin.y + vertical.frame.size.height + 2, width: TabWidth, height: 25)
        self.popup.view.view?.addSubview(label)
    }
    
    public func processesUpdater(value: [TopProcess]) {
        if self.processViewList.isEmpty || !self.popup.active && self.popup.initialized { return }
        self.popup.initialized = true
        
        for (i, process) in value.enumerated() {
            if i < 5 {
                let processView = self.processViewList[i]
                
                (processView.subviews[0] as! NSTextField).stringValue = process.command
                (processView.subviews[1] as! NSTextField).stringValue = Units(bytes: Int64(process.usage)).getReadableMemory()
            }
        }
    }
    
    private func makeProcessView(num: Int, height: CGFloat, label: String, value: String) -> NSStackView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 10, y: CGFloat(num)*height, width: TabWidth - 20, height: height))
        view.orientation = .horizontal
        view.distribution = .equalCentering
        let viewLabel = LabelField(string: label)
        let viewValue = ValueField(string: value)
        view.addView(viewLabel, in: .center)
        view.addView(viewValue, in: .center)
        
        return view
    }
}
