//
//  popup.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private let dashboardHeight: CGFloat = 160
    
    private var dashboardBatteryView: BatteryView = BatteryView()
    private var dashboardBatteryStatus: BatteryStatus = BatteryStatus()
    private var levelField: NSTextField? = nil
    
    private var sourceField: NSTextField? = nil
    private var timeLabelField: NSTextField? = nil
    private var timeField: NSTextField? = nil
    private var powerField: NSTextField? = nil
    private var currentField: NSTextField? = nil
    private var voltageField: NSTextField? = nil
    
    private var barView: BarChartView = BarChartView(size: 10, horizontal: true)
    private var maxCapacityField: NSTextField? = nil
    private var designedCapacityField: NSTextField? = nil
    private var healthField: NSTextField? = nil
    private var cyclesField: NSTextField? = nil
    private var temperatureField: NSTextField? = nil
    
    private var adapterView: NSView? = nil
    private var chargingStateField: StatusBadgeView? = nil
    private var adapterPowerField: NSTextField? = nil
    private var chargingCurrentField: NSTextField? = nil
    private var chargingVoltageField: NSTextField? = nil
    
    private var processesView: NSView? = nil
    private var processes: ProcessesView? = nil
    private var processesInitialized: Bool = false
    
    private let usageCache = PopupCache<Battery_Usage>()
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (Constants.Popup.processHeight*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    private var timeFormat: String {
        Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: "short")
    }
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.spacing = 0
        self.orientation = .vertical
        
        self.addArrangedSubview(self.initDashboard())
        self.addArrangedSubview(self.initDetails())
        self.addArrangedSubview(self.initBattery())
        self.addArrangedSubview(self.initProcesses())
        
        self.recalculateHeight()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func appear() {
        self.replay(self.usageCache, render: self.renderUsage)
    }
    
    public override func disappear() {
        self.processes?.setLock(false)
    }
    
    private func recalculateHeight() {
        var h: CGFloat = 0
        self.arrangedSubviews.forEach { v in
            if let v = v as? NSStackView {
                h += v.arrangedSubviews.map({ $0.fittingSize.height }).reduce(0, +)
            } else {
                h += v.fittingSize.height
            }
        }
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    private func initDashboard() -> NSView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.dashboardHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        view.orientation = .vertical
        view.spacing = 0
        
        self.dashboardBatteryView.heightAnchor.constraint(equalToConstant: 90).isActive = true
        
        let information = NSStackView()
        information.heightAnchor.constraint(equalToConstant: 70).isActive = true
        information.orientation = .vertical
        information.spacing = 2
        
        var level: NSStackView {
            let view = NSStackView()
            view.orientation = .horizontal
            view.alignment = .firstBaseline
            view.spacing = -2
            view.distribution = .fill
            view.setHuggingPriority(.defaultLow, for: .horizontal)
            
            let value: NSTextField = ValueField("100")
            value.font = .systemFont(ofSize: 28, weight: .medium)
            value.textColor = .labelColor
            self.levelField = value
            
            let percentage: NSTextField = LabelField("%")
            percentage.font = .systemFont(ofSize: 16, weight: .medium)
            percentage.textColor = .tertiaryLabelColor
            
            let leftSpacer = NSView()
            let rightSpacer = NSView()
            
            view.addArrangedSubview(leftSpacer)
            view.addArrangedSubview(value)
            view.addArrangedSubview(percentage)
            view.addArrangedSubview(rightSpacer)
            
            leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true
            
            return view
        }
        
        information.addArrangedSubview(level)
        information.addArrangedSubview(self.dashboardBatteryStatus)
        
        view.addArrangedSubview(self.dashboardBatteryView)
        view.addArrangedSubview(information)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.spacing = 0
        view.addArrangedSubview(SeparatorView(label: localizedString("Details")))
        
        self.sourceField = popupRow(view, title: "\(localizedString("Source")):", value: localizedString("Unknown")).1
        
        let time = popupRow(view, title: "\(localizedString("Time to discharge")):", value: localizedString("Unknown"))
        self.timeLabelField = time.0
        self.timeField = time.1
        
        self.powerField = popupRow(view, title: "\(localizedString("Power")):", value: "0 W").1
        self.currentField = popupRow(view, title: "\(localizedString("Current")):", value: "0 mA").1
        self.voltageField = popupRow(view, title: "\(localizedString("Voltage")):", value: "0 V").1
        
        return view
    }
    
    private func initBattery() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.spacing = 0
        view.addArrangedSubview(SeparatorView(label: localizedString("Battery")))
        
        let health: NSStackView = {
            let view = NSStackView()
            view.orientation = .vertical
            view.spacing = 8
            view.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
            
            let capacity: NSStackView = {
                let row = NSStackView()
                row.orientation = .horizontal
                row.distribution = .fill
                row.spacing = 0
                
                let max = LabelField("Max capacity", size: 10)
                max.textColor = .tertiaryLabelColor
                let designed = LabelField("Designed capacity", size: 10)
                designed.textColor = .tertiaryLabelColor
                
                self.maxCapacityField = max
                self.designedCapacityField = designed
                
                row.addArrangedSubview(max)
                row.addArrangedSubview(NSView())
                row.addArrangedSubview(designed)
                
                return row
            }()
            
            view.addArrangedSubview(capacity)
            view.addArrangedSubview(self.barView)
            
            return view
        }()
        
        view.addArrangedSubview(health)
        
        self.healthField = popupRow(view, title: "\(localizedString("Health")):", value: "").1
        self.cyclesField = popupRow(view, title: "\(localizedString("Cycles")):", value: "").1
        self.temperatureField = popupRow(view, title: "\(localizedString("Temperature")):", value: "").1
        
        return view
    }
    
    private func initAdapter() -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        view.orientation = .vertical
        view.spacing = 0
        view.addArrangedSubview(SeparatorView(label: localizedString("Power adapter")))
        
        self.chargingStateField = popupBadgeRow(view, title: "\(localizedString("Is charging")):", ok: "Yes", notOk: "No").1
        self.adapterPowerField = popupRow(view, title: "\(localizedString("Power")):", value: "").1
        
        self.adapterView = view
        
        return view
    }
    
    private func initProcesses() -> NSView {
        if self.numberOfProcesses == 0 { return NSView() }
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: ProcessesView = ProcessesView(
            frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y),
            values: [(localizedString("Usage"), nil)],
            n: self.numberOfProcesses
        )
        self.processes = container
        
        view.addSubview(separator)
        view.addSubview(container)
        
        self.processesView = view
        return view
    }
    
    public func usageCallback(_ value: Battery_Usage) {
        self.apply(value, to: self.usageCache, render: self.renderUsage)
    }
    
    private func renderUsage(_ value: Battery_Usage) {
        self.dashboardBatteryView.setValue(abs(value.level), connected: !value.isBatteryPowered, charging: value.isCharging)
        self.dashboardBatteryStatus.set(value)
        
        self.levelField?.stringValue = "\(Int(abs(value.level) * 100))"
        self.levelField?.toolTip = "\(value.currentCapacity) mAh"
        
        self.sourceField?.stringValue = localizedString(value.powerSource)
        
        if value.isBatteryPowered {
            self.timeLabelField?.stringValue = "\(localizedString("Time to discharge")):"
            if value.timeToEmpty != -1 && value.timeToEmpty != 0 {
                self.timeField?.stringValue = Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds(short: self.timeFormat == "short")
            } else {
                self.timeField?.stringValue = localizedString("Unknown")
            }
            
            if self.adapterView != nil {
                self.adapterView?.removeFromSuperview()
                self.adapterView = nil
                self.recalculateHeight()
            }
            
            self.powerField?.stringValue = "\(abs(value.batteryPower).roundTo(decimalPlaces: 2)) W"
            self.currentField?.stringValue = "\(abs(value.current)) mA"
            self.voltageField?.stringValue = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
        } else {
            self.timeLabelField?.stringValue = "\(localizedString("Time to charge")):"
            if value.timeToCharge != -1 && value.timeToCharge != 0 {
                self.timeField?.stringValue = Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds(short: self.timeFormat == "short")
            } else {
                self.timeField?.stringValue = localizedString("Unknown")
            }
            
            if self.adapterView == nil {
                self.insertArrangedSubview(self.initAdapter(), at: 3)
                self.recalculateHeight()
            }
            
            let current = value.adapterVoltage > 0 ? Int((value.adapterPower / value.adapterVoltage) * 1000) : 0
            self.powerField?.stringValue = "\(value.adapterPower.roundTo(decimalPlaces: 2)) W"
            self.currentField?.stringValue = "\(current) mA"
            self.voltageField?.stringValue = "\(value.adapterVoltage.roundTo(decimalPlaces: 2)) V"
            
            self.chargingStateField?.setStatus(value.isCharging)
            self.adapterPowerField?.stringValue = "\(value.ACwatts) W"
        }
        
        if value.timeToEmpty == -1 || value.timeToCharge == -1 {
            self.timeField?.stringValue = localizedString("Calculating")
        }
        if value.isCharged {
            self.timeField?.stringValue = localizedString("Fully charged")
        } else if value.optimizedChargingEngaged {
            self.timeField?.stringValue = localizedString("On hold")
        }
        
        self.barView.setValue(ColorValue(Double(value.health)/100, color: .systemGreen))
        self.maxCapacityField?.stringValue = localizedString("Max capacity", "\(value.maxCapacity)")
        self.designedCapacityField?.stringValue = localizedString("Designed capacity", "\(value.designedCapacity)")
        
        self.healthField?.stringValue = "\(value.health)%"
        self.cyclesField?.stringValue = "\(value.cycles)"
        self.temperatureField?.stringValue = temperature(value.temperature)
    }
    
    public func processCallback(_ list: [TopProcess]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.processesInitialized {
                return
            }
            let list = list.map { $0 }
            if list.count != self.processes?.count { self.processes?.clear() }
            
            for i in 0..<list.count {
                let process = list[i]
                self.processes?.set(i, process, ["\(process.usage)%"])
            }
            
            self.processesInitialized = true
        })
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes?.count == self.numberOfProcesses { return }
        
        DispatchQueue.main.async(execute: {
            self.processesView?.removeFromSuperview()
            self.processesView = nil
            self.processes = nil
            self.addArrangedSubview(self.initProcesses())
            self.processesInitialized = false
            self.recalculateHeight()
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Keyboard shortcut"), component: KeyboardShartcutView(
                callback: self.setKeyboardShortcut,
                value: self.keyboardShortcut
            ))
        ]))
        
        return view
    }
}

