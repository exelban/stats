//
//  process.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 05/01/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Process_p {
    var pid: Int { get }
    var name: String { get }
    var icon: NSImage { get }
}

public typealias ProcessHeader = (title: String, color: NSColor?)

public class ProcessesView: NSStackView {
    public var count: Int {
        self.list.count
    }
    
    private let values: [ProcessHeader]
    private let showPID: Bool
    private let showChart: Bool
    private var list: [ProcessView] = []
    private var header: ProcessView? = nil
    private var windowObserver: NSObjectProtocol? = nil
    
    public init(frame: NSRect = .zero, values: [ProcessHeader], n: Int = 0, showPID: Bool = false, showChart: Bool = false) {
        self.values = values
        self.showPID = showPID
        self.showChart = showChart
        
        super.init(frame: frame)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.setHuggingPriority(.required, for: .horizontal)
        self.spacing = 0
        
        let header = self.makeRow(header: true)
        self.addArrangedSubview(header)
        self.header = header
        self.setNumberOfProcesses(n)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observer = self.windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let observer = self.windowObserver {
            NotificationCenter.default.removeObserver(observer)
            self.windowObserver = nil
        }
        self.setLock(false)
        if let window = self.window {
            self.windowObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                self?.setLock(false)
            }
        }
    }
    
    public override func viewDidHide() {
        super.viewDidHide()
        self.setLock(false)
    }
    
    private func makeRow(header: Bool = false, alternate: Bool = false) -> ProcessView {
        let detailed = self.showPID || self.showChart
        let size = CGSize(width: self.frame.width > 0 ? self.frame.width : 264, height: detailed ? (header ? 24 : 28) : ProcessView.height)
        return ProcessView(size: size, values: self.values, showPID: self.showPID, showChart: self.showChart, header: header, alternate: detailed && alternate)
    }
    
    public func setNumberOfProcesses(_ n: Int) {
        let count = max(n, 0)
        while self.list.count > count {
            self.list.removeLast().removeFromSuperview()
        }
        for i in self.list.count..<count {
            let view = self.makeRow(alternate: i % 2 == 0)
            self.addArrangedSubview(view)
            self.list.append(view)
        }
    }
    
    public func setLock(_ newValue: Bool) {
        self.list.forEach{ $0.setLock(newValue) }
    }
    
    public func clear(_ symbol: String = "") {
        self.list.forEach{ $0.clear(symbol) }
    }
    
    public func set(_ idx: Int, _ process: Process_p?, _ values: [String], usage: ColorValue? = nil) {
        if self.list.indices.contains(idx) {
            self.list[idx].set(process, values, usage: usage)
        }
    }
    
    public func setColor(_ idx: Int, _ newColor: NSColor) {
        self.header?.setColor(idx, newColor)
    }
}

public class ProcessView: NSStackView {
    static let height: CGFloat = 22
    
    private let header: Bool
    private let alternate: Bool
    private let detailed: Bool
    private var pid: Int? = nil
    private var lock: Bool = false
    private var hovered: Bool = false
    
