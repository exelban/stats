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
    private var widgetActivationThresholdState: Bool = false
    private var widgetActivationThreshold: Int = 0
    private var widgetActivationThresholdSize: SizeUnit = .MB
    private var ICMPHost: String = "1.1.1.1"
    private var publicIPRefreshInterval: String = "never"
    private var baseValue: String = "byte"
    
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    public var usageResetCallback: (() -> Void) = {}
    public var ICMPHostCallback: ((_ newState: Bool) -> Void) = { _ in }
    public var publicIPRefreshIntervalCallback: (() -> Void) = {}
    
    private let title: String
    private var sliderView: NSView? = nil
    private var section: PreferencesSection? = nil
    private var widgetThresholdSection: PreferencesSection? = nil
    
    private var list: [Network_interface] = []
    
    private var vpnConnection: Bool {
        if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any], let scopes = settings["__SCOPED__"] as? [String: Any] {
            return !scopes.filter({ $0.key.contains("tap") || $0.key.contains("tun") || $0.key.contains("ppp") || $0.key.contains("ipsec") || $0.key.contains("ipsec0")}).isEmpty
        }
        return false
    }
    
    public init(_ module: ModuleType) {
        self.title = module.rawValue
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.readerType = Store.shared.string(key: "\(self.title)_reader", defaultValue: self.readerType)
        self.usageReset = Store.shared.string(key: "\(self.title)_usageReset", defaultValue: self.usageReset)
        self.VPNModeState = Store.shared.bool(key: "\(self.title)_VPNMode", defaultValue: self.VPNModeState)
        self.widgetActivationThresholdState = Store.shared.bool(key: "\(self.title)_widgetActivationThresholdState", defaultValue: self.widgetActivationThresholdState)
        self.widgetActivationThreshold = Store.shared.int(key: "\(self.title)_widgetActivationThreshold", defaultValue: self.widgetActivationThreshold)
        self.widgetActivationThresholdSize = SizeUnit.fromString(Store.shared.string(key: "\(self.title)_widgetActivationThresholdSize", defaultValue: self.widgetActivationThresholdSize.key))
        self.ICMPHost = Store.shared.string(key: "\(self.title)_ICMPHost", defaultValue: self.ICMPHost)
        self.publicIPRefreshInterval = Store.shared.string(key: "\(self.title)_publicIPRefreshInterval", defaultValue: self.publicIPRefreshInterval)
        self.baseValue = Store.shared.string(key: "\(self.title)_base", defaultValue: self.baseValue)
        
        super.init(frame: NSRect.zero)
        self.orientation = .vertical
        self.spacing = Constants.Settings.margin
        
        for interface in SCNetworkInterfaceCopyAll() as NSArray {
            if  let bsdName = SCNetworkInterfaceGetBSDName(interface as! SCNetworkInterface),
                let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface as! SCNetworkInterface) {
                self.list.append(Network_interface(displayName: displayName as String, BSDName: bsdName as String))
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func load(widgets: [widget_t]) {
        self.subviews.forEach{ $0.removeFromSuperview() }
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Number of top processes"), component: selectView(
                action: #selector(self.changeNumberOfProcesses),
                items: NumbersOfProcesses.map{ KeyValue_t(key: "\($0)", value: "\($0)") },
                selected: "\(self.numberOfProcesses)"
            ))
        ]))
        
        let interfaces = selectView(
            action: #selector(self.handleSelection),
            items: [],
            selected: ""
        )
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
        interfaces.menu = menu
        interfaces.sizeToFit()
        if selectedInterface == "" {
            interfaces.selectItem(withTag: 128)
        }
        
        var prefs: [PreferencesRow] = [
            PreferencesRow(localizedString("Reader type"), component: selectView(
                action: #selector(self.changeReaderType),
                items: NetworkReaders,
                selected: self.readerType
            )),
            PreferencesRow(localizedString("Network interface"), component: interfaces),
            PreferencesRow(localizedString("Base"), component: selectView(
                action: #selector(self.toggleBase),
                items: SpeedBase,
                selected: self.baseValue
            )),
            PreferencesRow(localizedString("Reset data usage"), component: selectView(
                action: #selector(self.toggleUsageReset),
                items: AppUpdateIntervals.dropLast(2).filter({ $0.key != "Silent" }),
                selected: self.usageReset
            )),
            PreferencesRow(localizedString("Auto-refresh public IP address"), component: selectView(
                action: #selector(self.toggleRefreshIPInterval),
                items: PublicIPAddressRefreshIntervals,
                selected: self.publicIPRefreshInterval
            ))
        ]
        if self.vpnConnection {
            prefs.append(PreferencesRow(localizedString("VPN mode"), component: switchView(
                action: #selector(self.toggleVPNMode),
                state: self.VPNModeState
            )))
        }
        let section = PreferencesSection(prefs)
        section.toggleVisibility(1, newState: self.readerType == "interface")
        self.addArrangedSubview(section)
        self.section = section
        
        self.widgetThresholdSection = PreferencesSection([
            PreferencesRow(localizedString("Widget activation threshold"), component: PreferencesSwitch(
                action: self.toggleWidgetActivationThreshold, state: self.widgetActivationThresholdState, with: StepperInput(
                    self.widgetActivationThreshold, range: NSRange(location: 1, length: 1023), 
                    unit: self.widgetActivationThresholdSize.key, units: SizeUnit.allCases,
                    callback: self.changeWidgetActivationThreshold, unitCallback: self.toggleWidgetActivationThresholdSize
                )
            ))
        ])
        self.addArrangedSubview(self.widgetThresholdSection!)
        self.widgetThresholdSection?.toggleVisibility(1, newState: self.widgetActivationThresholdState)
        
        let valueField: NSTextField = NSTextField()
        valueField.widthAnchor.constraint(equalToConstant: 250).isActive = true
        valueField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        valueField.textColor = .textColor
        valueField.isEditable = true
        valueField.isSelectable = true
        valueField.usesSingleLineMode = true
        valueField.maximumNumberOfLines = 1
        valueField.focusRingType = .none
        valueField.stringValue = self.ICMPHost
        valueField.delegate = self
        valueField.placeholderString = localizedString("Leave empty to disable the check")
        
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Connectivity host (ICMP)"), component: valueField)
        ]))
    }
    
    @objc private func handleSelection(_ sender: NSPopUpButton) {
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
        self.section?.toggleVisibility(1, newState: self.readerType == "interface")
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
    @objc func toggleWidgetActivationThreshold(_ sender: NSControl) {
        self.widgetActivationThresholdState = controlState(sender)
        Store.shared.set(key: "\(self.title)_widgetActivationThresholdState", value: self.widgetActivationThresholdState)
        self.widgetThresholdSection?.toggleVisibility(1, newState: self.widgetActivationThresholdState)
    }
    @objc private func changeWidgetActivationThreshold(_ newValue: Int) {
        self.widgetActivationThreshold = newValue
        Store.shared.set(key: "\(self.title)_widgetActivationThreshold", value: newValue)
    }
    private func toggleWidgetActivationThresholdSize(_ newValue: KeyValue_p) {
        guard let newUnit = newValue as? SizeUnit else { return }
        self.widgetActivationThresholdSize = newUnit
        Store.shared.set(key: "\(self.title)_widgetActivationThresholdSize", value: self.widgetActivationThresholdSize.key)
        self.display()
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
