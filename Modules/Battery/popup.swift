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
    private var detailsHeight: CGFloat = (22 * 3) + Constants.Popup.separatorHeight
    private let batteryHeight: CGFloat = (22 * 7) + Constants.Popup.separatorHeight
    private let adapterHeight: CGFloat = (22 * 4) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = 22
    
    private var dashboardBatteryView: BatteryView = BatteryView()
    private var dashboardBatteryStatus: BatteryStatus = BatteryStatus()
    private var adapterView: NSView? = nil
    private var processesView: NSView? = nil
    
    private var levelField: NSTextField? = nil
    private var sourceField: NSTextField? = nil
    private var timeLabelField: NSTextField? = nil
    private var timeField: NSTextField? = nil
    private var healthField: NSTextField? = nil
    private var capacityField: NSTextField? = nil
    private var cyclesField: NSTextField? = nil
    private var lastChargeField: NSTextField? = nil
    
    private var amperageField: NSTextField? = nil
    private var voltageField: NSTextField? = nil
    private var batteryPowerField: NSTextField? = nil
    private var temperatureField: NSTextField? = nil
    
    private var powerField: NSTextField? = nil
    private var chargingStateField: NSTextField? = nil
    private var chargingCurrentField: NSTextField? = nil
    private var chargingVoltageField: NSTextField? = nil
    
    private var processes: ProcessesView? = nil
    private var processesInitialized: Bool = false
    
    private let usageCache = PopupCache<Battery_Usage>()
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (self.processHeight*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
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
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.sourceField = popupRow(container, title: "\(localizedString("Source")):", value: "").1
        let t = self.labelValue(container, title: "\(localizedString("Time")):", value: "")
        self.timeLabelField = t.0
        self.timeField = t.1
        self.lastChargeField = popupRow(container, title: "\(localizedString("Last charge")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initBattery() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.batteryHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Battery"), origin: NSPoint(x: 0, y: self.batteryHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.healthField = popupRow(container, title: "\(localizedString("Health")):", value: "").1
        self.capacityField = popupRow(container, title: "\(localizedString("Capacity")):", value: "").1
        self.capacityField?.toolTip = localizedString("current / maximum / designed")
        self.cyclesField = popupRow(container, title: "\(localizedString("Cycles")):", value: "").1
        
        self.temperatureField = popupRow(container, title: "\(localizedString("Temperature")):", value: "").1
        self.batteryPowerField = popupRow(container, title: "\(localizedString("Power")):", value: "").1
        self.amperageField = popupRow(container, title: "\(localizedString("Current")):", value: "").1
        self.voltageField = popupRow(container, title: "\(localizedString("Voltage")):", value: "").1
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initAdapter() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.adapterHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Power adapter"), origin: NSPoint(x: 0, y: self.adapterHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: separator.frame.origin.y))
        container.orientation = .vertical
        container.spacing = 0
        
        self.chargingStateField = popupRow(container, title: "\(localizedString("Is charging")):", value: "").1
        self.powerField = popupRow(container, title: "\(localizedString("Power")):", value: "").1
        self.chargingCurrentField = popupRow(container, title: "\(localizedString("Current")):", value: "").1
        self.chargingVoltageField = popupRow(container, title: "\(localizedString("Voltage")):", value: "").1
        
        self.adapterView = view
        
        view.addSubview(separator)
        view.addSubview(container)
        
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
    
    private func labelValue(_ view: NSView, title: String, value: String) -> (NSTextField, NSTextField) {
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 22))
        
        let labelView: LabelField = LabelField(frame: NSRect(x: 0, y: (22-15)/2, width: view.frame.width/2, height: 15), title)
        let valueView: ValueField = ValueField(frame: NSRect(x: view.frame.width/2, y: (22-16)/2, width: view.frame.width/2, height: 16), value)
        
        rowView.addSubview(labelView)
        rowView.addSubview(valueView)
        
        if let view = view as? NSStackView {
            rowView.heightAnchor.constraint(equalToConstant: rowView.bounds.height).isActive = true
            view.addArrangedSubview(rowView)
        } else {
            view.addSubview(rowView)
        }
        
        return (labelView, valueView)
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
        self.timeField?.stringValue = ""
        
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
        }
        
        if value.timeToEmpty == -1 || value.timeToCharge == -1 {
            self.timeField?.stringValue = localizedString("Calculating")
        }
        
        if value.isCharged {
            self.timeField?.stringValue = localizedString("Fully charged")
        }
        
        self.healthField?.stringValue = "\(value.health)%"
        self.capacityField?.stringValue = "\(value.currentCapacity) / \(value.maxCapacity) / \(value.designedCapacity) mAh"
        
        if let state = value.state {
            self.healthField?.stringValue += " (\(state))"
        }
        self.cyclesField?.stringValue = "\(value.cycles)"
        
        let form = DateComponentsFormatter()
        form.maximumUnitCount = 2
        form.unitsStyle = .full
        form.allowedUnits = [.day, .hour, .minute]
        if let timestamp = value.timeOnACPower {
            if let duration = form.string(from: timestamp, to: Date()) {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .medium
                
                self.lastChargeField?.stringValue = duration
                self.lastChargeField?.toolTip = formatter.string(from: timestamp)
            } else {
                self.lastChargeField?.stringValue = localizedString("Unknown")
                self.lastChargeField?.toolTip = localizedString("Unknown")
            }
        } else {
            self.lastChargeField?.stringValue = localizedString("Unknown")
            self.lastChargeField?.toolTip = localizedString("Unknown")
        }
        
        self.amperageField?.stringValue = "\(abs(value.amperage)) mA"
        self.voltageField?.stringValue = "\(value.voltage.roundTo(decimalPlaces: 2)) V"
        let batteryPower = value.voltage * (Double(abs(value.amperage))/1000)
        self.batteryPowerField?.stringValue = "\(batteryPower.roundTo(decimalPlaces: 2)) W"
        self.temperatureField?.stringValue = temperature(value.temperature)
        
        self.powerField?.stringValue = value.isBatteryPowered ? localizedString("Not connected") : "\(value.ACwatts) W"
        self.chargingStateField?.stringValue = value.isCharging ? localizedString("Yes") : localizedString("No")
        self.chargingCurrentField?.stringValue = value.isBatteryPowered ? localizedString("Not connected") : "\(value.chargingCurrent) mA"
        self.chargingVoltageField?.stringValue = value.isBatteryPowered ? localizedString("Not connected") : "\(value.chargingVoltage) mV"
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
        
        let innerHeight: CGFloat = h-14
        let minWidth: CGFloat = 8
        let track: CGFloat = w-20
        var fillWidth: CGFloat = 0
        if self.percentage > 0 {
            fillWidth = minWidth + (track - minWidth) * CGFloat(self.percentage)
        }
        let fillRadius: CGFloat = Swift.min(10, fillWidth/2, innerHeight/2)
        let inner = NSBezierPath(roundedRect: NSRect(
            x: x+7,
            y: y+7,
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
        if value.isBatteryPowered {
            self.icon?.isHidden = true
            self.field?.textColor = value.level > 0.15 ? .systemGray : .systemRed
            self.field?.stringValue = localizedString("On Battery")
            self.view?.layer?.backgroundColor = (value.level > 0.15 ? NSColor.systemGray : NSColor.systemRed).withAlphaComponent(0.18).cgColor
            return
        }
        
        self.icon?.isHidden = false
        self.icon?.contentTintColor = .systemGreen
        self.field?.textColor = .systemGreen
        self.view?.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.18).cgColor
        
        if !value.isCharging && value.isCharged && value.level >= 1 {
            self.field?.stringValue = localizedString("Plugged In")
        } else {
            self.field?.stringValue = localizedString("Charging")
        }
    }
}
