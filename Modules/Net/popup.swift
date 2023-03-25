//
//  popup.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: NSStackView, Popup_p {
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    private var title: String
    
    private var uploadView: NSView? = nil
    private var uploadValue: Int64 = 0
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    private var uploadStateView: ColorView? = nil
    
    private var downloadView: NSView? = nil
    private var downloadValue: Int64 = 0
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    private var downloadStateView: ColorView? = nil
    
    private var downloadColorView: NSView? = nil
    private var uploadColorView: NSView? = nil
    
    private var localIPField: ValueField? = nil
    private var interfaceField: ValueField? = nil
    private var macAddressField: ValueField? = nil
    private var totalUploadField: ValueField? = nil
    private var totalDownloadField: ValueField? = nil
    private var statusField: ValueField? = nil
    private var connectivityField: ValueField? = nil
    
    private var publicIPStackView: NSStackView? = nil
    private var publicIPv4Field: ValueField? = nil
    private var publicIPv6Field: ValueField? = nil
    
    private var ssidField: ValueField? = nil
    private var standardField: ValueField? = nil
    private var securityField: ValueField? = nil
    private var channelField: ValueField? = nil
    
    private var processesView: NSView? = nil
    
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    private var connectionInitialized: Bool = false
    
    private var chart: NetworkChartView? = nil
    private var processes: [NetworkProcessView] = []
    
    private var base: DataSizeBase {
        get {
            return DataSizeBase(rawValue: Store.shared.string(key: "\(self.title)_base", defaultValue: "byte")) ?? .byte
        }
    }
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    private var processesHeight: CGFloat {
        get {
            let num = self.numberOfProcesses
            return (22*CGFloat(num)) + (num == 0 ? 0 : Constants.Popup.separatorHeight)
        }
    }
    
    private var downloadColorState: Color = .secondBlue
    private var downloadColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.downloadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColorState: Color = .secondRed
    private var uploadColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.uploadColorState.additional as? NSColor {
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
            height: 0
        ))
        
        self.downloadColorState = Color.fromString(Store.shared.string(key: "\(self.title)_downloadColor", defaultValue: self.downloadColorState.key))
        self.uploadColorState = Color.fromString(Store.shared.string(key: "\(self.title)_uploadColor", defaultValue: self.uploadColorState.key))
        
        self.spacing = 0
        self.orientation = .vertical
        
        self.addArrangedSubview(self.initDashboard())
        self.addArrangedSubview(self.initChart())
        self.addArrangedSubview(self.initDetails())
        self.addArrangedSubview(self.initPublicIP())
        self.addArrangedSubview(self.initProcesses())
        
        self.recalculateHeight()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func recalculateHeight() {
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    // MARK: - views
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 90))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let leftPart: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let uploadFields = self.topValueView(leftPart, title: localizedString("Uploading"), color: self.uploadColor)
        self.uploadView = uploadFields.0
        self.uploadValueField = uploadFields.1
        self.uploadUnitField = uploadFields.2
        self.uploadStateView = uploadFields.3
        
        let rightPart: NSView = NSView(frame: NSRect(x: view.frame.width / 2, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let downloadFields = self.topValueView(rightPart, title: localizedString("Downloading"), color: self.downloadColor)
        self.downloadView = downloadFields.0
        self.downloadValueField = downloadFields.1
        self.downloadUnitField = downloadFields.2
        self.downloadStateView = downloadFields.3
        
        view.addSubview(leftPart)
        view.addSubview(rightPart)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 90 + Constants.Popup.separatorHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: 90), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = 3
        
        let chart = NetworkChartView(frame: NSRect(
            x: 0,
            y: 1,
            width: container.frame.width,
            height: container.frame.height - 2
        ), num: 120, outColor: self.uploadColor, inColor: self.downloadColor)
        chart.base = self.base
        container.addSubview(chart)
        self.chart = chart
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        container.orientation = .vertical
        container.spacing = 0
        
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Popup.separatorHeight))
        
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: view.frame.width - 18, y: 6, width: 18, height: 18)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = NSImageScaling.scaleAxesIndependently
        button.contentTintColor = .lightGray
        button.action = #selector(self.resetTotalNetworkUsage)
        button.target = self
        button.toolTip = localizedString("Reset")
        button.image = Bundle(for: Module.self).image(forResource: "refresh")!
        
        row.addSubview(separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: 0), width: self.frame.width))
        row.addSubview(button)
        
        container.addArrangedSubview(row)
        
        (self.uploadColorView, self.totalUploadField) = popupWithColorRow(container, color: self.uploadColor, n: 0, title: "\(localizedString("Total upload")):", value: "0")
        (self.downloadColorView, self.totalDownloadField) = popupWithColorRow(container, color: self.downloadColor, n: 0, title: "\(localizedString("Total download")):", value: "0")
        
        self.statusField = popupRow(container, n: 0, title: "\(localizedString("Status")):", value: localizedString("Unknown")).1
        self.connectivityField = popupRow(container, n: 0, title: "\(localizedString("Internet connection")):", value: localizedString("Unknown")).1
        
        self.ssidField = popupRow(container, n: 0, title: "\(localizedString("Network")):", value: localizedString("Unknown")).1
        self.standardField = popupRow(container, n: 0, title: "\(localizedString("Standard")):", value: localizedString("Unknown")).1
        self.securityField = popupRow(container, n: 0, title: "\(localizedString("Security")):", value: localizedString("Unknown")).1
        self.channelField = popupRow(container, n: 0, title: "\(localizedString("Channel")):", value: localizedString("Unknown")).1
        
        self.interfaceField = popupRow(container, n: 0, title: "\(localizedString("Interface")):", value: localizedString("Unknown")).1
        self.macAddressField = popupRow(container, n: 0, title: "\(localizedString("Physical address")):", value: localizedString("Unknown")).1
        self.localIPField = popupRow(container, n: 0, title: "\(localizedString("Local IP")):", value: localizedString("Unknown")).1
        
        self.localIPField?.isSelectable = true
        self.macAddressField?.isSelectable = true
        
        view.addSubview(container)
        
        let h = container.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        view.setFrameSize(NSSize(width: self.frame.width, height: h))
        container.setFrameSize(NSSize(width: self.frame.width, height: view.bounds.height))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        container.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        return view
    }
    
    private func initPublicIP() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        container.orientation = .vertical
        container.spacing = 0
        
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Popup.separatorHeight))
        
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: view.frame.width - 18, y: 6, width: 18, height: 18)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = NSImageScaling.scaleAxesIndependently
        button.contentTintColor = .lightGray
        button.action = #selector(self.refreshPublicIP)
        button.target = self
        button.toolTip = localizedString("Refresh")
        button.image = Bundle(for: Module.self).image(forResource: "refresh")!
        
        row.addSubview(separatorView(localizedString("Public IP"), origin: NSPoint(x: 0, y: 0), width: self.frame.width))
        row.addSubview(button)
        
        container.addArrangedSubview(row)
        
        self.publicIPv4Field = popupRow(container, title: "\(localizedString("v4")):", value: localizedString("Unknown")).1
        self.publicIPv6Field = popupRow(container, title: "\(localizedString("v6")):", value: localizedString("Unknown")).1
        
        self.publicIPv4Field?.isSelectable = true
        if let valueView = self.publicIPv6Field {
            valueView.isSelectable = true
            valueView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            valueView.setFrameOrigin(NSPoint(x: valueView.frame.origin.x, y: 1))
        }
        
        view.addSubview(container)
        
        let h = container.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        view.setFrameSize(NSSize(width: self.frame.width, height: h))
        container.setFrameSize(NSSize(width: self.frame.width, height: view.bounds.height))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        container.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        self.publicIPStackView = container
        
        return view
    }
    
    private func initProcesses() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        for i in 0..<self.numberOfProcesses {
            let processView = NetworkProcessView(CGFloat(i))
            self.processes.append(processView)
            container.addSubview(processView)
        }
        
        view.addSubview(separator)
        view.addSubview(container)
        
        self.processesView = view
        return view
    }
    
    // MARK: - callbacks
    
    public func numberOfProcessesUpdated() {
        if self.processes.count == self.numberOfProcesses {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.processes = []
            
            if let view = self.processesView {
                self.removeView(view)
            }
            self.addArrangedSubview(self.initProcesses())
            self.processesInitialized = false
            
            self.recalculateHeight()
        })
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.uploadValue = value.bandwidth.upload
                self.downloadValue = value.bandwidth.download
                self.setUploadDownloadFields()
                
                self.totalUploadField?.stringValue = Units(bytes: value.total.upload).getReadableMemory()
                self.totalDownloadField?.stringValue = Units(bytes: value.total.download).getReadableMemory()
                
                if let interface = value.interface {
                    self.interfaceField?.stringValue = "\(interface.displayName) (\(interface.BSDName))"
                    self.macAddressField?.stringValue = interface.address
                } else {
                    self.interfaceField?.stringValue = localizedString("Unknown")
                    self.macAddressField?.stringValue = localizedString("Unknown")
                }
                
                if value.connectionType == .wifi {
                    self.ssidField?.stringValue = value.wifiDetails.ssid ?? localizedString("Unknown")
                    if let v = value.wifiDetails.RSSI {
                        self.ssidField?.stringValue += " (\(v))"
                    }
                    var rssi = localizedString("Unknown")
                    if let v = value.wifiDetails.RSSI {
                        rssi = "\(v) dBm"
                    }
                    var noise = localizedString("Unknown")
                    if let v = value.wifiDetails.noise {
                        noise = "\(v) dBm"
                    }
                    var txRate = localizedString("Unknown")
                    if let v = value.wifiDetails.transmitRate {
                        txRate = "\(v) Mbps"
                    }
                    self.ssidField?.toolTip = "RSSI: \(rssi)\nNoise: \(noise)\nTransmit rate: \(txRate)"
                    
                    self.standardField?.stringValue = value.wifiDetails.standard ?? localizedString("Unknown")
                    self.securityField?.stringValue = value.wifiDetails.security ?? localizedString("Unknown")
                    self.channelField?.stringValue = value.wifiDetails.channel ?? localizedString("Unknown")
                    
                    let number = value.wifiDetails.channelNumber ?? localizedString("Unknown")
                    let band = value.wifiDetails.channelBand ?? localizedString("Unknown")
                    let width = value.wifiDetails.channelWidth ?? localizedString("Unknown")
                    self.channelField?.toolTip = "Channel number: \(number)\nChannel band: \(band)\nChannel width: \(width)\nTransmit rate: \(txRate)"
                } else {
                    self.ssidField?.stringValue = localizedString("Unavailable")
                    self.standardField?.stringValue = localizedString("Unavailable")
                    self.securityField?.stringValue = localizedString("Unavailable")
                    self.channelField?.stringValue = localizedString("Unavailable")
                }
                
                if let view = self.publicIPv4Field, view.stringValue != value.raddr.v4 {
                    if let addr = value.raddr.v4 {
                        view.stringValue = (value.wifiDetails.countryCode != nil) ? "\(addr) (\(value.wifiDetails.countryCode!))" : addr
                    } else {
                        view.stringValue = localizedString("Unknown")
                    }
                }
                if let view = self.publicIPv6Field, view.stringValue != value.raddr.v6 {
                    if let addr = value.raddr.v6 {
                        view.stringValue = addr
                    } else {
                        view.stringValue = localizedString("Unknown")
                    }
                }
                
                if self.localIPField?.stringValue != value.laddr {
                    self.localIPField?.stringValue = value.laddr ?? localizedString("Unknown")
                }
                
                self.statusField?.stringValue = localizedString(value.status ? "UP" : "DOWN")
                
                self.initialized = true
            }
            
            if let chart = self.chart {
                if chart.base != self.base {
                    chart.base = self.base
                }
                chart.addValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
            }
        })
    }
    
    public func connectivityCallback(_ value: Bool?) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.connectionInitialized {
                var text = "Unknown"
                if let v = value {
                    text = v ? "UP" : "DOWN"
                }
                
                self.connectivityField?.stringValue = localizedString(text)
                self.connectionInitialized = true
            }
        })
    }
    
    public func processCallback(_ list: [Network_Process]) {
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
                let process = list[i]
                let index = list.count-i-1
                self.processes[index].attachProcess(process)
                self.processes[index].upload = Units(bytes: Int64(process.upload)).getReadableSpeed(base: self.base)
                self.processes[index].download = Units(bytes: Int64(process.download)).getReadableSpeed(base: self.base)
            }
            
            self.processesInitialized = true
        })
    }
    
    public func resetConnectivityView() {
        self.connectivityField?.stringValue = localizedString("Unknown")
    }
    
    // MARK: - Settings
    
    public func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Color of upload"),
            action: #selector(toggleUploadColor),
            items: Color.allColors,
            selected: self.uploadColorState.key
        ))
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Color of download"),
            action: #selector(toggleDownloadColor),
            items: Color.allColors,
            selected: self.downloadColorState.key
        ))
        
        return view
    }
    
    @objc private func toggleUploadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.uploadColorState = newValue
        Store.shared.set(key: "\(self.title)_uploadColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.uploadColorView?.layer?.backgroundColor = color.cgColor
            self.uploadStateView?.setColor(color)
            self.chart?.setColors(out: color)
        }
    }
    @objc private func toggleDownloadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.downloadColorState = newValue
        Store.shared.set(key: "\(self.title)_downloadColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.downloadColorView?.layer?.backgroundColor = color.cgColor
            self.downloadStateView?.setColor(color)
            self.chart?.setColors(in: color)
        }
    }
    
    // MARK: - helpers
    
    private func topValueView(_ view: NSView, title: String, color: NSColor) -> (NSView, NSTextField, NSTextField, ColorView) {
        let topHeight: CGFloat = 30
        let titleHeight: CGFloat = 15
        
        let valueWidth = "0".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        let unitWidth = "KB/s".widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        let topPartWidth = valueWidth + unitWidth
        
        let topView: NSView = NSView(frame: NSRect(
            x: (view.frame.width-topPartWidth)/2,
            y: (view.frame.height - topHeight - titleHeight)/2 + titleHeight,
            width: topPartWidth,
            height: topHeight
        ))
        
        let valueField = LabelField(frame: NSRect(x: 0, y: 0, width: valueWidth, height: 30), "0")
        valueField.font = NSFont.systemFont(ofSize: 26, weight: .light)
        valueField.textColor = .textColor
        valueField.alignment = .right
        
        let unitField = LabelField(frame: NSRect(x: valueField.frame.width, y: 4, width: unitWidth, height: 15), "KB/s")
        unitField.font = NSFont.systemFont(ofSize: 13, weight: .light)
        unitField.textColor = .labelColor
        unitField.alignment = .left
        
        let titleWidth: CGFloat = title.widthOfString(usingFont: NSFont.systemFont(ofSize: 12, weight: .regular))+8
        let iconSize: CGFloat = 12
        let bottomWidth: CGFloat = titleWidth+iconSize
        let bottomView: NSView = NSView(frame: NSRect(
            x: (view.frame.width-bottomWidth)/2,
            y: topView.frame.origin.y - titleHeight,
            width: bottomWidth,
            height: titleHeight
        ))
        
        let colorBlock: ColorView = ColorView(frame: NSRect(x: 0, y: 1, width: iconSize, height: iconSize), color: color, radius: 4)
        let titleField = LabelField(frame: NSRect(x: iconSize, y: 0, width: titleWidth, height: titleHeight), title)
        titleField.alignment = .center
        
        topView.addSubview(valueField)
        topView.addSubview(unitField)
        
        bottomView.addSubview(colorBlock)
        bottomView.addSubview(titleField)
        
        view.addSubview(topView)
        view.addSubview(bottomView)
        
        return (topView, valueField, unitField, colorBlock)
    }
    
    private func setUploadDownloadFields() {
        let upload = Units(bytes: self.uploadValue).getReadableTuple(base: self.base)
        let download = Units(bytes: self.downloadValue).getReadableTuple(base: self.base)
        
        var valueWidth = "\(upload.0)".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        var unitWidth = upload.1.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        var topPartWidth = valueWidth + unitWidth
        
        self.uploadView?.setFrameSize(NSSize(width: topPartWidth, height: self.uploadView!.frame.height))
        self.uploadView?.setFrameOrigin(NSPoint(x: ((self.frame.width/2)-topPartWidth)/2, y: self.uploadView!.frame.origin.y))
        
        self.uploadValueField?.setFrameSize(NSSize(width: valueWidth, height: self.uploadValueField!.frame.height))
        self.uploadValueField?.stringValue = "\(upload.0)"
        self.uploadUnitField?.setFrameSize(NSSize(width: unitWidth, height: self.uploadUnitField!.frame.height))
        self.uploadUnitField?.setFrameOrigin(NSPoint(x: self.uploadValueField!.frame.width, y: self.uploadUnitField!.frame.origin.y))
        self.uploadUnitField?.stringValue = upload.1
        
        valueWidth = "\(download.0)".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        unitWidth = download.1.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        topPartWidth = valueWidth + unitWidth
        
        self.downloadView?.setFrameSize(NSSize(width: topPartWidth, height: self.downloadView!.frame.height))
        self.downloadView?.setFrameOrigin(NSPoint(x: ((self.frame.width/2)-topPartWidth)/2, y: self.downloadView!.frame.origin.y))
        
        self.downloadValueField?.setFrameSize(NSSize(width: valueWidth, height: self.downloadValueField!.frame.height))
        self.downloadValueField?.stringValue = "\(download.0)"
        self.downloadUnitField?.setFrameSize(NSSize(width: unitWidth, height: self.downloadUnitField!.frame.height))
        self.downloadUnitField?.setFrameOrigin(NSPoint(x: self.downloadValueField!.frame.width, y: self.downloadUnitField!.frame.origin.y))
        self.downloadUnitField?.stringValue = download.1
        
        self.uploadStateView?.setState(self.uploadValue != 0)
        self.downloadStateView?.setState(self.downloadValue != 0)
    }
    
    @objc private func refreshPublicIP() {
        NotificationCenter.default.post(name: .refreshPublicIP, object: nil, userInfo: nil)
    }
    
    @objc private func resetTotalNetworkUsage() {
        NotificationCenter.default.post(name: .resetTotalNetworkUsage, object: nil, userInfo: nil)
    }
}

