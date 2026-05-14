//
//  preview.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09/05/2026
//  Using Swift 6.0
//  Running on macOS 26.4
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//  

import Cocoa
import Kit

internal class Preview: PreviewWrapper {
    private var chart: NetworkChartView? = nil
    private var grid: GridChartView? = nil
    
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    private var downloadStateView: ColorView? = nil
    
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    private var uploadStateView: ColorView? = nil
    
    private var totalUploadField: ValueField? = nil
    private var totalDownloadField: ValueField? = nil
    private var statusField: StatusBadgeView? = nil
    private var connectivityField: StatusBadgeView? = nil
    private var latencyField: ValueField? = nil
    private var jitterField: ValueField? = nil
    
    private var interfaceField: ValueField? = nil
    private var interfaceStatusField: StatusBadgeView? = nil
    private var macAddressField: ValueField? = nil
    private var connectionTypeField: ValueField? = nil
    private var ssidField: ValueField? = nil
    private var bssidField: ValueField? = nil
    private var standardField: ValueField? = nil
    private var securityField: ValueField? = nil
    private var channelField: ValueField? = nil
    private var signalField: ValueField? = nil
    private var speedField: ValueField? = nil
    
    private var localIPField: ValueField? = nil
    private var publicIPv4Field: ValueField? = nil
    private var publicIPv6Field: ValueField? = nil
    private var dnsField: ValueField? = nil
    
    private var initialized: Bool = false
    private var connectionInitialized: Bool = false
    
