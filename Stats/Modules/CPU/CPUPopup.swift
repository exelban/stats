//
//  CPUPopup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

extension CPU {
    public func initPopup() {
        self.popup.view.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
        
        makeChart()
        makeOverview()
        makeProcesses()
    }
    
    private func makeChart() {
        let lineColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 1.0)
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)

        self.popup.chart = LineChartView(frame: CGRect(x: 0, y: TabHeight - 110, width: TabWidth, height: 102))
        self.popup.chart.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .easeInCubic)
        self.popup.chart.backgroundColor = .white
        self.popup.chart.noDataText = "No \(self.name) usage data"
        self.popup.chart.legend.enabled = false
        self.popup.chart.scaleXEnabled = false
        self.popup.chart.scaleYEnabled = false
        self.popup.chart.pinchZoomEnabled = false
        self.popup.chart.doubleTapToZoomEnabled = false
        self.popup.chart.drawBordersEnabled = false
        
        self.popup.chart.rightAxis.enabled = false
        
        self.popup.chart.leftAxis.axisMinimum = 0
        self.popup.chart.leftAxis.axisMaximum = 100
        self.popup.chart.leftAxis.labelCount = 6
        self.popup.chart.leftAxis.drawGridLinesEnabled = false
        self.popup.chart.leftAxis.drawAxisLineEnabled = false
        
        self.popup.chart.leftAxis.gridColor = NSColor(red:220/255, green:220/255, blue:220/255, alpha:1)
        self.popup.chart.leftAxis.gridLineWidth = 0.5
        self.popup.chart.leftAxis.drawGridLinesEnabled = true
        self.popup.chart.leftAxis.labelTextColor = NSColor(red:150/255, green:150/255, blue:150/255, alpha:1)
        
        self.popup.chart.xAxis.drawAxisLineEnabled = false
        self.popup.chart.xAxis.drawLimitLinesBehindDataEnabled = false
        self.popup.chart.xAxis.gridLineWidth = 0.5
        self.popup.chart.xAxis.drawGridLinesEnabled = false
        self.popup.chart.xAxis.drawLabelsEnabled = false
        
        let marker = ChartMarker()
        marker.chartView = self.popup.chart
        self.popup.chart.marker = marker
        
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
        
        self.popup.chart.data = LineChartData(dataSet: chartDataSet)
        
        self.popup.view.view?.addSubview(self.popup.chart)
    }
    
    public func updateChart(value: Double) {
        let v: Double = Double((value * 100).roundTo(decimalPlaces: 2))!
        
        let index = Double((self.popup.chart.data?.getDataSetByIndex(0)?.entryCount)!)
        self.popup.chart.data?.addEntry(ChartDataEntry(x: index, y: v), dataSetIndex: 0)

        if index > 120 {
            self.popup.chart.xAxis.axisMinimum = index - 120
        }

        self.popup.chart.xAxis.axisMaximum = index
        self.popup.chart.notifyDataSetChanged()
        self.popup.chart.moveViewToX(index)
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
        
        let system: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        system.orientation = .horizontal
        system.distribution = .equalCentering
        let systemLabel = LabelField(string: "System")
        self.systemValue = ValueField(string: "0 %")
        system.addView(systemLabel, in: .center)
        system.addView(self.systemValue, in: .center)
        
        let user: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        user.orientation = .horizontal
        user.distribution = .equalCentering
        let userLabel = LabelField(string: "User")
        self.userValue = ValueField(string: "0 %")
        user.addView(userLabel, in: .center)
        user.addView(self.userValue, in: .center)
        
        let idle: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        idle.orientation = .horizontal
        idle.distribution = .equalCentering
        let idleLabel = LabelField(string: "Idle")
        self.idleValue = ValueField(string: "0 %")
        idle.addView(idleLabel, in: .center)
        idle.addView(self.idleValue, in: .center)
        
        vertical.addSubview(system)
        vertical.addSubview(user)
        vertical.addSubview(idle)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    public func usageUpdater(value: CPUUsage) {
        self.systemValue.stringValue = "\(value.system.roundTo(decimalPlaces: 2)) %"
        self.userValue.stringValue = "\(value.user.roundTo(decimalPlaces: 2)) %"
        self.idleValue.stringValue = "\(value.idle.roundTo(decimalPlaces: 2)) %"
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
        for (i, process) in value.enumerated() {
            if i < 5 {
                let processView = self.processViewList[i]
                
                (processView.subviews[0] as! NSTextField).stringValue = process.command
                (processView.subviews[1] as! NSTextField).stringValue = "\(process.usage.roundTo(decimalPlaces: 2)) %"
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
