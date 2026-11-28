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

// swiftlint:disable:next type_body_length
internal class Popup: PopupWrapper {
    private let bandwidthHistory = NetworkChartData(capacity: 180)
    private let connectivityHistory = GridChartData(capacity: 90)
    private var uploadRow: BandwidthRow? = nil
    private var uploadValue: Int64 = 0
    
    private var downloadRow: BandwidthRow? = nil
    private var downloadValue: Int64 = 0
    
    private var downloadColorView: NSView? = nil
    private var uploadColorView: NSView? = nil
    
    private var internetStatusField: NSTextField? = nil
    private var latencyField: NSTextField? = nil
    private var jitterField: NSTextField? = nil
    
    private var totalUploadLabel: LabelField? = nil
    private var totalUploadField: ValueField? = nil
    private var totalDownloadLabel: LabelField? = nil
    private var totalDownloadField: ValueField? = nil
    
    private var interfaceView: NSStackView? = nil
    private var interfaceField: ValueField? = nil
    private var interfaceStatusField: ValueField? = nil
    private var macAddressField: ValueField? = nil
    private var ssidField: ValueField? = nil
    private var standardField: ValueField? = nil
    private var channelField: ValueField? = nil
    private var ssidView: NSView? = nil
    
    private var interfaceDetailsState: Bool = false
    private var standardView: NSView? = nil
    private var channelView: NSView? = nil
    private var interfaceSpeedView: NSView? = nil
    private var interfaceSpeedField: ValueField? = nil
    private var dnsServersView: NSView? = nil
    private var dnsServersField: ValueField? = nil
    
    private var addressView: NSStackView? = nil
    private var localIPField: ValueField? = nil
    private var publicIPv4Field: ValueField? = nil
    private var publicIPv6Field: ValueField? = nil
    private var publicIPv4View: NSView? = nil
    private var publicIPv6View: NSView? = nil
    private var publicIPState: Bool = true
    private var emojiCCState: Bool = true
    
    private var processesView: NSView? = nil
    private var processes: ProcessesView? = nil
    
    private var chart: NetworkChartView? = nil
    private var reverseOrderState: Bool = false
    private var chartHistory: Int = 180
    private var chartScale: Scale = .none
    private var chartFixedScale: Int = 12
    private var chartFixedScaleSize: SizeUnit = .MB
    private var chartPrefSection: PreferencesSection? = nil
    private var connectivityChart: GridChartView? = nil
    
    private let processesCache = PopupCache<[Network_Process]>()
    
    private let usageCache = PopupCache<Network_Usage>()
    private let connectivityCache = PopupCache<Network_Connectivity?>()
    
    private var latency: [Double] = []
    private var jitter: [Double] = []
    