public class NetworkProcessView: NSView {
    public var width: CGFloat {
        get { return 0 }
        set {
            self.setFrameSize(NSSize(width: newValue, height: self.frame.height))
        }
    }
    
    public var icon: NSImage? {
        get { return NSImage() }
        set {
            self.imageView?.image = newValue
        }
    }
    public var label: String {
        get { return "" }
        set {
            self.labelView?.stringValue = newValue
        }
    }
    public var upload: String {
        get { return "" }
        set {
            self.uploadView?.stringValue = newValue
        }
    }
    public var download: String {
        get { return "" }
        set {
            self.downloadView?.stringValue = newValue
        }
    }
    
    private var imageView: NSImageView? = nil
    private var labelView: LabelField? = nil
    private var uploadView: ValueField? = nil
    private var downloadView: ValueField? = nil
    
    public init(_ n: CGFloat) {
        super.init(frame: NSRect(x: 0, y: n*22, width: Constants.Popup.width, height: 16))
        
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 16))
        
        let imageView: NSImageView = NSImageView(frame: NSRect(x: 2, y: 2, width: 12, height: 12))
        let labelView: LabelField = LabelField(frame: NSRect(x: 18, y: 0, width: rowView.frame.width - 138, height: 16), "")
        let uploadView: ValueField = ValueField(frame: NSRect(x: rowView.frame.width - 120, y: 1.75, width: 60, height: 12), "")
        let downloadView: ValueField = ValueField(frame: NSRect(x: rowView.frame.width - 60, y: 1.75, width: 60, height: 12), "")
        uploadView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        downloadView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        
        rowView.addSubview(imageView)
        rowView.addSubview(labelView)
        rowView.addSubview(uploadView)
        rowView.addSubview(downloadView)
        
        self.imageView = imageView
        self.labelView = labelView
        self.uploadView = uploadView
        self.downloadView = downloadView
        
        self.addSubview(rowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func attachProcess(_ process: Network_Process) {
        self.label = process.name
        self.icon = process.icon
        self.toolTip = "pid: \(process.pid)"
    }
    
    public func clear() {
        self.label = ""
        self.download = ""
        self.upload = ""
        self.icon = nil
        self.toolTip = ""
    }
}
