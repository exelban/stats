//
//  settings.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 06/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit
import SystemConfiguration

internal class Settings: NSStackView, Settings_v, NSTextFieldDelegate {
    private var numberOfProcesses: Int = 8
    private var readerType: String = "interface"
    private var usageReset: String = AppUpdateInterval.atStart.rawValue
    private var VPNModeState: Bool = false
    private var widgetActivationThreshold: Int = 0
    private var ICMPHost: String = "1.1.1.1"
    private var publicIPRefreshInterval: String = "never"
    private var baseValue: String = "byte"
    
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    public var usageResetCallback: (() -> Void) = {}
    public var ICMPHostCallback: ((_ newState: Bool) -> Void) = { _ in }
    public var publicIPRefreshIntervalCallback: (() -> Void) = {}
    
    private let title: String
    private var button: NSPopUpButton?
    private var valueField: NSTextField?
    
    private var list: [Network_interface] = []
    
    private var vpnConnection: Bool {
        if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any], let scopes = settings["__SCOPED__"] as? [String: Any] {
            return !scopes.filter({ $0.key.contains("tap") || $0.key.contains("tun") || $0.key.contains("ppp") || $0.key.contains("ipsec") || $0.key.contains("ipsec0")}).isEmpty
        }
        return false
    }
    
    public init(_ title: String) {
        self.title = title
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.readerType = Store.shared.string(key: "\(self.title)_reader", defaultValue: self.readerType)
        self.usageReset = Store.shared.string(key: "\(self.title)_usageReset", defaultValue: self.usageReset)
        self.VPNModeState = Store.shared.bool(key: "\(self.title)_VPNMode", defaultValue: self.VPNModeState)
        self.widgetActivationThreshold = Store.shared.int(key: "\(self.title)_widgetActivationThreshold", defaultValue: self.widgetActivationThreshold)
        self.ICMPHost = Store.shared.string(key: "\(self.title)_ICMPHost", defaultValue: self.ICMPHost)
        self.publicIPRefreshInterval = Store.shared.string(key: "\(self.title)_publicIPRefreshInterval", defaultValue: self.publicIPRefreshInterval)
        self.baseValue = Store.shared.string(key: "\(self.title)_base", defaultValue: self.baseValue)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if  let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
                let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                self.list.append(Network_interface(displayName: displayName as String, BSDName: bsdName as String))
            }
        }
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        self.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Base"),
            action: #selector(toggleBase),
            items: SpeedBase,
            selected: self.baseValue
        ))
        
        self.addArrangedSubview(self.activationSlider())
        
        self.addArrangedSubview(selectSettingsRowV1(
            title: localizedString("Number of top processes"),
            action: #selector(changeNumberOfProcesses),
            items: NumbersOfProcesses.map{ "\($0)" },
            selected: "\(self.numberOfProcesses)"
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Reset data usage"),
            action: #selector(toggleUsageReset),
            items: AppUpdateIntervals.dropLast(2).filter({ $0.key != "Silent" }),
            selected: self.usageReset
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Reader type"),
            action: #selector(changeReaderType),
            items: NetworkReaders,
            selected: self.readerType
        ))
        
        self.addArrangedSubview(selectSettingsRow(
            title: localizedString("Auto-refresh public IP address"),
            action: #selector(toggleRefreshIPInterval),
            items: PublicIPAddressRefreshIntervals,
            selected: self.publicIPRefreshInterval
        ))
        
        self.addArrangedSubview(self.interfaceSelector())
        
        if self.vpnConnection {
            self.addArrangedSubview(toggleSettingRow(
                title: localizedString("VPN mode"),
                action: #selector(toggleVPNMode),
                state: self.VPNModeState
            ))
        }
        
        self.addArrangedSubview(fieldSettingRow(self,
            title: localizedString("Connectivity host (ICMP)"),
            value: self.ICMPHost,
            placeholder: localizedString("Leave empty to disable the check"),
            width: 220
        ))
        
    }
    
    private func interfaceSelector() -> NSView {
        let view = NSStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: Constants.Settings.row).isActive = true
        view.orientation = .horizontal
        view.alignment = .centerY
        view.distribution = .fill
        view.spacing = 0
        
        let titleField: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0), localizedString("Network interface"))
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        titleField.textColor = .textColor
        
        let select: NSPopUpButton = NSPopUpButton()
        select.target = self
        select.action = #selector(self.handleSelection)
        select.isEnabled = self.readerType == "interface"
        self.button = select
        
        let selectedInterface = Store.shared.string(key: "\(self.title)_interface", defaultValue: "")
        let menu = NSMenu()
        let autodetection = NSMenuItem(title: localizedString("Autodetection"), action: nil, keyEquivalent: "")
        autodetection.identifier = NSUserInterfaceItemIdentifier(rawValue: "autodetection")
        autodetection.tag = 128
        menu.addItem(autodetection)
        menu.addItem(NSMenuItem.separator())
        
        self.list.forEach { (interface: Network_interface) in
            let interfaceMenu = NSMenuItem(title: "\(interface.displayName) (\(interface.BSDName))", action: nil, keyEquivalent: "")
            interfaceMenu.identifier = NSUserInterfaceItemIdentifier(rawValue: interface.BSDName)
            menu.addItem(interfaceMenu)
            if selectedInterface != "" && selectedInterface == interface.BSDName {
                interfaceMenu.state = .on
            }
        }
        
        select.menu = menu
        select.sizeToFit()
        
        if selectedInterface == "" {
            select.selectItem(withTag: 128)
        }
        
        view.addArrangedSubview(titleField)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(select)
        
        return view
    }
    
    func activationSlider() -> NSView {
        let view: NSStackView = NSStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: Constants.Settings.row * 1.5).isActive = true
        view.orientation = .horizontal
        view.alignment = .centerY
        view.distribution = .fill
        view.spacing = 0
        
        let titleField: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0), localizedString("Widget activation threshold"))
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        titleField.textColor = .textColor
        
        let container = NSStackView()
        container.spacing = 0
        container.orientation = .vertical
        container.alignment = .centerX
        container.distribution = .fillEqually
        
        var value = localizedString("Disabled")
        if self.widgetActivationThreshold != 0 {
            value = "\(self.widgetActivationThreshold) KB"
        }
        
        let valueField: NSTextField = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0), value)
        valueField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        valueField.textColor = .textColor
        self.valueField = valueField
        
        let slider = NSSlider()
        slider.minValue = 0
        slider.maxValue = 1024
        slider.doubleValue = Double(self.widgetActivationThreshold)
        slider.target = self
        slider.isContinuous = true
        slider.action = #selector(self.sliderCallback)
        slider.sizeToFit()
        
        container.addArrangedSubview(valueField)
        container.addArrangedSubview(slider)
        
        view.addArrangedSubview(titleField)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(container)
        
        container.widthAnchor.constraint(equalToConstant: 180).isActive = true
        container.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        
        return view
    }
    
    @objc func handleSelection(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem, let id = item.identifier?.rawValue else { return }
        
        if id == "autodetection" {
            Store.shared.remove("\(self.title)_interface")
        } else {
            if let bsdName = item.identifier?.rawValue {
                Store.shared.set(key: "\(self.title)_interface", value: bsdName)
            }
        }
        
        self.callback()
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    
    @objc private func changeReaderType(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.readerType = key
        Store.shared.set(key: "\(self.title)_reader", value: key)
        self.button?.isEnabled = self.readerType == "interface"
        
        NotificationCenter.default.post(name: .resetTotalNetworkUsage, object: nil, userInfo: nil)
    }
    
    @objc private func toggleUsageReset(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.usageReset = key
        Store.shared.set(key: "\(self.title)_usageReset", value: key)
        self.usageResetCallback()
    }
    
    @objc func toggleVPNMode(_ sender: NSControl) {
        self.VPNModeState = controlState(sender)
        Store.shared.set(key: "\(self.title)_VPNMode", value: self.VPNModeState)
    }
    
    @objc private func sliderCallback(_ sender: NSSlider) {
        guard let valueField = self.valueField else { return }
        
        let value = Int(sender.doubleValue)
        if value == 0 {
            valueField.stringValue = localizedString("Disabled")
        } else {
            valueField.stringValue = "\(value) KB"
        }
        self.widgetActivationThreshold = value
        Store.shared.set(key: "\(self.title)_widgetActivationThreshold", value: self.widgetActivationThreshold)
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            self.ICMPHost = textField.stringValue
            Store.shared.set(key: "\(self.title)_ICMPHost", value: self.ICMPHost)
            self.ICMPHostCallback(self.ICMPHost.isEmpty)
        }
    }
    
    @objc private func toggleRefreshIPInterval(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.publicIPRefreshInterval = key
        Store.shared.set(key: "\(self.title)_publicIPRefreshInterval", value: self.publicIPRefreshInterval)
        self.publicIPRefreshIntervalCallback()
    }
    
    @objc private func toggleBase(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.baseValue = key
        Store.shared.set(key: "\(self.title)_base", value: self.baseValue)
    }
}
