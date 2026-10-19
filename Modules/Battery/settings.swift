//
//  settings.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 15/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit
import SystemConfiguration

var textWidgetHelp = """
<h2>Description</h2>
You can use a combination of any of the variables. Values include their units where applicable.
<h3>Examples:</h3>
<ul>
<li>$battery.power</li>
<li>$battery.level - $battery.power ($time.remaining)</li>
<li>$battery.status - $battery.temperature</li>
<li>Adapter: $adapter.power / $adapter.rating</li>
</ul>
<h2>Available variables</h2>
<ul>
<li><b>$battery.level</b>: <small>Battery charge percentage.</small></li>
<li><b>$battery.power</b>: <small>Battery charging or discharging power in watts, shown as a positive value. This is not total system power while connected to an adapter.</small></li>
<li><b>$battery.current</b>: <small>Battery current in milliamps, including its sign.</small></li>
<li><b>$battery.voltage</b>: <small>Battery voltage in volts.</small></li>
<li><b>$battery.temperature</b>: <small>Battery temperature in the selected temperature unit.</small></li>
<li><b>$battery.health</b>: <small>Maximum capacity as a percentage of design capacity.</small></li>
<li><b>$battery.cycles</b>: <small>Battery charge cycle count.</small></li>
<li><b>$battery.source</b>: <small>Current power source.</small></li>
<li><b>$battery.state</b>: <small>Battery health condition, when reported by macOS.</small></li>
<li><b>$battery.status</b>: <small>On battery, charging, fully charged, on hold, or plugged in.</small></li>
<li><b>$capacity.current</b>: <small>Current battery capacity in milliamp-hours.</small></li>
<li><b>$capacity.max</b>: <small>Maximum battery capacity in milliamp-hours.</small></li>
<li><b>$capacity.designed</b>: <small>Design battery capacity in milliamp-hours.</small></li>
<li><b>$adapter.power</b>: <small>Measured adapter input power in watts, including battery charging.</small></li>
<li><b>$adapter.voltage</b>: <small>Adapter voltage in volts.</small></li>
<li><b>$adapter.current</b>: <small>Adapter current in milliamps, calculated from measured power and voltage.</small></li>
<li><b>$adapter.rating</b>: <small>Reported adapter power rating in watts, not measured consumption.</small></li>
<li><b>$charging.current</b>: <small>Charging current reported by the charger in milliamps.</small></li>
<li><b>$charging.voltage</b>: <small>Charging voltage reported by the charger in volts.</small></li>
<li><b>$time.remaining</b>: <small>Time to discharge or charge, depending on the power source. Shows fully charged or on hold when applicable.</small></li>
<li><b>$time.empty</b>: <small>Estimated time until the battery is empty.</small></li>
<li><b>$time.charge</b>: <small>Estimated time until the battery is fully charged.</small></li>
<li><b>$ups.name</b>: <small>Connected UPS name.</small></li>
<li><b>$ups.level</b>: <small>UPS charge percentage.</small></li>
<li><b>$ups.source</b>: <small>UPS power source.</small></li>
<li><b>$ups.status</b>: <small>UPS charging or power status.</small></li>
</ul>
Temperature, health condition, and UPS details show Unavailable when missing.
Power, current, and voltage readings depend on hardware support and may show zero when unavailable.
Time estimates show Calculating or Unknown when not available.
"""

internal class Settings: NSStackView, Settings_v, NSTextFieldDelegate {
    public var callback: (() -> Void) = {}
    public var callbackWhenUpdateNumberOfProcesses: (() -> Void) = {}
    
    private let title: String
    
    private var numberOfProcesses: Int = 8
    private var timeFormat: String = "short"
    private var textValue: String = "$battery.power"
    
    private let textWidgetHelpPanel: HelpHUD = HelpHUD(textWidgetHelp)
    
    public init(_ module: ModuleType) {
        self.title = module.stringValue
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.timeFormat = Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
        self.textValue = Store.shared.string(key: "\(self.title)_textWidgetValue", defaultValue: self.textValue)
        
        super.init(frame: NSRect.zero)
        self.orientation = .vertical
        self.spacing = Constants.Settings.margin
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
        
        if widgets.contains(where: { $0 == .battery || $0 == .text }) {
            self.addArrangedSubview(PreferencesSection([
                PreferencesRow(localizedString("Time format"), component: selectView(
                    action: #selector(toggleTimeFormat),
                    items: ShortLong,
                    selected: self.timeFormat
                ))
            ]))
        }
        
        if widgets.contains(where: { $0 == .text }) {
            let textField = self.inputField(id: "text", value: self.textValue, placeholder: localizedString("This will be visible in the text widget"))
            self.addArrangedSubview(PreferencesSection([
                PreferencesRow(localizedString("Text widget value"), component: textField) { [weak self] in
                    self?.textWidgetHelpPanel.show()
                }
            ]))
        }
    }
    
    private func inputField(id: String, value: String, placeholder: String) -> NSView {
        let field: NSTextField = NSTextField()
        field.identifier = NSUserInterfaceItemIdentifier(id)
        field.widthAnchor.constraint(equalToConstant: 250).isActive = true
        field.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        field.textColor = .textColor
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.focusRingType = .none
        field.stringValue = value
        field.delegate = self
        field.placeholderString = placeholder
        return field
    }
    
    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
            self.callbackWhenUpdateNumberOfProcesses()
        }
    }
    @objc private func toggleTimeFormat(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.timeFormat = key
        Store.shared.set(key: "\(self.title)_timeFormat", value: key)
        self.callback()
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if let field = notification.object as? NSTextField {
            if field.identifier == NSUserInterfaceItemIdentifier("text") {
                self.textValue = field.stringValue
                Store.shared.set(key: "\(self.title)_textWidgetValue", value: self.textValue)
                self.callback()
            }
        }
    }
}
