//
//  popup.swift
//  Claude
//
//  Created by Stats Claude Module
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private var util5hField: ValueField? = nil
    private var reset5hField: ValueField? = nil
    private var util7dField: ValueField? = nil
    private var reset7dField: ValueField? = nil

    private var initialized: Bool = false

    init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        self.orientation = .vertical
        self.spacing = Constants.Popup.spacing
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func usageCallback(_ value: Claude_Usage) {
        DispatchQueue.main.async {
            if !self.initialized { self.initView() }

            self.util5hField?.stringValue = "\(Int(value.utilization5h * 100))%"
            if let reset = value.reset5h {
                self.reset5hField?.stringValue = self.formatReset(reset)
            }

            self.util7dField?.stringValue = "\(Int(value.utilization7d * 100))%"
            if let reset = value.reset7d {
                self.reset7dField?.stringValue = self.formatReset(reset)
            }
        }
    }

    private func initView() {
        let section = PreferencesSection()
        let r1 = popupRow(title: "5h usage:", value: "-")
        self.util5hField = r1.1
        section.add(r1.2)
        let r2 = popupRow(title: "5h reset:", value: "-")
        self.reset5hField = r2.1
        section.add(r2.2)
        let r3 = popupRow(title: "7d usage:", value: "-")
        self.util7dField = r3.1
        section.add(r3.2)
        let r4 = popupRow(title: "7d reset:", value: "-")
        self.reset7dField = r4.1
        section.add(r4.2)
        self.addArrangedSubview(section)

        self.initialized = true

        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +) + (self.spacing * CGFloat(self.arrangedSubviews.count))
        self.sizeCallback?(NSSize(width: Constants.Popup.width, height: h))
    }

    private func formatReset(_ date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 { return "now" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