    private var downloadColorState: SColor = .secondBlue
    private var downloadColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.downloadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColorState: SColor = .secondRed
    private var uploadColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.uploadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.module.stringValue)_base", defaultValue: "byte")) ?? .byte
    }
    
    public init(_ module: ModuleType) {
        super.init(type: module)
        
        self.loadColors()
        
        self.addArrangedSubview(PreferencesSection([self.usageView()]))
        self.addArrangedSubview(PreferencesSection([self.historyView()]))
        self.addArrangedSubview(PreferencesSection(title: localizedString("Connectivity history"), [self.connectivityView()]))
        
        let splitView = NSStackView()
        splitView.orientation = .horizontal
        splitView.distribution = .fillEqually
        splitView.alignment = .top
        splitView.addArrangedSubview(PreferencesSection(title: localizedString("Details"), [self.detailsView()]))
        splitView.addArrangedSubview(PreferencesSection(title: localizedString("Interface"), [self.interfaceView()]))
        
        self.addArrangedSubview(splitView)
        self.addArrangedSubview(PreferencesSection(title: localizedString("Address"), [self.addressesView()]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadColors() {
        self.downloadColorState = SColor.fromString(Store.shared.string(key: "\(self.module.stringValue)_downloadColor", defaultValue: self.downloadColorState.key))
        self.uploadColorState = SColor.fromString(Store.shared.string(key: "\(self.module.stringValue)_uploadColor", defaultValue: self.uploadColorState.key))
    }
    
    private func usageView() -> NSView {
        let view = NSStackView()
        view.distribution = .fillEqually
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
        
        let download = self.usageValueView(title: localizedString("Downloading"), color: self.downloadColor)
        let upload = self.usageValueView(title: localizedString("Uploading"), color: self.uploadColor)
        
        self.downloadValueField = download.1
        self.downloadUnitField = download.2
        self.downloadStateView = download.3
        
        self.uploadValueField = upload.1
        self.uploadUnitField = upload.2
        self.uploadStateView = upload.3
        
        view.addArrangedSubview(download.0)
        view.addArrangedSubview(upload.0)
        
        return view
    }
    
    private func historyView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin*2
        view.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let chart = NetworkChartView(num: 600)
        self.chart = chart
        chart.setColors(in: self.downloadColor, out: self.uploadColor)
        chart.setLegend(x: true, y: false)
        view.addArrangedSubview(chart)
        
        return view
    }
    
    private func connectivityView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin*2
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        let grid = GridChartView(grid: (50, 6))
        self.grid = grid
        view.addArrangedSubview(grid)
        
        return view
    }
    
    private func detailsView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.totalUploadField = previewRow(view, color: self.uploadColor, title: "\(localizedString("Total upload")):", value: "0")
        self.totalDownloadField = previewRow(view, color: self.downloadColor, title: "\(localizedString("Total download")):", value: "0")
        self.statusField = previewBadgeRow(view, title: "\(localizedString("Status")):")
        self.connectivityField = previewBadgeRow(view, title: "\(localizedString("Internet connection")):")
        self.latencyField = previewRow(view, title: "\(localizedString("Latency")):", value: "0 ms")
        self.jitterField = previewRow(view, title: "\(localizedString("Jitter")):", value: "0 ms")
        
        return view
    }
    
    private func interfaceView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.interfaceField = previewRow(view, title: "\(localizedString("Interface")):", value: localizedString("Unknown"))
        self.interfaceStatusField = previewBadgeRow(view, title: "\(localizedString("Status")):")
        self.connectionTypeField = previewRow(view, title: "\(localizedString("Connection type")):", value: localizedString("Unknown"))
        self.macAddressField = previewRow(view, title: "\(localizedString("Physical address")):", value: localizedString("Unknown"))
        self.macAddressField?.isSelectable = true
        self.ssidField = previewRow(view, title: "\(localizedString("Network")):", value: "")
        self.ssidField?.superview?.isHidden = true
        self.bssidField = previewRow(view, title: "\(localizedString("BSSID")):", value: "")
        self.bssidField?.isSelectable = true
        self.bssidField?.superview?.isHidden = true
        self.standardField = previewRow(view, title: "\(localizedString("Standard")):", value: "")
        self.standardField?.superview?.isHidden = true
        self.securityField = previewRow(view, title: "\(localizedString("Security")):", value: "")
        self.securityField?.superview?.isHidden = true
        self.channelField = previewRow(view, title: "\(localizedString("Channel")):", value: "")
        self.channelField?.superview?.isHidden = true
        self.signalField = previewRow(view, title: "\(localizedString("Signal")):", value: "")
        self.signalField?.superview?.isHidden = true
        self.speedField = previewRow(view, title: "\(localizedString("Speed")):", value: localizedString("Unknown"))
        
        return view
    }
    
    private func addressesView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.localIPField = previewRow(view, title: "\(localizedString("Local IP")):", value: localizedString("Unknown"))
        self.localIPField?.isSelectable = true
        self.publicIPv4Field = previewRow(view, title: "\(localizedString("Public IP")) (v4):", value: "")
        self.publicIPv4Field?.isSelectable = true
        self.publicIPv4Field?.superview?.isHidden = true
        self.publicIPv6Field = previewRow(view, title: "\(localizedString("Public IP")) (v6):", value: "")
        self.publicIPv6Field?.isSelectable = true
        self.publicIPv6Field?.superview?.isHidden = true
        self.dnsField = previewRow(view, title: "\(localizedString("DNS Server")):", value: localizedString("Unknown"))
        self.dnsField?.isSelectable = true
        
        return view
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                let upload = Units(bytes: value.bandwidth.upload).getReadableTuple(base: self.base)
                let download = Units(bytes: value.bandwidth.download).getReadableTuple(base: self.base)
                
                self.uploadValueField?.stringValue = "\(upload.0)"
                self.uploadUnitField?.stringValue = upload.1
                
                self.downloadValueField?.stringValue = "\(download.0)"
                self.downloadUnitField?.stringValue = download.1
                
                self.uploadStateView?.setState(value.bandwidth.upload != 0)
                self.downloadStateView?.setState(value.bandwidth.download != 0)
                
                self.totalUploadField?.stringValue = Units(bytes: value.total.upload).getReadableMemory()
                self.totalDownloadField?.stringValue = Units(bytes: value.total.download).getReadableMemory()
                
                self.statusField?.setStatus(value.status)

                if let interface = value.interface {
                    self.interfaceField?.stringValue = "\(interface.displayName) (\(interface.BSDName))"
                    self.interfaceStatusField?.setStatus(interface.status)
                    self.macAddressField?.stringValue = interface.address
                    self.speedField?.stringValue = "\(Int(interface.transmitRate.rounded()))Mbps"
                } else {
                    self.interfaceField?.stringValue = localizedString("Unknown")
                    self.interfaceStatusField?.setStatus(nil)
                    self.macAddressField?.stringValue = localizedString("Unknown")
                    self.speedField?.stringValue = localizedString("Unknown")
                }
                
                self.connectionTypeField?.stringValue = value.connectionType?.rawValue.capitalized ?? localizedString("Unknown")
                
                let isWifi = value.connectionType == .wifi
                
                if isWifi, let ssid = value.wifiDetails.ssid {
                    self.ssidField?.stringValue = ssid
                    self.ssidField?.superview?.isHidden = false
                } else {
                    self.ssidField?.superview?.isHidden = true
                }
                
                if isWifi, let bssid = value.wifiDetails.bssid {
                    self.bssidField?.stringValue = bssid
                    self.bssidField?.superview?.isHidden = false
                } else {
                    self.bssidField?.superview?.isHidden = true
                }
                
                if isWifi, let standard = value.wifiDetails.standard {
                    self.standardField?.stringValue = standard
                    self.standardField?.superview?.isHidden = false
                } else {
                    self.standardField?.superview?.isHidden = true
                }
                
                if isWifi, let security = value.wifiDetails.security {
                    self.securityField?.stringValue = security
                    self.securityField?.superview?.isHidden = false
                } else {
                    self.securityField?.superview?.isHidden = true
                }
                
                if isWifi, let channel = value.wifiDetails.channel {
                    var str = channel
                    var extras: [String] = []
                    if let band = value.wifiDetails.channelBand { extras.append(band) }
                    if let width = value.wifiDetails.channelWidth { extras.append(width) }
                    if !extras.isEmpty {
                        str += " (\(extras.joined(separator: ", ")))"
                    }
                    self.channelField?.stringValue = str
                    self.channelField?.superview?.isHidden = false
                } else {
                    self.channelField?.superview?.isHidden = true
                }
                
                if isWifi, let rssi = value.wifiDetails.RSSI {
                    var str = "\(rssi) dBm"
                    if let noise = value.wifiDetails.noise {
                        str += " (\(localizedString("Noise")): \(noise) dBm)"
                    }
                    self.signalField?.stringValue = str
                    self.signalField?.superview?.isHidden = false
                } else {
                    self.signalField?.superview?.isHidden = true
                }
                
                var localIP = localizedString("Unknown")
                if let v4 = value.laddr.v4, !v4.isEmpty {
                    localIP = v4
                } else if let v6 = value.laddr.v6, !v6.isEmpty {
                    localIP = v6
                }
                self.localIPField?.stringValue = localIP
                
                if let v4 = value.raddr.v4, !v4.isEmpty {
                    var ip = v4
                    if let cc = value.raddr.countryCode, !cc.isEmpty {
                        ip += " (\(cc))"
                    }
                    self.publicIPv4Field?.stringValue = ip
                    self.publicIPv4Field?.superview?.isHidden = false
                } else {
                    self.publicIPv4Field?.superview?.isHidden = true
                }
                
                if let v6 = value.raddr.v6, !v6.isEmpty {
                    var ip = v6
                    if let cc = value.raddr.countryCode, !cc.isEmpty {
                        ip += " (\(cc))"
                    }
                    self.publicIPv6Field?.stringValue = ip
                    self.publicIPv6Field?.superview?.isHidden = false
                } else {
                    self.publicIPv6Field?.superview?.isHidden = true
                }
                
                if !value.dns.isEmpty {
                    self.dnsField?.stringValue = value.dns.joined(separator: ", ")
                } else {
                    self.dnsField?.stringValue = localizedString("Unknown")
                }
                
                self.initialized = true
            }
            
            if let chart = self.chart {
                chart.addValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
            }
        })
    }
    
    public func connectivityCallback(_ value: Network_Connectivity?) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.connectionInitialized {
                if let value {
                    self.connectivityField?.setStatus(value.status)
                    self.latencyField?.stringValue = "\(Int(value.latency)) ms"
                    self.jitterField?.stringValue = "\(Int(value.jitter)) ms"
                }
                self.connectionInitialized = true
            }
            
            if let value, let chart = self.grid {
                chart.addValue(value.status)
            }
        })
    }
    
    // MARK: - helpers
    
    private func usageValueView(title: String, color: NSColor) -> (NSView, NSTextField, NSTextField, ColorView) {
        let view = NSView()
        
        let container = NSStackView()
        container.distribution = .fill
        container.orientation = .vertical
        container.spacing = 0
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let valueView = NSStackView()
        valueView.distribution = .fill
        valueView.orientation = .horizontal
        valueView.alignment = .lastBaseline
        valueView.spacing = 0
        valueView.translatesAutoresizingMaskIntoConstraints = false
        
        let valueField = LabelField()
        valueField.font = NSFont.systemFont(ofSize: 26, weight: .light)
        valueField.textColor = .textColor
        valueField.alignment = .right
        valueField.stringValue = "0"
        
        let unitField = LabelField()
        unitField.font = NSFont.systemFont(ofSize: 13, weight: .light)
        unitField.textColor = .labelColor
        unitField.alignment = .left
        unitField.stringValue = "KB/s"
        
        valueView.addArrangedSubview(valueField)
        valueView.addArrangedSubview(unitField)
        
        let labelView = NSStackView()
        labelView.distribution = .fill
        labelView.orientation = .horizontal
        labelView.spacing = 0
        labelView.translatesAutoresizingMaskIntoConstraints = false
        
        let colorBlock: ColorView = ColorView(frame: NSRect(x: 0, y: 0, width: 12, height: 12), color: color, radius: 4)
        colorBlock.widthAnchor.constraint(equalToConstant: 12).isActive = true
        colorBlock.heightAnchor.constraint(equalToConstant: 12).isActive = true
        let titleField = LabelField(title)
        titleField.alignment = .center
        
        labelView.addArrangedSubview(colorBlock)
        labelView.addArrangedSubview(titleField)
        
        container.addArrangedSubview(valueView)
        container.addArrangedSubview(labelView)
        
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return (view, valueField, unitField, colorBlock)
    }
}