internal class BatteryView: NSView {
    private var percentage: Double = 0
    private var connected: Bool = false
    private var charging: Bool = false
    
    public override init(frame: NSRect = NSRect.zero) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let w: CGFloat = min(self.frame.width, 130)
        let h: CGFloat = min(self.frame.height, 60)
        let x: CGFloat = (self.frame.width - w)/2
        let y: CGFloat = (self.frame.size.height - h) / 2
        let batteryFrame = NSBezierPath(roundedRect: NSRect(x: x+1, y: y+1, width: w-8, height: h-2), xRadius: 16, yRadius: 16)
        
        NSColor.secondaryLabelColor.set()
        
        let bPX: CGFloat = batteryFrame.bounds.origin.x + batteryFrame.bounds.width
        let bPY: CGFloat = batteryFrame.bounds.origin.y + (batteryFrame.bounds.height/2) - 12
        let batteryPoint = NSBezierPath(roundedRect: NSRect(x: bPX, y: bPY, width: 7, height: 24), xRadius: 6, yRadius: 6)
        batteryPoint.fill()
        
        let batteryPointSeparator = NSBezierPath()
        batteryPointSeparator.move(to: CGPoint(x: bPX, y: batteryFrame.bounds.origin.y))
        batteryPointSeparator.line(to: CGPoint(x: bPX, y: batteryFrame.bounds.origin.y + batteryFrame.bounds.height))
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        NSColor.textColor.set()
        batteryPointSeparator.lineWidth = 6
        batteryPointSeparator.stroke()
        ctx.restoreGState()
        
