//
//  portal.swift
//  Claude
//
//  Created by Stats Claude Module
//

import Cocoa
import Kit

public class Portal: PortalWrapper {
    private var circle: PieChartView? = nil

    private var util5hField: NSTextField? = nil
    private var reset5hField: NSTextField? = nil
    private var util7dField: NSTextField? = nil
    private var reset7dField: NSTextField? = nil

    public override func load() {
        let view = NSStackView()
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        view.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Popup.spacing*2,
            bottom: 0,
            right: Constants.Popup.spacing*2
        )

        let chartsView = self.charts()
        let detailsView = self.details()

        view.addArrangedSubview(chartsView)
        view.addArrangedSubview(detailsView)

        self.addArrangedSubview(view)

        chartsView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        detailsView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
    }

    private func charts() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Popup.spacing*2
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Popup.spacing*4,
            left: Constants.Popup.spacing*4,
            bottom: Constants.Popup.spacing*4,
            right: Constants.Popup.spacing*4
        )

        let chart = PieChartView(frame: .zero, segments: [], drawValue: true)
        chart.toolTip = "Claude 5h usage"
        self.circle = chart
        view.addArrangedSubview(chart)

        return view
    }

    private func details() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2

        self.util5hField = portalRow(view, title: "5h usage:").1
        self.reset5hField = portalRow(view, title: "5h reset:").1
        self.util7dField = portalRow(view, title: "7d usage:").1
        self.reset7dField = portalRow(view, title: "7d reset:").1

        return view
    }

    internal func callback(_ value: Claude_Usage) {
        DispatchQueue.main.async {
            self.util5hField?.stringValue = "\(Int(value.utilization5h * 100))%"
            self.util7dField?.stringValue = "\(Int(value.utilization7d * 100))%"

            let color = Self.colorForUtilization(value.utilization5h)
            self.circle?.toolTip = "Claude 5h: \(Int(value.utilization5h * 100))%"
            self.circle?.setValue(value.utilization5h)
            self.circle?.setSegments([circle_segment(value: value.utilization5h, color: color)])
            self.circle?.setNonActiveSegmentColor(color.withAlphaComponent(0.15))

            if let reset = value.reset5h {
                self.reset5hField?.stringValue = self.formatReset(reset)
            }
            if let reset = value.reset7d {
                self.reset7dField?.stringValue = self.formatReset(reset)
            }
        }
    }

    // Green(0%) -> Green(80%) -> Yellow(90%) -> Red(100%)
    private static func colorForUtilization(_ u: Double) -> NSColor {
        let clamped = min(max(u, 0), 1)
        if clamped <= 0.8 {
            // Solid green
            return NSColor(red: 0.30, green: 0.78, blue: 0.40, alpha: 1.0)
        } else if clamped <= 0.9 {
            // Green -> Yellow (80%-90%)
            let t = (clamped - 0.8) / 0.1
            let r = 0.30 + t * (1.0 - 0.30)
            let g = 0.78 + t * (0.85 - 0.78)
            let b = 0.40 + t * (0.10 - 0.40)
            return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        } else {
            // Yellow -> Red (90%-100%)
            let t = (clamped - 0.9) / 0.1
            let r = 1.0
            let g = 0.85 - t * 0.85
            let b = 0.10 - t * 0.10
            return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        }
    }

    private func formatReset(_ date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 { return "now" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
