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

public struct Network_Usage: value_t {
    var bandwidth: Bandwidth = (0, 0)
    var total: Bandwidth = (0, 0)
    
    var laddr: String? = nil // local ip
    var raddr: Network_addr = Network_addr() // remote ip
    
    var interface: Network_interface? = nil
    var connectionType: Network_t? = nil
    var status: Bool = false
    
    var countryCode: String? = nil
    var ssid: String? = nil
    
    mutating func reset() {
        self.bandwidth = (0, 0)
        
        self.laddr = nil
        self.raddr = Network_addr()
        
        self.interface = nil
        self.connectionType = nil
        
        self.countryCode = nil
        self.ssid = nil
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
    
    private let ipUpdater = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.Network.IP")
    private let usageReseter = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.Network.Usage")
    
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
        
        self.widgets.filter{ $0.isActive }.forEach { (w: Widget) in
            switch w.item {
            case let widget as SpeedWidget: widget.setValue(upload: value.bandwidth.upload, download: value.bandwidth.download)
            case let widget as NetworkChart: widget.setValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
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
