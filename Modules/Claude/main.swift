//
//  main.swift
//  Claude
//
//  Created by Stats Claude Module
//

import Cocoa
import Kit

public struct Claude_Usage: Codable {
    public var utilization5h: Double = 0   // 0.0 ~ 1.0
    public var utilization7d: Double = 0
    public var overageUtilization: Double = 0
    public var fallbackPercentage: Double = 0

    public var reset5h: Date? = nil
    public var reset7d: Date? = nil

    public var status5h: String = "unknown"
    public var status7d: String = "unknown"
}

public class Claude: Module {
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal

    private var usageReader: ClaudeUsageReader? = nil

    public init() {
        self.popupView = Popup(.claude)
        self.settingsView = Settings(.claude)
        self.portalView = Portal(.claude)

        super.init(
            moduleType: .claude,
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView
        )
        guard self.available else { return }

        self.usageReader = ClaudeUsageReader(.claude) { [weak self] value in
            self?.usageCallback(value)
        }

        self.settingsView.setInterval = { [weak self] value in
            self?.usageReader?.setInterval(value)
        }

        self.setReaders([self.usageReader])
    }

    private func usageCallback(_ raw: Claude_Usage?) {
        guard let value = raw, self.enabled else { return }

        self.popupView.usageCallback(value)
        self.portalView.callback(value)

        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: SWidget) in
            switch w.item {
            case let widget as Mini: widget.setValue(value.utilization5h)
            case let widget as LineChart: widget.setValue(value.utilization5h)
            case let widget as TextWidget: widget.setValue("\(Int(value.utilization5h * 100))%")
            default: break
            }
        }
    }

    override public func isAvailable() -> Bool {
        return true
    }
}
