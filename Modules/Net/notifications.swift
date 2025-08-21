//
//  notifications.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 25/01/2025
//  Using Swift 6.0
//  Running on macOS 15.1
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//  

import Cocoa
import Kit

class Notifications: NotificationsWrapper {
    private let connectionID: String = "connection"
    private let connectionThresholdID: String = "connection_threshold"
    private let interfaceID: String = "interface"
    private let localID: String = "localIP"
    private let publicID: String = "publicIP"
    private let wifiID: String = "wifi"
    
    private var connectionState: Bool = false
    private var connectionThreshold: Int = 2
    private var interfaceState: Bool = false
    private var localIPState: Bool = false
    private var publicIPState: Bool = false
    private var wifiState: Bool = false
    
    private var connection: Bool?
    private var connectionCount: Int = 0
    private var connectionPrev: Bool?
    private var interface: String?
    private var localIP: String?
    private var publicIP: String?
    private var wifi: String?
    
    private var connectionInit: Bool = false
    private var interfaceInit: Bool = false
    private var localIPInit: Bool = false
    private var publicIPInit: Bool = false
    private var wifiInit: Bool = false
    
    public init(_ module: ModuleType) {
        super.init(module, [self.connectionID, self.interfaceID, self.localID, self.publicID, self.wifiID])
        
        self.connectionState = Store.shared.bool(key: "\(self.module)_notifications_connection_state", defaultValue: self.connectionState)
        self.connectionThreshold = Store.shared.int(key: "\(self.module)_notifications_connection_threshold", defaultValue: self.connectionThreshold)
        self.interfaceState = Store.shared.bool(key: "\(self.module)_notifications_interface_state", defaultValue: self.interfaceState)
        self.localIPState = Store.shared.bool(key: "\(self.module)_notifications_localIP_state", defaultValue: self.localIPState)
        self.publicIPState = Store.shared.bool(key: "\(self.module)_notifications_publicIP_state", defaultValue: self.publicIPState)
        self.wifiState = Store.shared.bool(key: "\(self.module)_notifications_wifi_state", defaultValue: self.wifiState)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Status"), component: PreferencesSwitch(
                action: self.toggleConnectionState, state: self.connectionState, with: StepperInput(
                    self.connectionThreshold, range: NSRange(location: 1, length: 9), visibileUnit: false,
                    callback: self.changeWidgetConnectionThreshold
                )
            )),
            PreferencesRow(localizedString("Network interface"), component: switchView(
                action: #selector(self.toggleInterfaceState),
                state: self.interfaceState
            )),
            PreferencesRow(localizedString("Local IP"), component: switchView(
                action: #selector(self.toggleLocalIPState),
                state: self.localIPState
            )),
            PreferencesRow(localizedString("Public IP"), component: switchView(
                action: #selector(self.toggleNPublicIPState),
                state: self.publicIPState
            )),
            PreferencesRow(localizedString("WiFi network"), component: switchView(
                action: #selector(self.toggleWiFiState),
                state: self.wifiState
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: Network_Usage) {
        if !self.interfaceInit {
            self.interface = value.interface?.BSDName
            self.interfaceInit = true
        }
        if !self.localIPInit {
            if let v4 = value.laddr.v4 {
                self.localIP = v4
                self.localIPInit = true
            } else if let v6 = value.laddr.v6 {
                self.localIP = v6
                self.localIPInit = true
            }
        }
        if !self.publicIPInit {
            if let v4 = value.raddr.v4 {
                self.publicIP = v4
                self.publicIPInit = true
            } else if let v6 = value.raddr.v6 {
                self.publicIP = v6
                self.publicIPInit = true
            }
        }
        if !self.wifiInit {
            self.wifi = value.wifiDetails.ssid
            self.wifiInit = true
        }
        
        if self.interfaceState {
            if value.interface?.BSDName != self.interface {
                self.newNotification(id: self.interfaceID, title: localizedString("Network interface changed"), subtitle: nil)
            }
            self.interface = value.interface?.BSDName
        }
        
        if self.localIPState {
            let addr = value.laddr.v4 ?? value.laddr.v6
            if addr != self.localIP {
                self.newNotification(id: self.localID, title: localizedString("Local IP changed"), subtitle: nil)
            }
            self.localIP = addr
        }
        
        if self.publicIPState {
            let addr = value.raddr.v4 ?? value.raddr.v6
            if addr != self.publicIP {
                self.newNotification(id: self.publicID, title: localizedString("Public IP changed"), subtitle: nil)
            }
            self.publicIP = addr
        }
        
        if self.wifiState {
            if value.wifiDetails.ssid != self.wifi {
                self.newNotification(id: self.wifiID, title: localizedString("WiFi network changed"), subtitle: nil)
            }
            self.wifi = value.wifiDetails.ssid
        }
    }
    
    internal func connectivityCallback(_ value: Network_Connectivity) {
        guard self.connectionState else { return }
        
        if self.connection == nil {
            self.connection = value.status
            return
        }
        
        if self.connection != value.status {
            self.connectionCount += 1
        } else {
            self.connectionCount = 0
        }
        
        if self.connectionCount >= self.connectionThreshold {
            let title: String = value.status ? localizedString("Internet connection established") : localizedString("Internet connection lost")
            self.newNotification(id: self.connectionID, title: title, subtitle: nil)
            self.connection = value.status
            self.connectionCount = 0
        }
    }
    
    @objc private func toggleConnectionState(_ sender: NSControl) {
        self.connectionState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_connection_state", value: self.connectionState)
    }
    @objc private func changeWidgetConnectionThreshold(_ newValue: Int) {
        self.connectionThreshold = newValue
        Store.shared.set(key: "\(self.module)_notifications_connection_threshold", value: newValue)
    }
    @objc private func toggleInterfaceState(_ sender: NSControl) {
        self.interfaceState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_interface_state", value: self.interfaceState)
    }
    @objc private func toggleLocalIPState(_ sender: NSControl) {
        self.localIPState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_localIP_state", value: self.localIPState)
    }
    @objc private func toggleNPublicIPState(_ sender: NSControl) {
        self.publicIPState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_publicIP_state", value: self.publicIPState)
    }
    @objc private func toggleWiFiState(_ sender: NSControl) {
        self.wifiState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_wifi_state", value: self.wifiState)
    }
}