        batteryFrame.lineWidth = 2
        batteryFrame.stroke()
        
        if self.percentage == 0 {
            return
        }
        
        let innerHeight: CGFloat = h-10
        let minWidth: CGFloat = 8
        let track: CGFloat = w-16
        var fillWidth: CGFloat = 0
        if self.percentage > 0 {
            fillWidth = minWidth + (track - minWidth) * CGFloat(self.percentage)
        }
        let fillRadius: CGFloat = Swift.min(12, fillWidth/2, innerHeight/2)
        let inner = NSBezierPath(roundedRect: NSRect(
            x: x+5,
            y: y+5,
            width: fillWidth,
            height: innerHeight
        ), xRadius: fillRadius, yRadius: fillRadius)
        self.percentage.batteryColorV2().set()
        inner.lineWidth = 0
        inner.stroke()
        inner.close()
        inner.fill()
        
        if self.connected {
            let center = CGPoint(
                x: batteryFrame.bounds.origin.x + (batteryFrame.bounds.width/2),
                y: batteryFrame.bounds.origin.y + (batteryFrame.bounds.height/2)
            )
            let symbolName: String = self.charging ? "bolt.fill" : "powerplug.fill"
            
            if self.percentage > 0.55 {
                guard let body = self.coloredSymbol(symbolName, color: .white) else { return }
                let size: NSSize = body.size
                body.draw(in: NSRect(x: center.x - (size.width/2), y: center.y - (size.height/2), width: size.width, height: size.height))
                return
            }
            
            guard let outline = self.coloredSymbol(symbolName, color: .black),
                  let body = self.coloredSymbol(symbolName, color: self.percentage.batteryColorV2()) else { return }
            
            let size: NSSize = body.size
            let border: CGFloat = 2
            let origin = CGPoint(x: center.x - (size.width/2), y: center.y - (size.height/2))
            
            let steps: Int = 24
            for i in 0..<steps {
                let angle: CGFloat = (CGFloat(i) / CGFloat(steps)) * 2 * .pi
                outline.draw(in: NSRect(
                    x: origin.x + (cos(angle) * border),
                    y: origin.y + (sin(angle) * border),
                    width: size.width,
                    height: size.height
                ), from: .zero, operation: .destinationOut, fraction: 1.0)
            }
            body.draw(in: NSRect(origin: origin, size: size))
        }
    }
    
    public func setValue(_ value: Double, connected: Bool, charging: Bool) {
        if self.percentage == value && self.connected == connected && self.charging == charging { return }
        
        self.percentage = value
        self.connected = connected
        self.charging = charging
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    private func coloredSymbol(_ name: String, color: NSColor) -> NSImage? {
        var config = NSImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        config = config.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        image?.isTemplate = false
        return image
    }
}

