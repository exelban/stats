//
//  settings.swift
//  Remote
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v, NSTextFieldDelegate {
    private var hostURLValue: String = "http://box:9090"
    private var updateIntervalValue: Int = 2
    private var numberOfProcesses: Int = 5
    private var timeoutValue: Int = 5

    private let title: String

    public var callback: (() -> Void) = {}
    public var setInterval: ((_ value: Int) -> Void) = {_ in }
    public var hostURLChanged: (() -> Void) = {}

    private var hostTextField: NSTextField? = nil
    private var statusLabel: NSTextField? = nil

    public init(_ module: ModuleType) {
        self.title = module.stringValue
        self.hostURLValue = Store.shared.string(key: "\(self.title)_hostURL", defaultValue: self.hostURLValue)
        self.updateIntervalValue = Store.shared.int(key: "\(self.title)_updateInterval", defaultValue: self.updateIntervalValue)
        self.numberOfProcesses = Store.shared.int(key: "\(self.title)_processes", defaultValue: self.numberOfProcesses)
        self.timeoutValue = Store.shared.int(key: "\(self.title)_timeout", defaultValue: self.timeoutValue)

        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))

        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.translatesAutoresizingMaskIntoConstraints = false
        self.spacing = Constants.Settings.margin
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func load(widgets: [widget_t]) {
        self.subviews.forEach { $0.removeFromSuperview() }

        // Connection Section
        let hostField = NSTextField(frame: NSRect(x: 0, y: 0, width: 180, height: 22))
        hostField.stringValue = self.hostURLValue
        hostField.placeholderString = "http://host:port"
        hostField.delegate = self
        hostField.font = NSFont.systemFont(ofSize: 12)
        hostField.alignment = .left
        hostField.isEditable = true
        hostField.isSelectable = true
        hostField.isBezeled = true
        hostField.bezelStyle = .roundedBezel
        self.hostTextField = hostField

        let testButton = NSButton(frame: NSRect(x: 0, y: 0, width: 60, height: 22))
        testButton.title = localizedString("Test")
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(self.testConnection)

        let hostRow = NSStackView()
        hostRow.orientation = .horizontal
        hostRow.spacing = 8
        hostRow.addArrangedSubview(hostField)
        hostRow.addArrangedSubview(testButton)

        let statusField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 16))
        statusField.stringValue = ""
        statusField.font = NSFont.systemFont(ofSize: 10)
        statusField.textColor = .secondaryLabelColor
        statusField.isBezeled = false
        statusField.isEditable = false
        statusField.backgroundColor = .clear
        statusField.alignment = .left
        self.statusLabel = statusField

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Host URL"), component: hostRow),
            PreferencesRow("", component: statusField)
        ]))

        // Update Intervals Section
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Update interval"), component: selectView(
                action: #selector(self.changeUpdateInterval),
                items: ReaderUpdateIntervals,
                selected: "\(self.updateIntervalValue)"
            )),
            PreferencesRow(localizedString("Connection timeout"), component: selectView(
                action: #selector(self.changeTimeout),
                items: [
                    KeyValue_t(key: "3", value: "3 sec"),
                    KeyValue_t(key: "5", value: "5 sec"),
                    KeyValue_t(key: "10", value: "10 sec"),
                    KeyValue_t(key: "15", value: "15 sec")
                ],
                selected: "\(self.timeoutValue)"
            ))
        ]))

        // Display Section
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Number of top processes"), component: selectView(
                action: #selector(self.changeNumberOfProcesses),
                items: NumbersOfProcesses.map { KeyValue_t(key: "\($0)", value: "\($0)") },
                selected: "\(self.numberOfProcesses)"
            ))
        ]))
    }

    // MARK: - NSTextFieldDelegate

    public func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let newValue = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if newValue != self.hostURLValue {
            self.hostURLValue = newValue
            Store.shared.set(key: "\(self.title)_hostURL", value: newValue)
            self.hostURLChanged()
            self.statusLabel?.stringValue = localizedString("Host URL updated")
            self.statusLabel?.textColor = .secondaryLabelColor
        }
    }

    // MARK: - Actions

    @objc private func testConnection() {
        guard let urlString = self.hostTextField?.stringValue,
              let url = URL(string: "\(urlString)/cpu") else {
            self.statusLabel?.stringValue = localizedString("Invalid URL")
            self.statusLabel?.textColor = .systemRed
            return
        }

        self.statusLabel?.stringValue = localizedString("Testing...")
        self.statusLabel?.textColor = .secondaryLabelColor

        var request = URLRequest(url: url, timeoutInterval: TimeInterval(self.timeoutValue))
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel?.stringValue = error.localizedDescription
                    self?.statusLabel?.textColor = .systemRed
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.statusLabel?.stringValue = localizedString("No response")
                    self?.statusLabel?.textColor = .systemRed
                    return
                }

                if httpResponse.statusCode == 200 {
                    if let data = data,
                       let _ = try? JSONDecoder().decode(Remote_Metrics.self, from: data) {
                        self?.statusLabel?.stringValue = localizedString("Connection successful")
                        self?.statusLabel?.textColor = .systemGreen
                    } else {
                        self?.statusLabel?.stringValue = localizedString("Invalid response format")
                        self?.statusLabel?.textColor = .systemOrange
                    }
                } else {
                    self?.statusLabel?.stringValue = "HTTP \(httpResponse.statusCode)"
                    self?.statusLabel?.textColor = .systemRed
                }
            }
        }.resume()
    }

    @objc private func changeUpdateInterval(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.updateIntervalValue = value
        Store.shared.set(key: "\(self.title)_updateInterval", value: value)
        self.setInterval(value)
    }

    @objc private func changeTimeout(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let value = Int(key) else { return }
        self.timeoutValue = value
        Store.shared.set(key: "\(self.title)_timeout", value: value)
    }

    @objc private func changeNumberOfProcesses(_ sender: NSMenuItem) {
        if let value = Int(sender.title) {
            self.numberOfProcesses = value
            Store.shared.set(key: "\(self.title)_processes", value: value)
        }
    }
}