    private var imageView: NSImageView = NSImageView()
    private var killView: NSButton = NSButton()
    private var labelView: LabelField = {
        let view = LabelField()
        view.cell?.truncatesLastVisibleLine = true
        view.lineBreakMode = .byTruncatingTail
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()
    private var pidView: LabelField? = nil
    private var bar: BarChartView? = nil
    private var valueViews: [ValueField] = []
    private var colorViews: [Int: ColorView] = [:]
    
    public convenience init(size: CGSize = CGSize(width: 264, height: 22), n: Int = 1, showPID: Bool = false, showChart: Bool = false) {
        self.init(size: size, values: Array(repeating: ("", nil), count: n), showPID: showPID, showChart: showChart, header: false, alternate: false)
    }
    
    fileprivate init(size: CGSize, values: [ProcessHeader], showPID: Bool, showChart: Bool, header: Bool, alternate: Bool) {
        self.header = header
        self.alternate = alternate
        self.detailed = showPID || showChart
        
        super.init(frame: NSRect(origin: .zero, size: size))
        
        self.wantsLayer = true
        self.orientation = .horizontal
        self.alignment = .centerY
        self.distribution = self.detailed ? .fill : .fillProportionally
        self.spacing = self.detailed ? Constants.Settings.margin : 0
        self.layer?.cornerRadius = 3
        if self.detailed {
            self.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
            self.labelView.textColor = .labelColor
        } else {
            self.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        }
        self.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        
        let imageBox = NSView()
        let iconSize: CGFloat = self.detailed ? 18 : 12
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.imageScaling = .scaleProportionallyDown
        self.killView.bezelStyle = .regularSquare
        self.killView.translatesAutoresizingMaskIntoConstraints = false
        self.killView.imageScaling = .scaleNone
        self.killView.image = iconFromSymbol(name: "xmark", scale: .small)
        self.killView.contentTintColor = .secondaryLabelColor
        self.killView.isBordered = false
        self.killView.action = #selector(self.kill)
        self.killView.target = self
        self.killView.toolTip = localizedString("Kill process")
        self.killView.focusRingType = .none
        self.killView.isHidden = true
        self.killView.isEnabled = false
        imageBox.addSubview(self.imageView)
        imageBox.addSubview(self.killView)
        
        if self.detailed {
            let process = NSStackView()
            process.orientation = .horizontal
            process.alignment = .centerY
            process.distribution = .fill
            process.spacing = 6
            process.addArrangedSubview(imageBox)
            process.addArrangedSubview(self.labelView)
            self.addArrangedSubview(process)
            if showChart {
                process.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 0.35).isActive = true
            }
        } else {
            self.addArrangedSubview(imageBox)
            self.addArrangedSubview(self.labelView)
        }
        
        if showPID {
            let field = LabelField(header ? "PID" : "")
            field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            field.widthAnchor.constraint(equalToConstant: 54).isActive = true
            self.addArrangedSubview(field)
            self.pidView = field
        }
        if showChart {
            let bar = BarChartView(size: 8, horizontal: true, animation: false)
            bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
            bar.setAccessibilityElement(false)
            bar.alphaValue = header ? 0 : 1
            self.addArrangedSubview(bar)
            self.bar = bar
        }
        self.valuesViews(values).forEach{ self.addArrangedSubview($0) }
        
        NSLayoutConstraint.activate([
            imageBox.widthAnchor.constraint(equalToConstant: self.detailed ? iconSize : size.height),
            imageBox.heightAnchor.constraint(equalToConstant: size.height),
            self.imageView.leadingAnchor.constraint(equalTo: imageBox.leadingAnchor, constant: self.detailed ? 0 : 2),
            self.imageView.centerYAnchor.constraint(equalTo: imageBox.centerYAnchor),
            self.imageView.widthAnchor.constraint(equalToConstant: iconSize),
            self.imageView.heightAnchor.constraint(equalToConstant: iconSize),
            self.killView.centerXAnchor.constraint(equalTo: self.imageView.centerXAnchor),
            self.killView.centerYAnchor.constraint(equalTo: self.imageView.centerYAnchor),
            self.killView.widthAnchor.constraint(equalToConstant: iconSize),
            self.killView.heightAnchor.constraint(equalToConstant: iconSize),
            self.labelView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        if header {
            self.labelView.stringValue = localizedString("Process")
            let fields: [NSTextField] = [self.labelView] + self.valueViews + [self.pidView].compactMap{ $0 }
            fields.forEach {
                $0.font = .systemFont(ofSize: 11, weight: .medium)
                $0.textColor = .tertiaryLabelColor
                $0.toolTip = $0.stringValue
            }
        } else {
            self.addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func valuesViews(_ values: [ProcessHeader]) -> [NSView] {
        var list: [NSView] = []
        let width: CGFloat = self.detailed ? 64 : 68
        
        for (i, value) in values.enumerated() {
            if self.header && values.count > 1, let color = value.color {
                let container = NSView()
                let block = ColorView(color: color, state: true, radius: 4)
                block.translatesAutoresizingMaskIntoConstraints = false
                block.toolTip = value.title
                container.addSubview(block)
                NSLayoutConstraint.activate([
                    block.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    block.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    block.widthAnchor.constraint(equalToConstant: 12),
                    block.heightAnchor.constraint(equalToConstant: 12),
                    container.widthAnchor.constraint(equalToConstant: width),
                    container.heightAnchor.constraint(equalToConstant: ProcessView.height)
                ])
                self.colorViews[i] = block
                list.append(container)
            } else {
                let field = ValueField(self.header ? value.title : "")
                if self.detailed {
                    field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
                } else if values.count != 1 {
                    field.font = .systemFont(ofSize: 10, weight: .regular)
                }
                if self.header {
                    field.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
                    field.setContentCompressionResistancePriority(.required, for: .horizontal)
                } else {
                    field.widthAnchor.constraint(equalToConstant: width).isActive = true
                }
                self.valueViews.append(field)
                list.append(field)
            }
        }
        
        return list
    }
    
    public override var wantsUpdateLayer: Bool { true }
    
    public override func updateLayer() {
        if self.lock {
            self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
        } else if self.hovered {
            self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        } else {
            self.layer?.backgroundColor = self.alternate ? NSColor.alternatingContentBackgroundColors[1].cgColor : NSColor.clear.cgColor
        }
    }
    
    public override func mouseEntered(with: NSEvent) {
        guard !self.header else { return }
        self.hovered = true
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
        }
        self.needsDisplay = true
    }
    
    public override func mouseExited(with: NSEvent) {
        self.hovered = false
        self.imageView.isHidden = false
        self.killView.isHidden = true
        self.needsDisplay = true
    }
    
    public override func mouseDown(with: NSEvent) {
        guard !self.header, self.pid != nil else { return }
        self.setLock(!self.lock)
    }
    
    fileprivate func set(_ process: Process_p?, _ values: [String], usage: ColorValue?) {
        if self.lock && process?.pid != self.pid { return }
        guard let process else {
            self.clear()
            return
        }
        
        self.labelView.stringValue = process.name
        for (i, field) in self.valueViews.enumerated() {
            field.stringValue = values.indices.contains(i) ? values[i] : ""
        }
        if self.pid != process.pid || self.imageView.image == nil {
            self.imageView.image = process.icon
        }
        self.pid = process.pid
        self.pidView?.stringValue = "\(process.pid)"
        self.killView.isEnabled = process.pid > 0
        if let usage {
            let value = usage.value.isFinite ? min(max(usage.value, 0), 1) : 0
            self.bar?.setValue(ColorValue(value, color: usage.color))
        } else {
            self.bar?.setValue(ColorValue(0))
        }
        self.bar?.toolTip = values.first
        self.toolTip = self.detailed ? "\(process.name) (PID: \(process.pid)) • \(values.joined(separator: ", "))" : "pid: \(process.pid)"
    }
    
    fileprivate func clear(_ symbol: String = "") {
        self.labelView.stringValue = symbol
        self.pidView?.stringValue = symbol
        self.valueViews.forEach({ $0.stringValue = symbol })
        self.bar?.setValue(ColorValue(0))
        self.bar?.toolTip = nil
        self.imageView.image = nil
        self.killView.isEnabled = false
        self.pid = nil
        self.setLock(false)
        self.toolTip = symbol
    }
    
    fileprivate func setLock(_ state: Bool) {
        self.lock = state && self.pid != nil
        self.imageView.isHidden = self.lock
        self.killView.isHidden = !self.lock
        self.needsDisplay = true
    }
    
    fileprivate func setColor(_ idx: Int, _ color: NSColor) {
        self.colorViews[idx]?.setColor(color)
    }
    
    @objc private func kill() {
        if let pid = self.pid, pid > 0 {
            _ = syncShell("kill -9 \(pid)")
            self.clear()
        }
    }
}
