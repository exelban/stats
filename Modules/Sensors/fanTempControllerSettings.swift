//
//  fanTempControllerSettings.swift
//  Sensors
//
//  Created by Morteza Rastgoo on 09/05/2026.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

/// Settings view appended below the existing Sensors preferences.
/// Shows two sub-sections — "AC Adapter" and "Battery" — each with an
/// enable toggle and a target temperature slider (30–85 °C).
internal class FanTempControllerSettingsView: NSStackView {

    private var acEnabled: Bool
    private var acTarget: Int
    private var battEnabled: Bool
    private var battTarget: Int

    private weak var acSlider: NSSlider?
    private weak var acSliderLabel: NSTextField?
    private weak var battSlider: NSSlider?
    private weak var battSliderLabel: NSTextField?

    public init() {
        let ac   = FanTempController.shared.acSettings
        let batt = FanTempController.shared.battSettings
        self.acEnabled   = ac.enabled
        self.acTarget    = ac.targetTemp
        self.battEnabled = batt.enabled
        self.battTarget  = batt.targetTemp

        super.init(frame: .zero)
        self.orientation = .vertical
        self.spacing = Constants.Settings.margin
        self.translatesAutoresizingMaskIntoConstraints = false

        self.addArrangedSubview(self.makeSection(
            title: localizedString("AC Adapter"),
            subtitle: localizedString("Fan target temperature while plugged in"),
            enabled: self.acEnabled,
            target: self.acTarget,
            enableAction: #selector(self.toggleAC),
            sliderAction: #selector(self.slideAC),
            sliderOut: { [weak self] s, l in self?.acSlider = s; self?.acSliderLabel = l }
        ))
        self.addArrangedSubview(self.makeSection(
            title: localizedString("Battery"),
            subtitle: localizedString("Fan target temperature while on battery"),
            enabled: self.battEnabled,
            target: self.battTarget,
            enableAction: #selector(self.toggleBatt),
            sliderAction: #selector(self.slideBatt),
            sliderOut: { [weak self] s, l in self?.battSlider = s; self?.battSliderLabel = l }
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Actions

    @objc private func toggleAC(_ sender: NSControl) {
        self.acEnabled = controlState(sender)
        FanTempController.shared.acSettings.enabled = self.acEnabled
        self.acSlider?.isEnabled = self.acEnabled
    }

    @objc private func slideAC(_ sender: NSSlider) {
        let v = Int(sender.intValue)
        self.acTarget = v
        FanTempController.shared.acSettings.targetTemp = v
        self.acSliderLabel?.stringValue = "\(v) °C"
    }

    @objc private func toggleBatt(_ sender: NSControl) {
        self.battEnabled = controlState(sender)
        FanTempController.shared.battSettings.enabled = self.battEnabled
        self.battSlider?.isEnabled = self.battEnabled
    }

    @objc private func slideBatt(_ sender: NSSlider) {
        let v = Int(sender.intValue)
        self.battTarget = v
        FanTempController.shared.battSettings.targetTemp = v
        self.battSliderLabel?.stringValue = "\(v) °C"
    }

    // MARK: - View builders

    private func makeSection(
        title: String,
        subtitle: String,
        enabled: Bool,
        target: Int,
        enableAction: Selector,
        sliderAction: Selector,
        sliderOut: (_ slider: NSSlider, _ label: NSTextField) -> Void
    ) -> PreferencesSection {
        let toggle = switchView(action: enableAction, state: enabled)

        let slider = NSSlider(value: Double(target), minValue: 30, maxValue: 85,
                              target: self, action: sliderAction)
        slider.controlSize = .small
        slider.isEnabled = enabled

        let valueLabel = NSTextField(labelWithString: "\(target) °C")
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        sliderOut(slider, valueLabel)

        let minLbl = NSTextField(labelWithString: "30°")
        minLbl.font = NSFont.systemFont(ofSize: 10)
        minLbl.textColor = .tertiaryLabelColor
        let maxLbl = NSTextField(labelWithString: "85°")
        maxLbl.font = NSFont.systemFont(ofSize: 10)
        maxLbl.textColor = .tertiaryLabelColor

        let sliderRow = NSStackView(views: [minLbl, slider, maxLbl, valueLabel])
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 4

        return PreferencesSection(title: title, subtitle: subtitle, [
            PreferencesRow(localizedString("Enable"), component: toggle),
            PreferencesRow(localizedString("Target temperature"), component: sliderRow)
        ])
    }
}
