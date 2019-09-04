//
//  MemoryView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 04/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Foundation
import Charts

extension Memory {
    
    func initTab() {
        self.tabView.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
        
        makeChart()
        makeOverview()
        makeProcesses()
        
        (self.reader as! MemoryReader).usage.subscribe(observer: self) { (value, _) in
            self.updateChart(value: Units(bytes: Int64(value.used)).getReadableTuple().0)
        }
    }
    
    func makeChart() {
        let reader = self.reader as! MemoryReader
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
        
        self.chart.rightAxis.enabled = false
        
        self.chart.leftAxis.axisMinimum = 0
        self.chart.leftAxis.axisMaximum = Units(bytes: Int64(reader.totalSize)).gigabytes
        self.chart.leftAxis.labelCount = Units(bytes: Int64(reader.totalSize)).gigabytes > 16 ? 6 : 4
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
        
        let lineChartEntry  = [ChartDataEntry]()
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
        
        self.tabView.view?.addSubview(self.chart)
    }
    
    func updateChart(value: Double) {
        let index = Double((self.chart.data?.getDataSetByIndex(0)?.entryCount)!)
        self.chart.data?.addEntry(ChartDataEntry(x: index, y: value), dataSetIndex: 0)
        
        if index > 120 {
            self.chart.xAxis.axisMinimum = index - 120
        }
        self.chart.xAxis.axisMaximum = index
        self.chart.notifyDataSetChanged()
        self.chart.moveViewToX(index)
    }
    
    func makeOverview() {
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
        self.tabView.view?.addSubview(overviewLabel)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 147, width: TabWidth, height: stackHeight*3))
        vertical.orientation = .vertical
        
        let total: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        total.orientation = .horizontal
        total.distribution = .equalCentering
        let totalLabel = labelField(string: "Total")
        let totalValue = valueField(string: "0 GB")
        total.addView(totalLabel, in: .center)
        total.addView(totalValue, in: .center)
        
        let used: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        used.orientation = .horizontal
        used.distribution = .equalCentering
        let usedLabel = labelField(string: "Used")
        let usedValue = valueField(string: "0 GB")
        used.addView(usedLabel, in: .center)
        used.addView(usedValue, in: .center)
        
        let free: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        free.orientation = .horizontal
        free.distribution = .equalCentering
        let freeLabel = labelField(string: "Free")
        let freeValue = valueField(string: "0 GB")
        free.addView(freeLabel, in: .center)
        free.addView(freeValue, in: .center)
        
        vertical.addSubview(total)
        vertical.addSubview(used)
        vertical.addSubview(free)
        
        self.tabView.view?.addSubview(vertical)
        
        (self.reader as! MemoryReader).usage.subscribe(observer: self) { (value, _) in
            totalValue.stringValue = Units(bytes: Int64(value.total)).getReadableUnit()
            usedValue.stringValue = Units(bytes: Int64(value.used)).getReadableUnit()
            freeValue.stringValue = Units(bytes: Int64(value.free)).getReadableUnit()
        }
    }
    
    func makeProcesses() {
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
        self.tabView.view?.addSubview(label)
        
        let stackHeight: CGFloat = 22
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 4, width: TabWidth, height: stackHeight*5))
        vertical.orientation = .vertical
        vertical.distribution = .fill
        
        var processViewList: [NSStackView] = []
        let process_1 = makeProcessView(num: 4, height: stackHeight, label: "", value: "")
        let process_2 = makeProcessView(num: 3, height: stackHeight, label: "", value: "")
        let process_3 = makeProcessView(num: 2, height: stackHeight, label: "", value: "")
        let process_4 = makeProcessView(num: 1, height: stackHeight, label: "", value: "")
        let process_5 = makeProcessView(num: 0, height: stackHeight, label: "", value: "")
        
        processViewList.append(process_1)
        processViewList.append(process_2)
        processViewList.append(process_3)
        processViewList.append(process_4)
        processViewList.append(process_5)
        
        vertical.addSubview(process_1)
        vertical.addSubview(process_2)
        vertical.addSubview(process_3)
        vertical.addSubview(process_4)
        vertical.addSubview(process_5)
        self.tabView.view?.addSubview(vertical)
        
        label.frame = NSRect(x: 0, y: vertical.frame.origin.y + vertical.frame.size.height + 2, width: TabWidth, height: 25)
        self.tabView.view?.addSubview(label)
        
        (self.reader as! MemoryReader).processes.subscribe(observer: self) { (processes, _) in
            for (i, process) in processes.enumerated() {
                if i < 5 {
                    let processView = processViewList[i]
                    
                    (processView.subviews[0] as! NSTextField).stringValue = process.command
                    (processView.subviews[1] as! NSTextField).stringValue = Units(bytes: Int64(process.usage)).getReadableUnit()
                }
            }
        }
    }
    
    func makeProcessView(num: Int, height: CGFloat, label: String, value: String) -> NSStackView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 10, y: CGFloat(num)*height, width: TabWidth - 20, height: height))
        view.orientation = .horizontal
        view.distribution = .equalCentering
        let viewLabel = labelField(string: label)
        let viewValue = valueField(string: value)
        view.addView(viewLabel, in: .center)
        view.addView(viewValue, in: .center)
        
        return view
    }
    
    func labelField(string: String) -> NSTextField {
        let label: NSTextField = NSTextField(string: string)
        
        label.isEditable = false
        label.isSelectable = false
        label.isBezeled = false
        label.textColor = .black
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        
        return label
    }
    
    func valueField(string: String) -> NSTextField {
        let label: NSTextField = NSTextField(string: string)
        
        label.isEditable = false
        label.isSelectable = false
        label.isBezeled = false
        label.textColor = .black
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.backgroundColor = NSColor(hexString: "#dddddd", alpha: 0)
        
        return label
    }
}
