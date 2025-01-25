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
    private let interfaceID: String = "interface"
    private let localID: String = "localIP"
    private let publicID: String = "publicIP"
    private let wifiID: String = "wifi"
    
    private var connectionState: Bool = false
    private var interfaceState: Bool = false
    private var localIPState: Bool = false
    private var publicIPState: Bool = false
    private var wifiState: Bool = false
    
    private var connection: Bool?
    private var interface: String?
    private var localIP: String?
    private var publicIP: String?
    private var wifi: String?
    
    public init(_ module: ModuleType) {
        super.init(module, [self.connectionID, self.interfaceID, self.localID, self.publicID, self.wifiID])
        
        self.connectionState = Store.shared.bool(key: "\(self.module)_notifications_connection_state", defaultValue: self.connectionState)
        self.interfaceState = Store.shared.bool(key: "\(self.module)_notifications_interface_state", defaultValue: self.interfaceState)
        self.localIPState = Store.shared.bool(key: "\(self.module)_notifications_localIP_state", defaultValue: self.localIPState)
        self.publicIPState = Store.shared.bool(key: "\(self.module)_notifications_publicIP_state", defaultValue: self.publicIPState)
        self.wifiState = Store.shared.bool(key: "\(self.module)_notifications_wifi_state", defaultValue: self.wifiState)
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Status"), component: switchView(
                action: #selector(self.toggleConnectionState),
                state: self.connectionState
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
        if self.interfaceState {
            if value.interface?.BSDName != self.interface {
                self.newNotification(id: self.interfaceID, title: localizedString("Network interface changed"), subtitle: nil)
            }
            self.interface = value.interface?.BSDName
        }
        
        if self.localIPState {
            if value.laddr != self.localIP {
                self.newNotification(id: self.localID, title: localizedString("Local IP changed"), subtitle: nil)
            }
            self.localIP = value.laddr
        }
        
        if self.publicIPState {
            if value.raddr.v4 ?? value.raddr.v6 != self.publicIP {
                self.newNotification(id: self.publicID, title: localizedString("Public IP changed"), subtitle: nil)
            }
            self.publicIP = value.raddr.v4 ?? value.raddr.v6
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
            var title: String
            if value.status {
                title = localizedString("Internet connection established")
            } else {
                title = localizedString("Internet connection lost")
            }
            self.newNotification(id: self.connectionID, title: title, subtitle: nil)
        }
        self.connection = value.status
    }
    
    @objc private func toggleConnectionState(_ sender: NSControl) {
        self.interfaceState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_connection_state", value: self.interfaceState)
    }
    @objc private func toggleInterfaceState(_ sender: NSControl) {
        self.interfaceState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_interface_state", value: self.interfaceState)
    }
    @objc private func toggleLocalIPState(_ sender: NSControl) {
        self.interfaceState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_localIP_state", value: self.interfaceState)
    }
    @objc private func toggleNPublicIPState(_ sender: NSControl) {
        self.interfaceState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_publicIP_state", value: self.interfaceState)
    }
    @objc private func toggleWiFiState(_ sender: NSControl) {
        self.interfaceState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_wifi_state", value: self.interfaceState)
    }
}
