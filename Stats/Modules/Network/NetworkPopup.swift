//
//  NetworkPopup.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 22/01/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Charts

extension Network {
    public func initPopup() {
        self.popup.view.view?.frame = NSRect(x: 0, y: 0, width: TabWidth, height: TabHeight)
        
        makeChart()
        makeOverview()
        makeDataOverview()
    }
    
    private func makeChart() {
        let downloadLineColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 1.0)
        let downloadGradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.5)
        
        let uploadLineColor: NSColor = NSColor(red: (1), green: (0), blue: (0), alpha: 1.0)
        let uploadGradientColor: NSColor = NSColor(red: (1), green: (0), blue: (0), alpha: 0.5)

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
        
        self.chart.leftAxis.valueFormatter = ChartsNetworkAxisFormatter()
        self.chart.leftAxis.axisMinimum = 0
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

        let marker = ChartNetworkMarker()
        marker.chartView = self.chart
        self.chart.marker = marker
        
        var downloadLineChartEntry  = [ChartDataEntry]()
        downloadLineChartEntry.append(ChartDataEntry(x: 0, y: 0))
        let download = LineChartDataSet(entries: downloadLineChartEntry, label: "Download")
        download.drawCirclesEnabled = false
        download.mode = .cubicBezier
        download.cubicIntensity = 0.1
        download.colors = [downloadLineColor]
        download.fillColor = downloadGradientColor
        download.drawFilledEnabled = true
        
        var uploadLineChartEntry  = [ChartDataEntry]()
        uploadLineChartEntry.append(ChartDataEntry(x: 0, y: 0))
        let upload = LineChartDataSet(entries: uploadLineChartEntry, label: "Upload")
        upload.drawCirclesEnabled = false
        upload.mode = .cubicBezier
        upload.cubicIntensity = 0.1
        upload.colors = [uploadLineColor]
        upload.fillColor = uploadGradientColor
        upload.drawFilledEnabled = true
        
        let data = LineChartData()
        data.addDataSet(download)
        data.addDataSet(upload)
        data.setDrawValues(false)
        
        self.chart.data = data
        self.popup.view.view?.addSubview(self.chart)
    }
    
    public func chartUpdater(value: NetworkUsage) {
        if self.chart.data == nil { return }

        let index = Double((self.chart.data?.getDataSetByIndex(0)?.entryCount)!)
        self.chart.data?.addEntry(ChartDataEntry(x: index, y: Double(value.download)), dataSetIndex: 0)
        self.chart.data?.addEntry(ChartDataEntry(x: index, y: Double(value.upload)), dataSetIndex: 1)

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
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 125, width: TabWidth, height: stackHeight*4))
        vertical.orientation = .vertical
        
        let publicIP: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*3, width: TabWidth - 20, height: stackHeight))
        publicIP.orientation = .horizontal
        publicIP.distribution = .equalCentering
        let publicIPLabel = LabelField(string: "Public IP")
        self.publicIPValue = ValueField(string: "No connection")
        publicIP.addView(publicIPLabel, in: .center)
        publicIP.addView(self.publicIPValue, in: .center)
        
        let localIP: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        localIP.orientation = .horizontal
        localIP.distribution = .equalCentering
        let localIPLabel = LabelField(string: "Local IP")
        self.localIPValue = ValueField(string: "No connection")
        localIP.addView(localIPLabel, in: .center)
        localIP.addView(self.localIPValue, in: .center)
        
        let network: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        network.orientation = .horizontal
        network.distribution = .equalCentering
        let networkLabel = LabelField(string: "Network")
        self.networkValue = ValueField(string: "No connection")
        network.addView(networkLabel, in: .center)
        network.addView(self.networkValue, in: .center)
        
        let physical: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        physical.orientation = .horizontal
        physical.distribution = .equalCentering
        let physicalLabel = LabelField(string: "Physical address")
        self.physicalValue = ValueField(string: "No connection")
        physical.addView(physicalLabel, in: .center)
        physical.addView(self.physicalValue, in: .center)
        
        vertical.addSubview(publicIP)
        vertical.addSubview(localIP)
        vertical.addSubview(network)
        vertical.addSubview(physical)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    public func overviewUpdater(value: NetworkInterface) {
        if !self.popup.active && self.popup.initialized && !value.force { return }
        self.popup.initialized = true

        if !value.active {
            self.clearOverview()
            return
        }
        
        if let publicIP = value.publicIP {
//            if value.countryCode != nil {
//                publicIP = "\(publicIP) (\(value.countryCode!))"
//            }
            self.publicIPValue.stringValue = publicIP
        }
        if let localIP = value.localIP {
            self.localIPValue.stringValue = localIP
        }
        if var networkType = value.networkType {
            if value.wifiName != nil {
                networkType = "\(value.wifiName!) (\(networkType))"
            }
            self.networkValue.stringValue = networkType
        }
        if let macAddress = value.macAddress {
            self.physicalValue.stringValue = macAddress.uppercased()
        }
    }
    
    private func clearOverview() {
        self.publicIPValue.stringValue = "No connection"
        self.localIPValue.stringValue = "No connection"
        self.networkValue.stringValue = "No connection"
        self.physicalValue.stringValue = "No connection"
    }
    
    private func makeDataOverview() {
        let label: NSView = NSView(frame: NSRect(x: 0, y: 95, width: TabWidth, height: 25))
        
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor(hexString: "#eeeeee", alpha: 0.5).cgColor
        
        let text: NSTextField = NSTextField(string: "Data overview")
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
        let vertical: NSStackView = NSStackView(frame: NSRect(x: 0, y: 4, width: TabWidth, height: stackHeight*4))
        vertical.orientation = .vertical
        
        let upload: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*3, width: TabWidth - 20, height: stackHeight))
        upload.orientation = .horizontal
        upload.distribution = .equalCentering
        let uploadLabel = LabelField(string: "Upload")
        self.uploadValue = ValueField(string: "0 KB/s")
        upload.addView(uploadLabel, in: .center)
        upload.addView(self.uploadValue, in: .center)
        
        let download: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*2, width: TabWidth - 20, height: stackHeight))
        download.orientation = .horizontal
        download.distribution = .equalCentering
        let downloadLabel = LabelField(string: "Download")
        self.downloadValue = ValueField(string: "0 KB/s")
        download.addView(downloadLabel, in: .center)
        download.addView(self.downloadValue, in: .center)
        
        let totalUpload: NSStackView = NSStackView(frame: NSRect(x: 10, y: stackHeight*1, width: TabWidth - 20, height: stackHeight))
        totalUpload.orientation = .horizontal
        totalUpload.distribution = .equalCentering
        let totalUploadLabel = LabelField(string: "Total upload")
        self.totalUploadValue = ValueField(string: "0 KB")
        totalUpload.addView(totalUploadLabel, in: .center)
        totalUpload.addView(self.totalUploadValue, in: .center)
        
        let totalDownload: NSStackView = NSStackView(frame: NSRect(x: 10, y: 0, width: TabWidth - 20, height: stackHeight))
        totalDownload.orientation = .horizontal
        totalDownload.distribution = .equalCentering
        let totalDownloadLabel = LabelField(string: "Total download")
        self.totalDownloadValue = ValueField(string: "0 KB")
        totalDownload.addView(totalDownloadLabel, in: .center)
        totalDownload.addView(self.totalDownloadValue, in: .center)
        
        vertical.addSubview(upload)
        vertical.addSubview(download)
        vertical.addSubview(totalUpload)
        vertical.addSubview(totalDownload)
        
        self.popup.view.view?.addSubview(vertical)
    }
    
    public func dataUpdater(value: NetworkUsage) {
        if !self.popup.active && self.popup.initialized { return }
        
        self.downloadValue.stringValue = Units(bytes: value.download).getReadableSpeed()
        self.uploadValue.stringValue = Units(bytes: value.upload).getReadableSpeed()
        
        self.totalDownloadValue.stringValue = Units(bytes: value.totalDownload).getReadableMemory()
        self.totalUploadValue.stringValue = Units(bytes: value.totalUpload).getReadableMemory()
    }
}