    public var locationPermissionAction: (() -> Void)?
    private var locationPermissionButton: NSButton?
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.title)_base", defaultValue: "byte")) ?? .byte
    }
    private var speedUnit: String {
        networkSpeedUnit(from: Store.shared.string(key: "\(self.title)_speedUnit", defaultValue: NetworkSpeedUnitAuto)).key
    }
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (22*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    
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
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.spacing = 0
        self.orientation = .vertical
        
        self.downloadColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_downloadColor", defaultValue: self.downloadColorState.key))
        self.uploadColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_uploadColor", defaultValue: self.uploadColorState.key))
        self.reverseOrderState = Store.shared.bool(key: "\(self.title)_reverseOrder", defaultValue: self.reverseOrderState)
        self.chartHistory = Store.shared.int(key: "\(self.title)_chartHistory", defaultValue: self.chartHistory)
        self.bandwidthHistory.resize(self.chartHistory)
        self.chartScale = Scale.fromString(Store.shared.string(key: "\(self.title)_chartScale", defaultValue: self.chartScale.key))
        self.chartFixedScale = Store.shared.int(key: "\(self.title)_chartFixedScale", defaultValue: self.chartFixedScale)
        self.chartFixedScaleSize = SizeUnit.fromString(Store.shared.string(key: "\(self.title)_chartFixedScaleSize", defaultValue: self.chartFixedScaleSize.key))
        self.publicIPState = Store.shared.bool(key: "\(self.title)_publicIP", defaultValue: self.publicIPState)
        self.interfaceDetailsState = Store.shared.bool(key: "\(self.title)_interfaceDetails", defaultValue: self.interfaceDetailsState)
        self.emojiCCState = Store.shared.bool(key: "\(self.title)_emojiCC", defaultValue: self.emojiCCState)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadContent() {
        self.addSection(self.initDashboard())
        self.addArrangedSubview(self.initChart())
        self.addArrangedSubview(self.initConnectivityChart())
        self.addArrangedSubview(self.initDetails())
        self.addArrangedSubview(self.initInterface())
        self.addArrangedSubview(self.initAddress())
        self.addArrangedSubview(self.initProcesses())
        
        if !self.publicIPState {
            self.addressView?.removeFromSuperview()
        }
        
        self.resizeToFitContent()
    }
    
    public override func unloadContent() {
        self.uploadRow = nil
        self.downloadRow = nil
        self.downloadColorView = nil
        self.uploadColorView = nil
        self.totalUploadLabel = nil
        self.totalUploadField = nil
        self.totalDownloadLabel = nil
        self.totalDownloadField = nil
        self.internetStatusField = nil
        self.latencyField = nil
        self.jitterField = nil
        self.interfaceView = nil
        self.interfaceField = nil
        self.interfaceStatusField = nil
        self.macAddressField = nil
        self.ssidField = nil
        self.standardField = nil
        self.channelField = nil
        self.ssidView = nil
        self.standardView = nil
        self.channelView = nil
        self.interfaceSpeedView = nil
        self.interfaceSpeedField = nil
        self.dnsServersView = nil
        self.dnsServersField = nil
        self.addressView = nil
        self.localIPField = nil
        self.publicIPv4Field = nil
        self.publicIPv6Field = nil
        self.publicIPv4View = nil
        self.publicIPv6View = nil
        self.processesView = nil
        self.processes = nil
        self.chart = nil
        self.connectivityChart = nil
        self.locationPermissionButton = nil
    }
    
    public override func appear() {
        self.replay(self.processesCache, render: self.renderProcesses)
        self.replay(self.usageCache, render: self.renderUsage)
        self.replay(self.connectivityCache, render: self.renderConnectivity)
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    // MARK: - Views
    
    private func initDashboard() -> NSView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: Constants.Popup.dashboardHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.margins
        view.edgeInsets = .init(top: Constants.Popup.margins, left: Constants.Popup.margins, bottom: Constants.Popup.margins, right: Constants.Popup.margins)
        
        let speed = NSStackView()
        speed.orientation = .vertical
        speed.alignment = .leading
        speed.spacing = Constants.Popup.margins
        
        let upload = BandwidthRow(
            icon: "arrow.up",
            title: localizedString("Uploading"),
            color: self.uploadColor
        )
        let download = BandwidthRow(
            icon: "arrow.down",
            title: localizedString("Downloading"),
            color: self.downloadColor
        )
        self.uploadRow = upload
        self.downloadRow = download
        speed.addArrangedSubview(upload)
        speed.addArrangedSubview(download)
        upload.widthAnchor.constraint(equalTo: speed.widthAnchor).isActive = true
        download.widthAnchor.constraint(equalTo: speed.widthAnchor).isActive = true
        self.setUploadDownloadFields()
        
        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Constants.Popup.spacing*2
        
        let status = PopupDashboardDetailsRow(
            icon: "globe",
            title: localizedString("Internet connection"),
            dafaultValue: "n/a"
        )
        self.internetStatusField = status.valueView
        let latency = PopupDashboardDetailsRow(
            icon: "timer",
            title: localizedString("Latency"),
            dafaultValue: "n/a"
        )
        self.latencyField = latency.valueView
        let jitter = PopupDashboardDetailsRow(
            icon: "waveform.path.ecg",
            title: localizedString("Jitter"),
            dafaultValue: "n/a"
        )
        self.jitterField = jitter.valueView
        
        details.addArrangedSubview(status)
        details.addArrangedSubview(latency)
        details.addArrangedSubview(jitter)
        
        view.addArrangedSubview(speed)
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 90 + Constants.Popup.separatorHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: 90), width: self.frame.width)
        
        let chart = NetworkChartView(
            frame: NSRect(x: 0, y: 1, width: view.frame.width, height: separator.frame.origin.y - 2),
            num: self.chartHistory, reversedOrder: self.reverseOrderState, outColor: self.uploadColor, inColor: self.downloadColor,
            scale: self.chartScale,
            fixedScale: Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale)),
            history: self.bandwidthHistory
        )
        chart.setBase(self.base)
        chart.setSpeedUnit(self.speedUnit)
        self.chart = chart
        
        view.addSubview(separator)
        view.addSubview(chart)
        
        return view
    }
    
    private func initConnectivityChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 30 + Constants.Popup.separatorHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Connectivity history"), origin: NSPoint(x: 0, y: 30), width: self.frame.width)
        
        let chart = GridChartView(frame: NSRect(x: 0, y: 1, width: view.frame.width, height: separator.frame.origin.y - 2), grid: (30, 3), history: self.connectivityHistory)
        self.connectivityChart = chart
        
        view.addSubview(separator)
        view.addSubview(chart)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.spacing = 0
        
        view.addArrangedSubview(SeparatorView(
            label: localizedString("Details"),
            button: PopupButton(toolTip: localizedString("Reset"), icon: "arrow.clockwise") { [weak self] in
                self?.resetTotalNetworkUsage()
            }
        ))
        
        let totalUpload = popupWithColorRow(view, color: self.uploadColor, title: "\(localizedString("Total upload")):", value: "0")
        let totalDownload = popupWithColorRow(view, color: self.downloadColor, title: "\(localizedString("Total download")):", value: "0")
        
        self.uploadColorView = totalUpload.0
        self.totalUploadLabel = totalUpload.1
        self.totalUploadField = totalUpload.2
        
        self.downloadColorView = totalDownload.0
        self.totalDownloadLabel = totalDownload.1
        self.totalDownloadField = totalDownload.2
        
        return view
    }
    
    private func initInterface() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.spacing = 0
        
        view.addArrangedSubview(SeparatorView(
            label: localizedString("Interface"),
            button: PopupButton(toolTip: localizedString("Details"), state: self.interfaceDetailsState) { [weak self] in
                self?.toggleInterfaceDetails()
            }
        ))
        
        let ssid = popupRow(view, title: "\(localizedString("Network")):", value: localizedString("Unknown"))
        
        let permissionButton = NSButton(title: localizedString("Open Location Settings"), target: self, action: #selector(self.requestLocationPermission))
        permissionButton.bezelStyle = .rounded
        permissionButton.controlSize = .small
        permissionButton.font = .systemFont(ofSize: 11)
        permissionButton.isHidden = true
        
        ssid.2.addSubview(permissionButton)
        self.locationPermissionButton = permissionButton
        
        self.interfaceField = popupRow(view, title: "\(localizedString("Interface")):", value: localizedString("Unknown")).1
        self.interfaceStatusField = popupRow(view, title: "\(localizedString("Status")):", value: "").1
        self.macAddressField = popupRow(view, title: "\(localizedString("Physical address")):", value: localizedString("Unknown")).1
        self.macAddressField?.isSelectable = true
        
        let standard = popupRow(view, title: "\(localizedString("Wi-Fi standard")):", value: localizedString("Unavailable"))
        let channel = popupRow(view, title: "\(localizedString("Channel")):", value: localizedString("Unavailable"))
        let speed = popupRow(view, title: "\(localizedString("Link speed")):", value: localizedString("Unknown"))
        
        self.ssidField = ssid.1
        self.standardField = standard.1
        self.channelField = channel.1
        self.interfaceSpeedField = speed.1
        
        self.ssidView = ssid.2
        self.standardView = standard.2
        self.channelView = channel.2
        self.interfaceSpeedView = speed.2
        
        if !self.interfaceDetailsState {
            self.standardView?.removeFromSuperview()
            self.channelView?.removeFromSuperview()
            self.interfaceSpeedView?.removeFromSuperview()
        }
        
        self.interfaceView = view
        return view
    }
    
    private func initAddress() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.spacing = 0
        
        view.addArrangedSubview(SeparatorView(
            label: localizedString("Address"),
            button: PopupButton(toolTip: localizedString("Refresh"), icon: "arrow.clockwise") { [weak self] in
                self?.refreshPublicIP()
            }
        ))
        
        self.localIPField = popupRow(view, title: "\(localizedString("Local IP")):", value: localizedString("Unknown")).1
        
        let ipV4 = popupRow(view, title: "\(localizedString("Public IP")):", value: localizedString("Unknown"))
        let ipV6 = popupRow(view, title: "\(localizedString("Public IP")):", value: localizedString("Unknown"))
        
        self.publicIPv4Field = ipV4.1
        self.publicIPv6Field = ipV6.1
        self.publicIPv4View = ipV4.2
        self.publicIPv6View = ipV6.2
        
        self.localIPField?.isSelectable = true
        self.publicIPv4Field?.isSelectable = true
        self.publicIPv6Field?.isSelectable = true
        
        if let valueView = self.publicIPv6Field {
            valueView.font = NSFont.systemFont(ofSize: 7, weight: .semibold)
            valueView.setFrameOrigin(NSPoint(x: valueView.frame.origin.x, y: -1))
        }
        
        ipV4.2.removeFromSuperview()
        ipV6.2.removeFromSuperview()
        
        self.addressView = view
        return view
    }
    
    private func initProcesses() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        self.processesView = view
        guard self.numberOfProcesses != 0 else { return view }
        
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: ProcessesView = ProcessesView(
            frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y),
            values: [(localizedString("Downloading"), self.downloadColor), (localizedString("Uploading"), self.uploadColor)],
            n: self.numberOfProcesses
        )
        self.processes = container
        view.addSubview(separator)
        view.addSubview(container)
        return view
    }
    
    // MARK: - Updates
    
    public func numberOfProcessesUpdated() {
        if self.processes?.count == self.numberOfProcesses { return }
        
        DispatchQueue.main.async(execute: {
            guard self.contentLoaded else { return }
            self.processesView?.removeFromSuperview()
            self.processesView = nil
            self.processes = nil
            self.addArrangedSubview(self.initProcesses())
            self.processesCache.initialized = false
            self.resizeToFitContent()
        })
    }
    
    @objc private func requestLocationPermission() {
        guard let action = self.locationPermissionAction else { return }
        if self.usageCache.value?.wifiLocationAuthorization == .denied {
            (self.window as? PopupWindow)?.dismissIfUnlocked()
        }
        action()
    }
    
    public func usageCallback(_ value: Network_Usage) {
        let date = Date()
        self.apply(value, to: self.usageCache, render: self.renderUsage)
        
        DispatchQueue.main.async {
            let sample = (upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download), date: date)
            self.bandwidthHistory.append(upload: sample.upload, download: sample.download, at: sample.date)
            if let chart = self.chart {
                chart.setBase(self.base)
                chart.setSpeedUnit(self.speedUnit)
                chart.historyUpdated()
            }
        }
    }
    
    private func renderUsage(_ value: Network_Usage) {
        var resized = false
        self.uploadValue = value.bandwidth.upload
        self.downloadValue = value.bandwidth.download
        self.setUploadDownloadFields()
        
        self.totalUploadField?.stringValue = Units(bytes: value.total.upload).getReadableMemory()
        self.totalDownloadField?.stringValue = Units(bytes: value.total.download).getReadableMemory()
        
        let form = DateComponentsFormatter()
        form.maximumUnitCount = 2
        form.unitsStyle = .full
        form.allowedUnits = [.day, .hour, .minute]
        
        let duration = value.lastReset.flatMap { form.string(from: $0, to: Date()) }
        let tooltip = duration.map { localizedString("Last reset", $0) }
        self.totalUploadLabel?.toolTip = tooltip
        self.totalDownloadLabel?.toolTip = tooltip
        
        if let interface = value.interface {
            self.interfaceField?.stringValue = "\(interface.displayName) (\(interface.BSDName)"
            if let cc = value.wifiDetails.countryCode {
                self.interfaceField?.stringValue += ", \(cc)"
            }
            self.interfaceField?.stringValue += ")"
            self.interfaceStatusField?.stringValue = interface.status ? localizedString("Up") : localizedString("Down")
            self.macAddressField?.stringValue = interface.address
            self.interfaceSpeedField?.stringValue = "\(Int(interface.transmitRate.rounded()))Mbps"
        } else {
            self.interfaceField?.stringValue = localizedString("Unknown")
            self.interfaceStatusField?.stringValue = ""
            self.macAddressField?.stringValue = localizedString("Unknown")
            self.interfaceSpeedField?.stringValue = localizedString("Unknown")
        }
        
        if value.connectionType == .wifi {
            let accessRequired = value.wifiLocationAuthorization == .notDetermined || value.wifiLocationAuthorization == .denied
            if let view = self.ssidView, view.superview == nil {
                self.interfaceView?.addArrangedSubview(view)
                resized = true
            }
            if self.interfaceDetailsState, let view = self.standardView, view.superview == nil && value.wifiDetails.standard != nil {
                self.interfaceView?.addArrangedSubview(view)
                resized = true
            }
            if self.interfaceDetailsState, let view = self.channelView, view.superview == nil && value.wifiDetails.channel != nil {
                self.interfaceView?.addArrangedSubview(view)
                resized = true
            }
            
            self.ssidField?.stringValue = value.wifiDetails.ssid ?? localizedString("Unknown")
            if let v = value.wifiDetails.RSSI {
                self.ssidField?.stringValue += " (\(v))"
            }
            self.locationPermissionButton?.title = localizedString(value.wifiLocationAuthorization == .notDetermined ? "Allow access to Wi-Fi details" : "Open Location Settings")
            self.locationPermissionButton?.isHidden = !accessRequired
            self.ssidField?.isHidden = accessRequired
            if accessRequired, let button = self.locationPermissionButton, let field = self.ssidField {
                button.sizeToFit()
                button.frame.size.width = min(button.frame.width, field.frame.width)
                button.frame.origin = NSPoint(
                    x: isRTL ? field.frame.minX : field.frame.maxX - button.frame.width,
                    y: ((self.ssidView?.bounds.height ?? 22) - button.frame.height) / 2
                )
            }
            self.standardField?.stringValue = value.wifiDetails.standard ?? localizedString("Unknown")
            self.channelField?.stringValue = value.wifiDetails.channel ?? localizedString("Unknown")
            
            var rssi = localizedString("Unknown")
            if let v = value.wifiDetails.RSSI {
                rssi = "\(v) dBm"
            }
            var noise = localizedString("Unknown")
            if let v = value.wifiDetails.noise {
                noise = "\(v) dBm"
            }
            
            let number = value.wifiDetails.channelNumber ?? localizedString("Unknown")
            let band = value.wifiDetails.channelBand ?? localizedString("Unknown")
            let width = value.wifiDetails.channelWidth ?? localizedString("Unknown")
            self.channelField?.toolTip = "RSSI: \(rssi)\nNoise: \(noise)\nChannel number: \(number)\nChannel band: \(band)\nChannel width: \(width)\n"
        } else {
            if self.ssidView?.superview != nil {
                self.ssidField?.stringValue = localizedString("Unavailable")
                self.ssidView?.removeFromSuperview()
                resized = true
            }
            if self.standardField?.superview != nil {
                self.standardField?.stringValue = localizedString("Unavailable")
                self.standardView?.removeFromSuperview()
                resized = true
            }
            if self.channelView?.superview != nil {
                self.channelField?.stringValue = localizedString("Unavailable")
                self.channelView?.removeFromSuperview()
                resized = true
            }
        }
        
        var privateIP = localizedString("Unknown")
        if let v4 = value.laddr.v4, !v4.isEmpty {
            privateIP = v4
        } else if let v6 = value.laddr.v6, !v6.isEmpty {
            privateIP = v6
        }
        if self.localIPField?.stringValue != privateIP {
            self.localIPField?.stringValue = privateIP
        }
        
        if let view = self.publicIPv4View {
            if let addr = value.raddr.v4 {
                if view.superview == nil {
                    self.addressView?.addArrangedSubview(view)
                    resized = true
                }
                var ip = addr
                if let cc = value.raddr.countryCode, !cc.isEmpty {
                    if self.emojiCCState, let flag = countryFlag(cc) {
                        ip += " \(flag)"
                    } else {
                        ip += " (\(cc))"
                    }
                    self.publicIPv4Field?.toolTip = cc
                }
                if self.publicIPv4Field?.stringValue != ip {
                    self.publicIPv4Field?.stringValue = ip
                }
            } else if view.superview != nil {
                view.removeFromSuperview()
                resized = true
                self.publicIPv4Field?.stringValue = localizedString("Unknown")
            }
        }
        
        if let view = self.publicIPv6View {
            if let addr = value.raddr.v6 {
                if view.superview == nil {
                    self.addressView?.addArrangedSubview(view)
                    resized = true
                }
                var ip = addr
                if let cc = value.raddr.countryCode {
                    if self.emojiCCState, let flag = countryFlag(cc) {
                        ip += " \(flag)"
                    } else {
                        ip += " (\(cc))"
                    }
                    self.publicIPv6Field?.toolTip = cc
                }
                if self.publicIPv6Field?.stringValue != ip {
                    self.publicIPv6Field?.stringValue = ip
                }
            } else if view.superview != nil {
                view.removeFromSuperview()
                resized = true
                self.publicIPv6Field?.stringValue = localizedString("Unknown")
            }
        }
        
        if self.interfaceDetailsState {
            if !value.dns.isEmpty {
                let servers = value.dns.joined(separator: "\n")
                
                if self.dnsServersField == nil || value.dns.count != self.dnsServersField?.stringValue.split(separator: "\n").count {
                    if let view = self.dnsServersView {
                        view.removeFromSuperview()
                    }
                    let view = popupRow(self.interfaceView, title: "\(localizedString("DNS Server")):", value: servers, multiline: true)
                    self.dnsServersField = view.1
                    self.dnsServersView = view.2
                    self.dnsServersField?.isSelectable = true
                }
                
                if self.dnsServersField?.stringValue != servers {
                    self.dnsServersField?.stringValue = servers
                }
                
                resized = true
            } else if let view = self.dnsServersView {
                view.removeFromSuperview()
                resized = true
            }
        }
        
        if resized {
            self.resizeToFitContent()
        }
        
        self.chart?.display()
    }
    
    public func connectivityCallback(_ value: Network_Connectivity?) {
        let date = Date()
        if self.latency.count >= 90 {
            self.latency.remove(at: 0)
        }
        self.latency.append(value?.latency ?? 0)
        
        if self.jitter.count >= 90 {
            self.jitter.remove(at: 0)
        }
        self.jitter.append(value?.jitter ?? 0)
        
        self.apply(value, to: self.connectivityCache, render: self.renderConnectivity)
        
        DispatchQueue.main.async {
            if let value {
                let sample = (status: value.status, date: date)
                self.connectivityHistory.append(sample.status, at: sample.date)
                self.connectivityChart?.historyUpdated()
            }
        }
    }
    
    private func renderConnectivity(_ value: Network_Connectivity?) {
        var status = localizedString("Unknown")
        var latency = localizedString("Unknown")
        var jitter = localizedString("Unknown")
        
        if let v = value {
            if v.status && !self.latency.isEmpty {
                latency = "\((self.latency.reduce(0, +) / Double(self.latency.count)).rounded(toPlaces: 2)) ms"
            }
            if v.status && !self.jitter.isEmpty {
                jitter = "\((self.jitter.reduce(0, +) / Double(self.jitter.count)).rounded(toPlaces: 2)) ms"
            }
            status = v.status ? localizedString("Online") : localizedString("Offline")
        }
        
        self.internetStatusField?.stringValue = status
        self.latencyField?.stringValue = latency
        self.jitterField?.stringValue = jitter
        
        self.connectivityChart?.display()
    }
    
    public func processCallback(_ list: [Network_Process]) {
        self.apply(list, to: self.processesCache, render: self.renderProcesses)
    }
    
    private func renderProcesses(_ list: [Network_Process]) {
        if list.count != self.processes?.count { self.processes?.clear() }
        
        for i in 0..<list.count {
            let process = list[i]
            let upload = Units(bytes: Int64(process.upload)).getReadableSpeed(base: self.base, unit: self.speedUnit)
            let download = Units(bytes: Int64(process.download)).getReadableSpeed(base: self.base, unit: self.speedUnit)
            self.processes?.set(i, process, [download, upload])
        }
    }
    
    public func resetConnectivityView() {
        self.internetStatusField?.stringValue = "n/a"
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Keyboard shortcut"), component: KeyboardShartcutView(
                callback: self.setKeyboardShortcut,
                value: self.keyboardShortcut
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Color of download"), component: self.colorSelectView(
                action: #selector(self.toggleDownloadColor),
                items: SColor.allColors,
                selected: self.downloadColorState.key
            )),
            PreferencesRow(localizedString("Color of upload"), component: self.colorSelectView(
                action: #selector(self.toggleUploadColor),
                items: SColor.allColors,
                selected: self.uploadColorState.key
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Reverse order"), component: self.switchView(
                action: #selector(self.toggleReverseOrder),
                state: self.reverseOrderState
            ))
        ]))
        
        self.chartPrefSection = PreferencesSection([
            PreferencesRow(localizedString("Chart history"), component: self.selectView(
                action: #selector(self.togglechartHistory),
                items: LineChartHistory,
                selected: "\(self.chartHistory)"
            )),
            PreferencesRow(localizedString("Main chart scaling"), component: self.selectView(
                action: #selector(self.toggleChartScale),
                items: Scale.allCases,
                selected: self.chartScale.key
            )),
            PreferencesRow(localizedString("Scale value"), component: StepperInput(
                self.chartFixedScale, range: NSRange(location: 1, length: 1023),
                unit: self.chartFixedScaleSize.key, units: SizeUnit.allCases,
                callback: self.toggleFixedScale, unitCallback: self.toggleFixedScaleSize
            ))
        ])
        view.addArrangedSubview(self.chartPrefSection!)
        self.chartPrefSection?.setRowVisibility(2, newState: self.chartScale == .fixed)
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Public IP"), component: self.switchView(
                action: #selector(self.togglePublicIP),
                state: self.publicIPState
            )),
            PreferencesRow(localizedString("Show country code instead of emoji"), component: self.switchView(
                action: #selector(self.toggleEmojiCC),
                state: !self.emojiCCState
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleUploadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.uploadColorState = SColor.fromString(key, defaultValue: self.uploadColorState)
        Store.shared.set(key: "\(self.title)_uploadColor", value: self.uploadColorState.key)
        self.uploadRow?.setColor(self.uploadColor)
        if let color = self.uploadColorState.additional as? NSColor {
            self.processes?.setColor(1, color)
            self.uploadColorView?.layer?.backgroundColor = color.cgColor
            self.chart?.setColors(out: color)
        }
    }
    @objc private func toggleDownloadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.downloadColorState = SColor.fromString(key, defaultValue: self.downloadColorState)
        Store.shared.set(key: "\(self.title)_downloadColor", value: self.downloadColorState.key)
        self.downloadRow?.setColor(self.downloadColor)
        if let color = self.downloadColorState.additional as? NSColor {
            self.processes?.setColor(0, color)
            self.downloadColorView?.layer?.backgroundColor = color.cgColor
            self.chart?.setColors(in: color)
        }
    }
    @objc private func toggleReverseOrder(_ sender: NSControl) {
        self.reverseOrderState = controlState(sender)
        self.chart?.setReverseOrder(self.reverseOrderState)
        Store.shared.set(key: "\(self.title)_reverseOrder", value: self.reverseOrderState)
        self.display()
    }
    @objc private func togglechartHistory(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.chartHistory = value
        self.bandwidthHistory.resize(value)
        Store.shared.set(key: "\(self.title)_chartHistory", value: value)
        self.chart?.reinit(self.chartHistory)
    }
    @objc private func toggleChartScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.chartScale = value
        self.chart?.setScale(self.chartScale, Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale)))
        self.chartPrefSection?.setRowVisibility(2, newState: self.chartScale == .fixed)
        Store.shared.set(key: "\(self.title)_chartScale", value: key)
        self.display()
    }
    @objc private func togglePublicIP(_ sender: NSControl) {
        self.publicIPState = controlState(sender)
        Store.shared.set(key: "\(self.title)_publicIP", value: self.publicIPState)
        
        DispatchQueue.main.async(execute: {
            if !self.publicIPState {
                self.addressView?.removeFromSuperview()
            } else if let view = self.addressView {
                self.insertArrangedSubview(view, at: 4)
            }
            self.resizeToFitContent()
        })
    }
    @objc private func toggleFixedScale(_ newValue: Int) {
        self.chart?.setScale(self.chartScale, Double(self.chartFixedScaleSize.toBytes(newValue)))
        Store.shared.set(key: "\(self.title)_chartFixedScale", value: newValue)
    }
    private func toggleFixedScaleSize(_ newValue: KeyValue_p) {
        guard let newUnit = newValue as? SizeUnit else { return }
        self.chartFixedScaleSize = newUnit
        Store.shared.set(key: "\(self.title)_chartFixedScaleSize", value: self.chartFixedScaleSize.key)
        self.display()
    }
    @objc private func toggleInterfaceDetails() {
        self.interfaceDetailsState = !self.interfaceDetailsState
        Store.shared.set(key: "\(self.title)_interfaceDetails", value: self.interfaceDetailsState)
        
        if !self.interfaceDetailsState {
            self.standardView?.removeFromSuperview()
            self.channelView?.removeFromSuperview()
            self.interfaceSpeedView?.removeFromSuperview()
            self.dnsServersView?.removeFromSuperview()
        } else {
            if let view = self.standardView, view.superview == nil && self.standardField?.stringValue != localizedString("Unavailable") {
                self.interfaceView?.addArrangedSubview(view)
            }
            if let view = self.channelView, view.superview == nil && self.channelField?.stringValue != localizedString("Unavailable") {
                self.interfaceView?.addArrangedSubview(view)
            }
            if let view = self.interfaceSpeedView, view.superview == nil {
                self.interfaceView?.addArrangedSubview(view)
            }
            if let view = self.dnsServersView, view.superview == nil {
                self.interfaceView?.addArrangedSubview(view)
            }
        }
        
        self.resizeToFitContent()
    }
    @objc private func toggleEmojiCC(_ sender: NSControl) {
        self.emojiCCState = !controlState(sender)
        Store.shared.set(key: "\(self.title)_emojiCC", value: self.emojiCCState)
    }
    
    // MARK: - helpers
    
    private func setUploadDownloadFields() {
        let upload = Units(bytes: self.uploadValue).getReadableTuple(base: self.base, unit: self.speedUnit)
        let download = Units(bytes: self.downloadValue).getReadableTuple(base: self.base, unit: self.speedUnit)
        
        self.uploadRow?.setSpeed(upload.0, unit: upload.1)
        self.downloadRow?.setSpeed(download.0, unit: download.1)
    }
    
    @objc private func refreshPublicIP() {
        NotificationCenter.default.post(name: .refreshPublicIP, object: nil, userInfo: nil)
        self.localIPField?.stringValue = localizedString("Updating...")
        self.publicIPv4Field?.stringValue = localizedString("Updating...")
        self.publicIPv6Field?.stringValue = localizedString("Updating...")
    }
    
    @objc private func resetTotalNetworkUsage() {
        NotificationCenter.default.post(name: .resetTotalNetworkUsage, object: nil, userInfo: nil)
        self.totalUploadField?.stringValue = Units(bytes: 0).getReadableMemory()
        self.totalDownloadField?.stringValue = Units(bytes: 0).getReadableMemory()
    }
}

