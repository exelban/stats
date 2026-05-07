//
//  fanProfileSettings.swift
//  Sensors
//
//  Created for Stats fan profile engine.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

#if arch(arm64)

import Cocoa

// Mirrors Stats' PreferencesSection/PreferencesRow patterns used elsewhere in settings.swift.
internal class FanProfileSettingsView: NSStackView {
    public var onChange: (() -> Void) = {}

    private var profiles: [FanProfile] = []
    private var profileRows: NSStackView = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        self.orientation = .vertical
        self.spacing = Constants.Settings.margin
        self.translatesAutoresizingMaskIntoConstraints = false

        let header = self.makeHeader()
        self.addArrangedSubview(header)

        self.profileRows.orientation = .vertical
        self.profileRows.spacing = Constants.Settings.margin
        self.addArrangedSubview(self.profileRows)

        self.reload()
    }

    private func makeHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let label = NSTextField(labelWithString: localizedString("Fan Profiles"))
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let addPresetButton = NSPopUpButton()
        addPresetButton.addItem(withTitle: localizedString("Add preset…"))
        for preset in FanProfilePreset.allCases {
            addPresetButton.addItem(withTitle: preset.profile.name)
        }
        addPresetButton.target = self
        addPresetButton.action = #selector(self.addPreset(_:))

        let addCustomButton = NSButton(title: "+", target: self, action: #selector(self.addCustomProfile))
        addCustomButton.bezelStyle = .roundRect
        addCustomButton.toolTip = localizedString("Add custom profile")

        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView()) // flexible spacer
        row.addArrangedSubview(addPresetButton)
        row.addArrangedSubview(addCustomButton)
        return row
    }

    private func reload() {
        self.profileRows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        self.profiles = FanProfileEngine.shared.allProfiles

        if profiles.isEmpty {
            let empty = NSTextField(labelWithString: localizedString("No profiles. Add a preset to get started."))
            empty.textColor = .secondaryLabelColor
            empty.font = NSFont.systemFont(ofSize: 12)
            self.profileRows.addArrangedSubview(empty)
            return
        }

        for profile in profiles {
            self.profileRows.addArrangedSubview(self.makeProfileRow(profile))
        }
    }

    private func makeProfileRow(_ profile: FanProfile) -> NSView {
        let section = PreferencesSection([
            PreferencesRow(profile.name, component: self.makeProfileControls(profile))
        ])
        section.identifier = NSUserInterfaceItemIdentifier("profile_\(profile.id.uuidString)")
        return section
    }

    private func makeProfileControls(_ profile: FanProfile) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8

        let toggle = NSSwitch()
        toggle.state = profile.enabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(self.toggleProfile(_:))
        // Store UUID directly so the action handler doesn't need to parse a prefixed string.
        toggle.identifier = NSUserInterfaceItemIdentifier(profile.id.uuidString)
        toggle.toolTip = profile.enabled
            ? localizedString("Disable profile")
            : localizedString("Enable profile")

        let fanLabel = NSTextField(labelWithString: profile.fanID == -1
            ? localizedString("All fans")
            : "Fan \(profile.fanID)")
        fanLabel.textColor = .secondaryLabelColor
        fanLabel.font = NSFont.systemFont(ofSize: 11)

        let deleteBtn = NSButton(title: "✕", target: self, action: #selector(self.deleteProfile(_:)))
        deleteBtn.bezelStyle = .roundRect
        deleteBtn.identifier = NSUserInterfaceItemIdentifier(profile.id.uuidString)
        deleteBtn.toolTip = localizedString("Remove profile")

        stack.addArrangedSubview(toggle)
        stack.addArrangedSubview(fanLabel)
        stack.addArrangedSubview(deleteBtn)
        return stack
    }

    // MARK: - Actions

    @objc private func addPreset(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem > 0 else { return }
        let presetIndex = sender.indexOfSelectedItem - 1
        let presets = FanProfilePreset.allCases
        guard presetIndex < presets.count else { return }
        FanProfileEngine.shared.addProfile(presets[presetIndex].profile)
        sender.selectItem(at: 0)
        self.reload()
        self.onChange()
    }

    @objc private func addCustomProfile() {
        let profile = FanProfile(
            name: "Custom",
            fanID: -1,
            points: [
                CurvePoint(temperatureC: 40, rpm: 1500),
                CurvePoint(temperatureC: 70, rpm: 3000),
                CurvePoint(temperatureC: 90, rpm: 5000)
            ]
        )
        FanProfileEngine.shared.addProfile(profile)
        self.reload()
        self.onChange()
    }

    @objc private func toggleProfile(_ sender: NSSwitch) {
        guard let uuidStr = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: uuidStr) else { return }
        var profile = FanProfileEngine.shared.allProfiles.first(where: { $0.id == uuid })
        profile?.enabled = (sender.state == .on)
        if let p = profile { FanProfileEngine.shared.updateProfile(p) }
        self.reload()
        self.onChange()
    }

    @objc private func deleteProfile(_ sender: NSButton) {
        guard let uuidStr = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: uuidStr) else { return }
        FanProfileEngine.shared.removeProfile(id: uuid)
        self.reload()
        self.onChange()
    }
}

#endif
