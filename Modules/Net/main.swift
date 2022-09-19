//
//  main.swift
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
import SystemConfiguration

public enum Network_t: String {
    case wifi
    case ethernet
    case bluetooth
    case other
}

public struct Network_interface {
    var displayName: String = ""
    var BSDName: String = ""
    var address: String = ""
}

public struct Network_addr {
    var v4: String? = nil
    var v6: String? = nil
}

public struct Network_wifi {
    var countryCode: String? = nil
    var ssid: String? = nil
    var RSSI: Int? = nil
    var noise: Int? = nil
    var transmitRate: Double? = nil
    var transmitPower: Int? = nil
    
    var standard: String? = nil
    var mode: String? = nil
    var security: String? = nil
    var channel: String? = nil
    
    var channelBand: String? = nil
    var channelWidth: String? = nil
    var channelNumber: String? = nil
    
    mutating func reset() {
        self.countryCode = nil
        self.ssid = nil
        self.RSSI = nil
        self.noise = nil
        self.transmitRate = nil
        self.transmitPower = nil
        self.standard = nil
        self.mode = nil
        self.security = nil
        self.channel = nil
    }
}

public struct Network_Usage: value_t {
    var bandwidth: Bandwidth = (0, 0)
    var total: Bandwidth = (0, 0)
    
    var laddr: String? = nil // local ip
    var raddr: Network_addr = Network_addr() // remote ip
    
    var interface: Network_interface? = nil
    var connectionType: Network_t? = nil
    var status: Bool = false
    
    var wifiDetails: Network_wifi = Network_wifi()
    
    mutating func reset() {
        self.bandwidth = (0, 0)
        
        self.laddr = nil
        self.raddr = Network_addr()
        
        self.interface = nil
        self.connectionType = nil
        
        self.wifiDetails.reset()
    }
    
    public var widgetValue: Double = 0
}

public struct Network_Process {
    var time: Date = Date()
    var name: String = ""
    var pid: String = ""
    var download: Int = 0
    var upload: Int = 0
    var icon: NSImage? = nil
}

public class Network: Module {
    private var popupView: Popup
    private var settingsView: Settings
    
    private var usageReader: UsageReader? = nil
    private var processReader: ProcessReader? = nil
    private var connectivityReader: ConnectivityReader? = nil
    
    private let ipUpdater = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.Network.IP")
    private let usageReseter = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.Network.Usage")
    
    private var widgetActivationThreshold: Int {
        get {
            return Store.shared.int(key: "\(self.config.name)_widgetActivationThreshold", defaultValue: 0)
        }
    }
    
    public init() {
        self.settingsView = Settings("Network")
        self.popupView = Popup("Network")
        
        super.init(
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
        
        self.usageReader = UsageReader()
        self.processReader = ProcessReader()
        self.connectivityReader = ConnectivityReader()
        
        self.settingsView.callbackWhenUpdateNumberOfProcesses = {
            self.popupView.numberOfProcessesUpdated()
            DispatchQueue.global(qos: .background).async {
                self.processReader?.read()
            }
        }
        
        self.usageReader?.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        self.usageReader?.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.processReader?.callbackHandler = { [unowned self] value in
            if let list = value {
                self.popupView.processCallback(list)
            }
        }
        
        self.connectivityReader?.callbackHandler = { [unowned self] value in
            self.connectivityCallback(value)
        }
        
        self.settingsView.callback = { [unowned self] in
            self.usageReader?.getDetails()
            self.usageReader?.read()
        }
        self.settingsView.usageResetCallback = { [unowned self] in
            self.setUsageReset()
        }
        
        if let reader = self.usageReader {
            self.addReader(reader)
        }
        if let reader = self.processReader {
            self.addReader(reader)
        }
        if let reader = self.connectivityReader {
            self.addReader(reader)
        }
        
        self.setIPUpdater()
        self.setUsageReset()
    }
    
    public override func isAvailable() -> Bool {
        var list: [String] = []
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                list.append(displayName as String)
            }
        }
        return !list.isEmpty
    }
    
    private func usageCallback(_ raw: Network_Usage?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        self.popupView.usageCallback(value)
        
        var upload = value.bandwidth.upload
        var download = value.bandwidth.download
        let activationValue = Units(bytes: min(upload, download)).kilobytes
        
        if Double(self.widgetActivationThreshold) > activationValue {
            upload = 0
            download = 0
        }
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SpeedWidget: widget.setValue(upload: upload, download: download)
            case let widget as NetworkChart: widget.setValue(upload: Double(upload), download: Double(download))
            default: break
            }
        }
    }
    
    private func connectivityCallback(_ raw: Bool?) {
        guard let value = raw, self.enabled else { return }
        
        self.popupView.connectivityCallback(value)
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as StateWidget: widget.setValue(value)
            default: break
            }
        }
    }
    
    private func setIPUpdater() {
        self.ipUpdater.interval = 60 * 60
        self.ipUpdater.repeats = true
        self.ipUpdater.schedule { (completion: @escaping NSBackgroundActivityScheduler.CompletionHandler) in
            guard self.enabled && self.isAvailable() else {
                return
            }
            
            debug("going to automatically refresh IP address...")
            NotificationCenter.default.post(name: .refreshPublicIP, object: nil, userInfo: nil)
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
    }
    
    private func setUsageReset() {
        self.usageReseter.invalidate()
        
        switch AppUpdateInterval(rawValue: Store.shared.string(key: "\(self.config.name)_usageReset", defaultValue: AppUpdateInterval.atStart.rawValue)) {
        case .oncePerDay: self.usageReseter.interval = 60 * 60 * 24
        case .oncePerWeek: self.usageReseter.interval = 60 * 60 * 24 * 7
        case .oncePerMonth: self.usageReseter.interval = 60 * 60 * 24 * 30
        case .never, .atStart: return
        default: return
        }
        
        self.usageReseter.repeats = true
        self.usageReseter.schedule { (completion: @escaping NSBackgroundActivityScheduler.CompletionHandler) in
            guard self.enabled && self.isAvailable() else {
                return
            }
            
            debug("going to reset the usage...")
            NotificationCenter.default.post(name: .resetTotalNetworkUsage, object: nil, userInfo: nil)
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
    }
}