private class BandwidthRow: NSView {
    private let iconTile = NSView()
    private let iconView = NSImageView()
    private let valueView = NSTextField(labelWithString: "")
    private let unitView = NSTextField(labelWithString: "")
    private let title: String
    
    public init(icon: String, title: String, color: NSColor) {
        self.title = title
        super.init(frame: .zero)
        
        self.iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        self.iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        self.iconTile.wantsLayer = true
        self.iconTile.layer?.cornerRadius = Constants.Popup.radius
        self.iconTile.addSubview(self.iconView)
        
        self.valueView.font = .monospacedDigitSystemFont(ofSize: 21, weight: .bold)
        self.valueView.alignment = .left
        self.valueView.lineBreakMode = .byTruncatingTail
        self.valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.unitView.font = .systemFont(ofSize: 12, weight: .semibold)
        self.unitView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        
        self.iconView.translatesAutoresizingMaskIntoConstraints = false
        [self.iconTile, self.valueView, self.unitView, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            self.iconTile.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.iconTile.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.iconTile.widthAnchor.constraint(equalToConstant: 28),
            self.iconTile.heightAnchor.constraint(equalToConstant: 28),
            self.iconView.centerXAnchor.constraint(equalTo: self.iconTile.centerXAnchor),
            self.iconView.centerYAnchor.constraint(equalTo: self.iconTile.centerYAnchor),
            self.valueView.leadingAnchor.constraint(equalTo: self.iconTile.trailingAnchor, constant: Constants.Popup.margins),
            self.valueView.topAnchor.constraint(equalTo: self.topAnchor),
            self.unitView.leadingAnchor.constraint(equalTo: self.valueView.trailingAnchor, constant: Constants.Popup.spacing*2),
            self.unitView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor),
            self.unitView.firstBaselineAnchor.constraint(equalTo: self.valueView.firstBaselineAnchor),
            label.leadingAnchor.constraint(equalTo: self.valueView.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor),
            label.topAnchor.constraint(equalTo: self.valueView.bottomAnchor),
            label.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        self.setColor(color)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setSpeed(_ value: String, unit: String) {
        self.valueView.stringValue = value
        self.unitView.stringValue = unit
        self.toolTip = "\(self.title): \(value) \(unit)"
    }
    
    public func setColor(_ color: NSColor) {
        self.iconView.contentTintColor = color
        self.iconTile.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
        self.valueView.textColor = color
        self.unitView.textColor = color
    }
}
