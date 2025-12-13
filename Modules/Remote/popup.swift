//
//  popup.swift
//  Remote
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 120 + Constants.Popup.separatorHeight
    private let detailsHeight: CGFloat = (22*4) + Constants.Popup.separatorHeight
    private let averageHeight: CGFloat = (22*3) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = 22

    private var statusField: NSTextField? = nil
    private var hostnameField: NSTextField? = nil
    private var systemField: NSTextField? = nil
    private var userField: NSTextField? = nil
    private var idleField: NSTextField? = nil
    private var average1Field: NSTextField? = nil
    private var average5Field: NSTextField? = nil
    private var average15Field: NSTextField? = nil

    private var systemColorView: NSView? = nil
    private var userColorView: NSView? = nil
    private var idleColorView: NSView? = nil

    private var lineChart: LineChartView? = nil
    private var barChart: BarChartView? = nil
    private var circle: PieChartView? = nil
    private var statusIndicator: NSView? = nil

    private var processesContainer: NSStackView? = nil
    private var processLabels: [(NSTextField, NSTextField)] = []

    private var systemColorState: SColor = .secondRed
    private var systemColor: NSColor { self.systemColorState.additional as? NSColor ?? NSColor.systemRed }
    private var userColorState: SColor = .secondBlue
    private var userColor: NSColor { self.userColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var idleColorState: SColor = .lightGray
    private var idleColor: NSColor { self.idleColorState.additional as? NSColor ?? NSColor.lightGray }
    private var chartColorState: SColor = .systemAccent
    private var chartColor: NSColor { self.chartColorState.additional as? NSColor ?? NSColor.systemBlue }

    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 5)
    }
    private var processesHeight: CGFloat {
        (self.processHeight * CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    private var lineChartHistory: Int = 180

    private var connectionStatus: Remote_ConnectionStatus = .disconnected
    private var lastMetrics: Remote_Metrics? = nil

    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))

        self.spacing = 0
        self.orientation = .vertical

        self.systemColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_systemColor", defaultValue: self.systemColorState.key))
        self.userColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_userColor", defaultValue: self.userColorState.key))
        self.idleColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_idleColor", defaultValue: self.idleColorState.key))
        self.chartColorState = SColor.fromString(Store.shared.string(key: "\(self.title)_chartColor", defaultValue: self.chartColorState.key))
        self.lineChartHistory = Store.shared.int(key: "\(self.title)_lineChartHistory", defaultValue: self.lineChartHistory)

        self.addArrangedSubview(self.initDashboard())
        self.addArrangedSubview(self.initChart())
        self.addArrangedSubview(self.initDetails())
        self.addArrangedSubview(self.initAverage())
        self.addArrangedSubview(self.initProcesses())

        self.recalculateHeight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func updateLayer() {
        self.lineChart?.display()
    }

    private func recalculateHeight() {
        var h: CGFloat = 0
        self.arrangedSubviews.forEach { v in
            if let v = v as? NSStackView {
                h += v.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
            } else {
                h += v.bounds.height
            }
        }
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }

    // MARK: - Dashboard

    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.dashboardHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true

        let usageSize = self.dashboardHeight - 20
        let usageX = (view.frame.width - usageSize) / 2

        let usage = NSView(frame: NSRect(x: usageX, y: (view.frame.height - usageSize) / 2, width: usageSize, height: usageSize))

        self.circle = PieChartView(frame: NSRect(x: 0, y: 0, width: usage.frame.width, height: usage.frame.height), segments: [], drawValue: true)
        self.circle!.toolTip = localizedString("CPU usage")
        usage.addSubview(self.circle!)

        // Status indicator (left side)
        let statusContainer = NSView(frame: NSRect(x: 10, y: (view.frame.height - 50) / 2, width: 60, height: 50))

        self.statusIndicator = NSView(frame: NSRect(x: 24, y: 32, width: 12, height: 12))
        self.statusIndicator?.wantsLayer = true
        self.statusIndicator?.layer?.cornerRadius = 6
        self.statusIndicator?.layer?.backgroundColor = NSColor.systemGray.cgColor
        statusContainer.addSubview(self.statusIndicator!)

        let statusLabel = LabelField(frame: NSRect(x: 0, y: 12, width: 60, height: 16), "")
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        self.statusField = statusLabel
        statusContainer.addSubview(statusLabel)

        // Hostname (right side)
        let hostnameContainer = NSView(frame: NSRect(x: view.frame.width - 70, y: (view.frame.height - 50) / 2, width: 60, height: 50))

        let hostnameLabel = LabelField(frame: NSRect(x: 0, y: 20, width: 60, height: 16), "")
        hostnameLabel.alignment = .center
        hostnameLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        hostnameLabel.textColor = .secondaryLabelColor
        self.hostnameField = hostnameLabel
        hostnameContainer.addSubview(hostnameLabel)

        view.addSubview(statusContainer)
        view.addSubview(usage)
        view.addSubview(hostnameContainer)

        return view
    }

    // MARK: - Chart

    private func initChart() -> NSView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        view.orientation = .vertical
        view.spacing = 0

        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: 0), width: self.frame.width)

        let lineChartContainer: NSView = {
            let box: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 70))
            box.heightAnchor.constraint(equalToConstant: box.frame.height).isActive = true
            box.wantsLayer = true
            box.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
            box.layer?.cornerRadius = 3

            let chartFrame = NSRect(x: 1, y: 0, width: box.frame.width, height: box.frame.height)
            self.lineChart = LineChartView(frame: chartFrame, num: self.lineChartHistory)
            self.lineChart?.color = self.chartColor
            box.addSubview(self.lineChart!)

            return box
        }()

        let barChartContainer: NSView = {
            let box: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 50))
            box.heightAnchor.constraint(equalToConstant: box.frame.height).isActive = true
            box.wantsLayer = true
            box.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
            box.layer?.cornerRadius = 3

            let chart = BarChartView(frame: NSRect(
                x: Constants.Popup.spacing,
                y: Constants.Popup.spacing,
                width: view.frame.width - (Constants.Popup.spacing * 2),
                height: box.frame.height - (Constants.Popup.spacing * 2)
            ), num: 8) // Default 8 cores, will resize dynamically
            self.barChart = chart

            box.addSubview(chart)

            return box
        }()

        view.addArrangedSubview(separator)
        view.addArrangedSubview(lineChartContainer)
        view.addArrangedSubview(barChartContainer)

        return view
    }

    // MARK: - Details

    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Details"), origin: NSPoint(
            x: 0,
            y: self.detailsHeight - Constants.Popup.separatorHeight
        ), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0

        (self.systemColorView, _, self.systemField) = popupWithColorRow(container, color: self.systemColor, title: "\(localizedString("System")):", value: "-")
        (self.userColorView, _, self.userField) = popupWithColorRow(container, color: self.userColor, title: "\(localizedString("User")):", value: "-")
        (self.idleColorView, _, self.idleField) = popupWithColorRow(container, color: self.idleColor.withAlphaComponent(0.5), title: "\(localizedString("Idle")):", value: "-")

        let hostRow = popupRow(container, title: "\(localizedString("Host")):", value: "-")
        self.hostnameField = hostRow.1

        view.addSubview(separator)
        view.addSubview(container)

        return view
    }

    // MARK: - Average Load

    private func initAverage() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.averageHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Average load"), origin: NSPoint(x: 0, y: self.averageHeight - Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0

        self.average1Field = popupRow(container, title: "\(localizedString("1 minute")):", value: "-").1
        self.average5Field = popupRow(container, title: "\(localizedString("5 minutes")):", value: "-").1
        self.average15Field = popupRow(container, title: "\(localizedString("15 minutes")):", value: "-").1

        view.addSubview(separator)
        view.addSubview(container)

        return view
    }

    // MARK: - Processes

    private func initProcesses() -> NSView {
        if self.numberOfProcesses == 0 {
            return NSView()
        }

        let height = self.processesHeight
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: height))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: height - Constants.Popup.separatorHeight), width: self.frame.width)

        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        self.processesContainer = container

        // Header row
        let headerRow = NSView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
        headerRow.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let processLabel = LabelField(frame: NSRect(x: 8, y: 2, width: 150, height: 18), localizedString("Process"))
        processLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        processLabel.textColor = .tertiaryLabelColor
        headerRow.addSubview(processLabel)

        let cpuLabel = LabelField(frame: NSRect(x: container.frame.width - 60, y: 2, width: 52, height: 18), localizedString("CPU"))
        cpuLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        cpuLabel.textColor = .tertiaryLabelColor
        cpuLabel.alignment = .right
        headerRow.addSubview(cpuLabel)

        container.addArrangedSubview(headerRow)

        // Process rows
        for _ in 0..<self.numberOfProcesses {
            let row = NSView(frame: NSRect(x: 0, y: 0, width: container.frame.width, height: 22))
            row.heightAnchor.constraint(equalToConstant: 22).isActive = true

            let nameLabel = LabelField(frame: NSRect(x: 8, y: 2, width: 180, height: 18), "-")
            nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            nameLabel.cell?.truncatesLastVisibleLine = true
            row.addSubview(nameLabel)

            let usageLabel = LabelField(frame: NSRect(x: container.frame.width - 60, y: 2, width: 52, height: 18), "-")
            usageLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            usageLabel.alignment = .right
            row.addSubview(usageLabel)

            self.processLabels.append((nameLabel, usageLabel))
            container.addArrangedSubview(row)
        }

        view.addSubview(separator)
        view.addSubview(container)

        return view
    }

    // MARK: - Public Methods

    public func setConnectionStatus(_ status: Remote_ConnectionStatus) {
        self.connectionStatus = status

        DispatchQueue.main.async {
            switch status {
            case .connected:
                self.statusIndicator?.layer?.backgroundColor = NSColor.systemGreen.cgColor
                self.statusField?.stringValue = localizedString("Connected")
            case .disconnected:
                self.statusIndicator?.layer?.backgroundColor = NSColor.systemGray.cgColor
                self.statusField?.stringValue = localizedString("Offline")
            case .error(let msg):
                self.statusIndicator?.layer?.backgroundColor = NSColor.systemRed.cgColor
                self.statusField?.stringValue = msg
            }
        }
    }

    public func metricsCallback(_ value: Remote_Metrics) {
        self.lastMetrics = value

        DispatchQueue.main.async {
            // Update pie chart
            self.circle?.setValue([
                circle_segment(value: value.cpu.systemLoad, color: self.systemColor),
                circle_segment(value: value.cpu.userLoad, color: self.userColor)
            ])
            self.circle?.setText(value.cpu.totalUsage)

            // Update line chart
            self.lineChart?.addValue(value.cpu.totalUsage)

            // Update bar chart
            if !value.cpu.usagePerCore.isEmpty {
                self.barChart?.setValues(value.cpu.usagePerCore.map({ ColorValue($0) }))
            }

            // Update details
            self.systemField?.stringValue = "\(Int(value.cpu.systemLoad * 100))%"
            self.userField?.stringValue = "\(Int(value.cpu.userLoad * 100))%"
            self.idleField?.stringValue = "\(Int(value.cpu.idleLoad * 100))%"
            self.hostnameField?.stringValue = value.hostname

            // Update average load
            self.average1Field?.stringValue = String(format: "%.2f", value.loadAvg.load1)
            self.average5Field?.stringValue = String(format: "%.2f", value.loadAvg.load5)
            self.average15Field?.stringValue = String(format: "%.2f", value.loadAvg.load15)

            // Update processes
            for (i, (nameLabel, usageLabel)) in self.processLabels.enumerated() {
                if i < value.processes.count {
                    let proc = value.processes[i]
                    nameLabel.stringValue = proc.name
                    usageLabel.stringValue = String(format: "%.1f%%", proc.usage)
                } else {
                    nameLabel.stringValue = "-"
                    usageLabel.stringValue = "-"
                }
            }
        }
    }
}