internal class BatteryStatus: NSStackView {
    private var view: NSView? = nil
    private var icon: NSImageView? = nil
    private var field: NSTextField? = nil
    
    public override init(frame: NSRect = NSRect.zero) {
        super.init(frame: frame)
        
        self.orientation = .horizontal
        self.alignment = .firstBaseline
        self.spacing = 0
        self.distribution = .fill
        self.setHuggingPriority(.defaultLow, for: .horizontal)
        
        let block = NSStackView()
        block.orientation = .horizontal
        block.alignment = .centerY
        block.spacing = 4
        block.translatesAutoresizingMaskIntoConstraints = false
        block.wantsLayer = true
        block.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.18).cgColor
        block.layer?.cornerRadius = 8
        block.edgeInsets = NSEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)
        self.view = block
        
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: localizedString("Unknown"))
        icon.contentTintColor = .systemGray
        icon.symbolConfiguration = .init(pointSize: 10, weight: .bold)
        icon.isHidden = true
        self.icon = icon
        
        let label = NSTextField(labelWithString: localizedString("Unknown"))
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .systemGray
        self.field = label
        
        block.addArrangedSubview(icon)
        block.addArrangedSubview(label)
        
        let leftSpacer = NSView()
        let rightSpacer = NSView()
        
        self.addArrangedSubview(leftSpacer)
        self.addArrangedSubview(block)
        self.addArrangedSubview(rightSpacer)
        
        leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func set(_ value: Battery_Usage) {
        var text: String = localizedString("Charging")
        var color: NSColor = .systemGreen
        var symbol: String = "bolt.fill"
        
        if value.isBatteryPowered {
            text = localizedString("On battery")
            color = value.level > 0.15 ? .systemGray : .systemRed
        } else if !value.isCharging {
            if value.isCharged && value.level >= 1 {
                text = localizedString("Plugged in")
                symbol = "powerplug.fill"
            } else if value.optimizedChargingEngaged {
                text = localizedString("On hold")
                color = .systemGray
                symbol = "powerplug.fill"
            }
        }
        
        self.icon?.isHidden = value.isBatteryPowered
        self.icon?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        self.icon?.contentTintColor = color
        self.field?.textColor = color
        self.field?.stringValue = text
        self.view?.layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
    }
}
