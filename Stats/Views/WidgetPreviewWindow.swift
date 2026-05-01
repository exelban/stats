//
//  WidgetPreviewWindow.swift
//  Stats
//
//  Development-only preview window for menu bar widgets. Launched via the
//  `--preview` CLI flag so widget appearance can be iterated on without
//  installing the app to the menu bar.
//

import Cocoa
import Kit

internal class WidgetPreviewWindow: NSWindow {
    private var liquidGlass: Bool = Constants.isTahoe
    private var darkBackground: Bool = true
    
    private let stack: NSStackView = {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 16
        s.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let menubarRow: NSStackView = {
        let s = NSStackView()
        s.orientation = .horizontal
        s.alignment = .top
        s.spacing = 18
        s.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        s.wantsLayer = true
        s.layer?.cornerRadius = 8
        return s
    }()
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = "Stats — Widget Preview"
        self.center()
        self.isReleasedWhenClosed = false
        
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(self.stack)
        NSLayoutConstraint.activate([
            self.stack.topAnchor.constraint(equalTo: content.topAnchor),
            self.stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            self.stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            self.stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        self.contentView = content
        
        self.buildControls()
        self.stack.addArrangedSubview(self.menubarRow)
        self.refresh()
    }
    
    private func buildControls() {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        
        let glass = NSButton(checkboxWithTitle: "Liquid Glass", target: self, action: #selector(toggleGlass(_:)))
        glass.state = self.liquidGlass ? .on : .off
        
        let dark = NSButton(checkboxWithTitle: "Dark menu bar", target: self, action: #selector(toggleDark(_:)))
        dark.state = self.darkBackground ? .on : .off
        
        row.addArrangedSubview(glass)
        row.addArrangedSubview(dark)
        self.stack.addArrangedSubview(row)
    }
    
    @objc private func toggleGlass(_ sender: NSButton) {
        self.liquidGlass = sender.state == .on
        self.persist()
        self.refresh()
    }
    
    @objc private func toggleDark(_ sender: NSButton) {
        self.darkBackground = sender.state == .on
        self.refresh()
    }
    
    private func persist() {
        // Pre-seed Store entries so the freshly constructed widgets pick up
        // the current Liquid Glass state on init.
        let titles = ["CPU", "GPU", "RAM", "Disk", "Network", "Battery"]
        let widgets = ["bar_chart", "line_chart", "network_chart", "battery"]
        for t in titles {
            for w in widgets {
                Store.shared.set(key: "\(t)_\(w)_liquidGlass", value: self.liquidGlass)
            }
        }
    }
    
    private func refresh() {
        // Tear down the simulated menu bar row and rebuild from scratch so the
        // new toggle state takes effect on the next draw cycle.
        self.menubarRow.subviews.forEach { $0.removeFromSuperview() }
        self.menubarRow.layer?.backgroundColor = (self.darkBackground
            ? NSColor.black.withAlphaComponent(0.35)
            : NSColor.white.withAlphaComponent(0.35)).cgColor
        
        // Force the widgets inside the simulated menu bar to resolve as the
        // toggled appearance so `NSAppearance.current` (and any color helper
        // that reads it) returns the right ink color even when the host
        // window itself isn't using that appearance.
        let widgetAppearance = NSAppearance(named: self.darkBackground ? .darkAqua : .aqua)
        self.menubarRow.appearance = widgetAppearance
        
        // Helper that wraps each widget in a vertical stack with a name label
        // so it's obvious which widget is which in the preview.
        func labeled(_ name: String, _ widget: NSView) -> NSView {
            let column = NSStackView()
            column.orientation = .vertical
            column.alignment = .centerX
            column.spacing = 4
            
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.addArrangedSubview(widget)
            column.addArrangedSubview(row)
            
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textColor = self.darkBackground ? .white : .black
            column.addArrangedSubview(label)
            return column
        }
        
        // BarChart — CPU shows two stacked bars (e.g. system + user usage).
        let bar = BarChart(title: "CPU", config: nil, preview: false)
        bar.setValue([[ColorValue(0.32, color: nil)], [ColorValue(0.71, color: nil)]])
        self.menubarRow.addArrangedSubview(labeled("BarChart (CPU)", bar))
        
        // BarChart — GPU shows a single bar to demonstrate the taller
        // single-row pill that gets to claim more vertical space.
        let gpu = BarChart(title: "GPU", config: nil, preview: false)
        gpu.setValue([[ColorValue(0.55, color: nil)]])
        self.menubarRow.addArrangedSubview(labeled("BarChart (GPU)", gpu))
        
        // LineChart — RAM.
        let line = LineChart(title: "RAM", config: nil, preview: false)
        for v in stride(from: 0.1, through: 0.9, by: 0.07) { line.setValue(v) }
        self.menubarRow.addArrangedSubview(labeled("LineChart (RAM)", line))
        
        // NetworkChart — Network.
        let net = NetworkChart(title: "Network", config: nil, preview: false)
        for i in 0..<30 {
            net.setValue(upload: Double((i % 7) * 1000), download: Double((i % 11) * 1500))
        }
        self.menubarRow.addArrangedSubview(labeled("NetworkChart (Net)", net))
        
        // Battery.
        let bat = BatteryWidget(title: "Battery", preview: false)
        bat.setValue(percentage: 0.62, ACStatus: false, isCharging: false, optimizedCharging: false, time: 0)
        self.menubarRow.addArrangedSubview(labeled("Battery", bat))
    }
}
