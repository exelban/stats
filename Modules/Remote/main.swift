//
//  main.swift
//  Remote
//
//  Created by Serhiy Mytrovtsiy on 09/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

// MARK: - Data Structures

public struct Remote_CPU: Codable {
    public var totalUsage: Double = 0
    public var usagePerCore: [Double] = []
    public var systemLoad: Double = 0
    public var userLoad: Double = 0
    public var idleLoad: Double = 0
}

public struct Remote_LoadAvg: Codable {
    public var load1: Double = 0
    public var load5: Double = 0
    public var load15: Double = 0
}

public struct Remote_Process: Codable {
    public var pid: Int = 0
    public var name: String = ""
    public var usage: Double = 0
}

public struct Remote_Metrics: Codable {
    public var cpu: Remote_CPU = Remote_CPU()
    public var loadAvg: Remote_LoadAvg = Remote_LoadAvg()
    public var processes: [Remote_Process] = []
    public var hostname: String = ""
    public var timestamp: Double = 0
}

public enum Remote_ConnectionStatus {
    case connected
    case disconnected
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Module

public class Remote: Module {
    private let popupView: Popup
    private let settingsView: Settings

    private var metricsReader: RemoteReader? = nil

    private var systemColor: NSColor {
        let color = SColor.secondRed
        let key = Store.shared.string(key: "\(self.config.name)_systemColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }
    private var userColor: NSColor {
        let color = SColor.secondBlue
        let key = Store.shared.string(key: "\(self.config.name)_userColor", defaultValue: color.key)
        if let c = SColor.fromString(key).additional as? NSColor {
            return c
        }
        return color.additional as! NSColor
    }

    public init() {
        self.settingsView = Settings(.remote)
        self.popupView = Popup(.remote)

        super.init(
            moduleType: .remote,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }

        self.metricsReader = RemoteReader(.remote) { [weak self] value in
            self?.metricsCallback(value)
        }

        self.settingsView.callback = { [weak self] in
            self?.metricsReader?.read()
        }
        self.settingsView.setInterval = { [weak self] value in
            self?.metricsReader?.setInterval(value)
        }
        self.settingsView.hostURLChanged = { [weak self] in
            self?.metricsReader?.updateHost()
            self?.metricsReader?.read()
        }

        self.setReaders([self.metricsReader])
    }

    private func metricsCallback(_ raw: Remote_Metrics?) {
        guard self.enabled else { return }

        if let value = raw {
            self.popupView.metricsCallback(value)
            self.popupView.setConnectionStatus(.connected)

            self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: SWidget) in
                switch w.item {
                case let widget as Mini:
                    widget.setValue(value.cpu.totalUsage)
                case let widget as LineChart:
                    widget.setValue(value.cpu.totalUsage)
                case let widget as BarChart:
                    let val = value.cpu.usagePerCore.map({ [ColorValue($0)] })
                    widget.setValue(val.isEmpty ? [[ColorValue(value.cpu.totalUsage)]] : val)
                case let widget as PieChart:
                    widget.setValue([
                        circle_segment(value: value.cpu.systemLoad, color: self.systemColor),
                        circle_segment(value: value.cpu.userLoad, color: self.userColor)
                    ])
                default: break
                }
            }
        } else {
            self.popupView.setConnectionStatus(.disconnected)
        }
    }
}
