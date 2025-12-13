//
//  popup.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 22/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

private struct Sensor_t: KeyValue_p {
    let key: String
    let name: String?
    
    var value: String
    var additional: Any?
    
    var index: Int {
        get { Store.shared.int(key: "sensors_\(self.key)_index", defaultValue: -1) }
        set { Store.shared.set(key: "sensors_\(self.key)_index", value: newValue) }
    }
    
    init(key: String, value: String, name: String? = nil) {
        self.key = key
        self.value = value
        self.name = name
    }
}

internal class Popup: PopupWrapper {
    private var list: [String: NSView] = [:]
    
    private var unknownSensorsState: Bool { Store.shared.bool(key: "Sensors_unknown", defaultValue: false) }
    private var fanValueState: FanValue = .percentage
    
    private var sensors: [Sensor_p] = []
    private let settingsView: NSStackView = NSStackView()
    
    private var fanControlState: Bool {
        get { Store.shared.bool(key: "Sensors_fanControl", defaultValue: true) }
        set { Store.shared.set(key: "Sensors_fanControl", value: newValue) }
    }
    
    public init() {
        super.init(ModuleType.sensors, frame: NSRect( x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.fanValueState = FanValue(rawValue: Store.shared.string(key: "Sensors_popup_fanValue", defaultValue: self.fanValueState.rawValue)) ?? .percentage
        
        self.orientation = .vertical
        self.spacing = 0
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.settingsView.orientation = .vertical
        self.settingsView.spacing = Constants.Settings.margin
        
        self.settingsView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Keyboard shortcut"), component: KeyboardShartcutView(
                callback: self.setKeyboardShortcut,
                value: self.keyboardShortcut
            ))
        ]))
        
        self.settingsView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Fan value"), component: selectView(
                action: #selector(self.toggleFanValue),
                items: FanValues,
                selected: self.fanValueState.rawValue
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func setup(_ values: [Sensor_p]? = nil, reload: Bool = false) {
        guard let values = reload ? self.sensors : values else { return }
        let fans = values.filter({ $0.type == .fan && $0.popupState })
        var sensors = values
        if !self.unknownSensorsState {
            sensors = sensors.filter({ $0.group != .unknown })
        }
        
        self.subviews.forEach({ $0.removeFromSuperview() })
        if !reload {
            self.settingsView.subviews.filter({ $0.identifier == NSUserInterfaceItemIdentifier("sensor") }).forEach { v in
                v.removeFromSuperview()
            }
        }
        
        if !fans.isEmpty {
            self.addArrangedSubview(self.fansSeparatorView())
            
            let container = NSStackView()
            container.orientation = .vertical
            container.spacing = Constants.Popup.spacing
            
            fans.forEach { (f: Sensor_p) in
                if let fan = f as? Fan {
                    if f.isComputed {
                        let sensor = SensorView(fan, width: self.frame.width, toggleable: false) {}
                        self.list[fan.key] = sensor
                        container.addArrangedSubview(sensor)
                    } else {
                        let view = FanView(fan, width: self.frame.width) { [weak self] in
                            let h = container.arrangedSubviews.map({ $0.bounds.height + container.spacing }).reduce(0, +) - container.spacing
                            if container.frame.size.height != h && h >= 0 {
                                container.setFrameSize(NSSize(width: container.frame.width, height: h))
                            }
                            self?.recalculateHeight()
                        }
                        self.list[fan.key] = view
                        container.addArrangedSubview(view)
                    }
                }
            }
            
            let h = container.arrangedSubviews.map({ $0.bounds.height + container.spacing }).reduce(0, +) - container.spacing
            if container.frame.size.height != h {
                container.setFrameSize(NSSize(width: container.frame.width, height: h))
            }
            self.addArrangedSubview(container)
        }
        
        var types: [SensorType] = []
        sensors.forEach { (s: Sensor_p) in
            if !types.contains(s.type) {
                types.append(s.type)
            }
        }
        
        types.forEach { (typ: SensorType) in
            var filtered = sensors.filter{ $0.type == typ }
            var groups: [SensorGroup] = []
            filtered.forEach { (s: Sensor_p) in
                if !groups.contains(s.group) {
                    groups.append(s.group)
                }
            }
            
            if !reload {
                let section = PreferencesSection(label: localizedString(typ.rawValue))
                section.identifier = NSUserInterfaceItemIdentifier("sensor")
                groups.forEach { (group: SensorGroup) in
                    filtered.filter{ $0.group == group }.forEach { (s: Sensor_p) in
                        let btn = switchView(
                            action: #selector(self.toggleSensor),
                            state: s.popupState
                        )
                        btn.identifier = NSUserInterfaceItemIdentifier(rawValue: s.key)
                        section.add(PreferencesRow(localizedString(s.name), component: btn))
                    }
                }
                self.settingsView.addArrangedSubview(section)
            }
            
            if typ == .fan { return }
            filtered = filtered.filter{ $0.popupState }
            if filtered.isEmpty { return }
            
            self.addArrangedSubview(separatorView(localizedString(typ.rawValue), width: self.frame.width))
            groups.forEach { (group: SensorGroup) in
                filtered.filter{ $0.group == group }.forEach { (s: Sensor_p) in
                    let sensor = SensorView(s, width: self.frame.width) { [weak self] in
                        self?.recalculateHeight()
                    }
                    self.addArrangedSubview(sensor)
                    self.list[s.key] = sensor
                }
            }
        }
        
        if !reload {
            self.sensors = values
        }
        self.recalculateHeight()
    }
    
    internal func usageCallback(_ values: [Sensor_p]) {
        DispatchQueue.main.async(execute: {
            values.filter({ $0 is Sensor }).forEach { (s: Sensor_p) in
                if let sensor = self.list[s.key] as? SensorView {
                    sensor.addHistoryPoint(s)
                }
            }
            
            if self.window?.isVisible ?? false {
                values.forEach { (s: Sensor_p) in
                    switch self.list[s.key] {
                    case let fan as FanView:
                        if let f = s as? Fan {
                            fan.update(f)
                        }
                    case let sensor as SensorView:
                        sensor.update(s)
                    case .none, .some:
                        break
                    }
                }
            }
        })
    }
    
    private func recalculateHeight() {
        let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        self.settingsView
    }
    
    @objc private func toggleFanValue(_ sender: NSMenuItem) {
        if let key = sender.representedObject as? String, let value = FanValue(rawValue: key) {
            self.fanValueState = value
            Store.shared.set(key: "Sensors_popup_fanValue", value: self.fanValueState.rawValue)
        }
    }
    
    // MARK: helpers
    
    private func fansSeparatorView() -> NSView {
        let view: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 26))
        view.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        view.orientation = .horizontal
        view.spacing = 0
        view.distribution = .fillEqually
        view.alignment = .top
        
        let labelView: NSTextField = TextView()
        labelView.stringValue = localizedString("Fans")
        labelView.alignment = .center
        labelView.textColor = .secondaryLabelColor
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        let btnContainer = NSView()
        
        let button = NSButton()
        button.frame = CGRect(x: (self.frame.width/3)-20, y: 10, width: 15, height: 15)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = NSImageScaling.scaleAxesIndependently
        button.contentTintColor = .lightGray
        button.action = #selector(self.toggleFanControl)
        button.target = self
        button.toolTip = localizedString("Control")
        button.image = Bundle(for: Module.self).image(forResource: "tune")!
        
        btnContainer.addSubview(button)
        
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(labelView)
        view.addArrangedSubview(btnContainer)
        
        return view
    }
    
    @objc private func toggleSensor(_ sender: NSControl) {
        guard let id = sender.identifier else { return }
        Store.shared.set(key: "sensor_\(id.rawValue)_popup", value: controlState(sender))
        self.setup(reload: true)
    }
    
    @objc private func toggleFanControl() {
        self.fanControlState = !self.fanControlState
        NotificationCenter.default.post(name: .toggleFanControl, object: nil, userInfo: ["state": self.fanControlState])
    }
}

// MARK: - Sensor view

internal class SensorView: NSStackView {
    public var sizeCallback: (() -> Void)
    
    private var valueView: ValueSensorView!
    private var chartView: ChartSensorView!
    
    private var openned: Bool = false
    
    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "Sensors_popup_fanValue", defaultValue: FanValue.percentage.rawValue)) ?? .percentage
    }
    
    public init(_ sensor: Sensor_p, width: CGFloat, toggleable: Bool = true, callback: @escaping (() -> Void)) {
        self.sizeCallback = callback
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        
        self.orientation = .vertical
        self.distribution = .fillProportionally
        self.spacing = 0
        
        self.valueView = ValueSensorView(sensor, width: width, toggleable: toggleable, callback: { [weak self] in
            self?.open()
        })
        self.chartView = ChartSensorView(width: width, suffix: sensor.unit)
        
        self.addArrangedSubview(self.valueView)
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: self.bounds.width)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ sensor: Sensor_p) {
        var value = sensor.formattedPopupValue
        if let fan = sensor as? Fan {
            value = self.fanValueState == .percentage ? "\(fan.percentage)%" : fan.formattedValue
        }
        self.valueView.update(value)
    }
    
    public func addHistoryPoint(_ sensor: Sensor_p) {
        self.chartView.update(sensor.localValue, sensor.unit)
    }
    
    private func open() {
        if self.openned {
            self.chartView.removeFromSuperview()
        } else {
            self.addArrangedSubview(self.chartView)
        }
        self.openned = !self.openned
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.sizeCallback()
    }
}

internal class ValueSensorView: NSStackView {
    public var callback: (() -> Void)
    
    private var labelView: LabelField = {
        let view = LabelField(frame: NSRect.zero)
        view.cell?.truncatesLastVisibleLine = true
        return view
    }()
    private var valueView: ValueField = ValueField(frame: NSRect.zero)
    
    private let isToggleable: Bool
    
    public init(_ sensor: Sensor_p, width: CGFloat, toggleable: Bool = true, callback: @escaping (() -> Void)) {
        self.callback = callback
        self.isToggleable = toggleable
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        
        self.wantsLayer = true
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.layer?.cornerRadius = 3
        
        self.labelView.stringValue = sensor.name
        self.labelView.toolTip = sensor.key
        self.valueView.stringValue = sensor.formattedValue
        
        self.addArrangedSubview(self.labelView)
        self.addArrangedSubview(self.valueView)
        
        if self.isToggleable {
            self.addTrackingArea(NSTrackingArea(
                rect: NSRect(x: 0, y: 0, width: self.frame.width, height: 22),
                options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
                owner: self,
                userInfo: nil
            ))
        }
        
        NSLayoutConstraint.activate([
            self.labelView.heightAnchor.constraint(equalToConstant: 16),
            self.widthAnchor.constraint(equalToConstant: self.bounds.width),
            self.heightAnchor.constraint(equalToConstant: self.bounds.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ value: String) {
        self.valueView.stringValue = value
    }
    
    override func mouseDown(with theEvent: NSEvent) {
        guard self.isToggleable else { return }
        self.callback()
    }
    
    public override func mouseEntered(with: NSEvent) {
        guard self.isToggleable else { return }
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.05)
    }
    
    public override func mouseExited(with: NSEvent) {
        guard self.isToggleable else { return }
        self.layer?.backgroundColor = .none
    }
}

internal class ChartSensorView: NSStackView {
    private var chart: LineChartView? = nil
    
    public init(width: CGFloat, suffix: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 60))
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.layer?.cornerRadius = 3
        
        self.chart = LineChartView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height), num: 120, scale: .linear)
        self.chart?.suffix = suffix
        
        if let view = self.chart {
            self.addArrangedSubview(view)
        }
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: self.bounds.width),
            self.heightAnchor.constraint(equalToConstant: self.bounds.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ value: Double, _ suffix: String) {
        if self.chart?.suffix != suffix {
            self.chart?.suffix = suffix
        }
        self.chart?.addValue(value/100)
    }
}

// MARK: - Fan view

internal class FanView: NSStackView {
    public var sizeCallback: (() -> Void)
    
    private var fan: Fan
    private var ready: Bool = false
    
    private var helperView: NSView? = nil
    private var controlView: NSView? = nil
    private var buttonsView: NSView? = nil
    
    private var valueField: NSTextField? = nil
    private var sliderValueField: NSTextField? = nil
    
    private var slider: NSSlider? = nil
    private var modeButtons: ModeButtons? = nil
    private var debouncer: DispatchWorkItem? = nil
    
    private var barView: NSView? = nil
    
    private var minBtn: NSButton? = nil
    private var maxBtn: NSButton? = nil
    
    private var speedState: Bool {
        Store.shared.bool(key: "Sensors_speed", defaultValue: false)
    }
    private var syncState: Bool {
        Store.shared.bool(key: "Sensors_fansSync", defaultValue: false)
    }
    private var speed: Double {
        get {
            if let v = self.fan.customSpeed, self.speedState {
                return Double(v)
            }
            return self.fan.value
        }
    }
    private var resetModeAfterSleep: Bool = false
    private var controlState: Bool
    private var fanValue: FanValue {
        FanValue(rawValue: Store.shared.string(key: "Sensors_popup_fanValue", defaultValue: FanValue.percentage.rawValue)) ?? .percentage
    }
    
    private var horizontalMargin: CGFloat {
        self.edgeInsets.top + self.edgeInsets.bottom + (self.spacing*CGFloat(self.arrangedSubviews.count))
    }

    public init(_ fan: Fan, width: CGFloat, callback: @escaping (() -> Void)) {
        self.fan = fan
        self.sizeCallback = callback
        self.controlState = Store.shared.bool(key: "Sensors_fanControl", defaultValue: true)
        
        let inset: CGFloat = 5
        super.init(frame: NSRect(x: 0, y: 0, width: width - (inset*2), height: 0))
        
        self.helperView = self.noHelper()
        self.controlView = self.control()
        self.buttonsView = self.mode()
        
        self.orientation = .vertical
        self.alignment = .centerX
        self.distribution = .fillProportionally
        self.spacing = 1
        self.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.nameAndSpeed()
        self.setupControls()
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeListener), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepListener), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.syncFanSpeed), name: .syncFansControl, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeHelperState), name: .fanHelperState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.controlCallback), name: .toggleFanControl, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleFanError), name: .fanControlError, object: nil)
        
        if let fanMode = self.fan.customMode, self.speedState && fanMode != FanMode.automatic {
            SMCHelper.shared.setFanMode(fan.id, mode: fanMode.rawValue)
            self.modeButtons?.setMode(FanMode(rawValue: fanMode.rawValue) ?? .automatic)
            
            self.setSpeed(value: Int(self.speed), then: {
                DispatchQueue.main.async {
                    self.sliderValueField?.textColor = .systemBlue
                }
            })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .syncFansControl, object: nil)
        NotificationCenter.default.removeObserver(self, name: .fanHelperState, object: nil)
        NotificationCenter.default.removeObserver(self, name: .fanControlError, object: nil)
        NotificationCenter.default.removeObserver(self, name: .toggleSettings, object: nil)
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (isDarkMode ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25) : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)).cgColor
    }
    
    private func nameAndSpeed() {
        let row: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 16))
        row.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        row.heightAnchor.constraint(equalToConstant: row.bounds.height).isActive = true
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 0
        
        let nameField: NSTextField = TextView()
        nameField.stringValue = self.fan.name
        nameField.toolTip = self.fan.key
        nameField.cell?.truncatesLastVisibleLine = true
        
        let value = self.fan.value
        let valueField: NSTextField = TextView()
        valueField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        valueField.alignment = .right
        valueField.stringValue = self.fanValue == .percentage ? "\(self.fan.percentage)%" : self.fan.formattedValue
        valueField.toolTip = "\(value)"
        
        let bar: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 8))
        bar.widthAnchor.constraint(equalToConstant: bar.bounds.width).isActive = true
        bar.heightAnchor.constraint(equalToConstant: bar.bounds.height).isActive = true
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        bar.layer?.borderColor = NSColor.quaternaryLabelColor.cgColor
        bar.layer?.borderWidth = 1
        bar.layer?.cornerRadius = 2
        
        let width: CGFloat = (bar.frame.width * CGFloat(self.fan.percentage < 0 ? 0 : self.fan.percentage)) / 100
        let barInner = NSView(frame: NSRect(x: 0, y: 0, width: width, height: bar.frame.height))
        barInner.wantsLayer = true
        barInner.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        
        bar.addSubview(barInner)
        
        row.addArrangedSubview(nameField)
        row.addArrangedSubview(bar)
        row.addArrangedSubview(valueField)
        
        self.valueField = valueField
        self.barView = barInner
        
        self.addArrangedSubview(row)
    }
    
    private func noHelper() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 30))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let container = NSStackView(frame: NSRect(x: 0, y: 4, width: view.frame.width, height: view.frame.height - 8))
        container.wantsLayer = true
        container.layer?.cornerRadius = 3
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.lightGray.cgColor
        container.orientation = .horizontal
        container.alignment = .centerY
        container.distribution = .fillProportionally
        container.spacing = 0
        
        let button: NSButton = NSButton(title: localizedString("Install fan helper"), target: nil, action: #selector(self.installHelper))
        button.isBordered = false
        button.target = self
        
        container.addArrangedSubview(button)
        view.addSubview(container)
        
        return view
    }
    
    private func mode() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 30))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let buttons = ModeButtons(frame: NSRect(
            x: 0,
            y: 4,
            width: view.frame.width,
            height: view.frame.height - 8
        ), mode: self.fan.mode)
        buttons.callback = { [weak self] (mode: FanMode) in
            if let fan = self?.fan, fan.mode != mode {
                self?.fan.mode = mode
                self?.fan.customMode = mode
                SMCHelper.shared.setFanMode(fan.id, mode: mode.rawValue)
            }
            DispatchQueue.main.async {
                self?.toggleControlView(mode == .forced)
            }
        }
        buttons.off = { [weak self] in
            if let fan = self?.fan {
                if self?.fan.mode != .forced {
                    self?.fan.mode = .forced
                    SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue)
                }
                SMCHelper.shared.setFanSpeed(fan.id, speed: 0)
                self?.fan.customSpeed = 0
            }
            DispatchQueue.main.async {
                self?.toggleControlView(false)
            }
        }
        buttons.turbo = { [weak self] in
            if let fan = self?.fan {
                if self?.fan.mode != .forced {
                    self?.fan.mode = .forced
                    SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue)
                }
                SMCHelper.shared.setFanSpeed(fan.id, speed: Int(fan.maxSpeed))
                self?.fan.customSpeed = Int(fan.maxSpeed)
            }
            DispatchQueue.main.async {
                self?.toggleControlView(false)
            }
        }
        
        view.addSubview(buttons)
        self.modeButtons = buttons
        
        return view
    }
    
    private func control() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 46))
        view.identifier = NSUserInterfaceItemIdentifier(rawValue: "control")
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let controls: NSStackView = NSStackView(frame: NSRect(x: 0, y: 14, width: view.frame.width, height: 30))
        controls.orientation = .horizontal
        controls.spacing = 0
        
        let slider: NSSlider = NSSlider(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        slider.minValue = 0  // Allow 0 RPM (off) via slider
        slider.maxValue = self.fan.maxSpeed
        slider.doubleValue = self.speed
        slider.isContinuous = true
        slider.action = #selector(self.sliderCallback)
        slider.target = self
        
        let levels: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 16))
        
        let minBtn: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 50, height: levels.frame.height))
        minBtn.title = "\(Int(self.fan.minSpeed))"
        minBtn.toolTip = localizedString("Min")
        minBtn.setButtonType(.toggle)
        minBtn.isBordered = false
        minBtn.target = self
        minBtn.state = .off
        minBtn.action = #selector(self.setMin)
        minBtn.wantsLayer = true
        minBtn.layer?.cornerRadius = 3
        minBtn.layer?.borderWidth = 1
        minBtn.layer?.borderColor = NSColor.lightGray.cgColor
        
        let valueField: NSTextField = TextView(frame: NSRect(x: 80, y: 0, width: levels.frame.width - 160, height: levels.frame.height))
        valueField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        valueField.textColor = .secondaryLabelColor
        valueField.alignment = .center
        
        let maxBtn: NSButton = NSButton(frame: NSRect(x: levels.frame.width - 50, y: 0, width: 50, height: levels.frame.height))
        maxBtn.title = "\(Int(self.fan.maxSpeed))"
        maxBtn.toolTip = localizedString("Max")
        maxBtn.setButtonType(.toggle)
        maxBtn.isBordered = false
        maxBtn.target = self
        maxBtn.state = .off
        maxBtn.wantsLayer = true
        maxBtn.action = #selector(self.setMax)
        maxBtn.layer?.cornerRadius = 3
        maxBtn.layer?.borderWidth = 1
        maxBtn.layer?.borderColor = NSColor.lightGray.cgColor
        
        controls.addArrangedSubview(slider)
        
        levels.addSubview(minBtn)
        levels.addSubview(valueField)
        levels.addSubview(maxBtn)
        
        view.addSubview(controls)
        view.addSubview(levels)
        
        self.slider = slider
        self.sliderValueField = valueField
        self.minBtn = minBtn
        self.maxBtn = maxBtn
        
        return view
    }
    
    private func toggleControlView(_ state: Bool) {
        guard let view = self.controlView else {
            return
        }
        
        if state {
            self.slider?.doubleValue = self.speed
            self.sliderValueField?.stringValue = "\(Int(self.speed)) RPM"
            if self.speedState {
                self.sliderValueField?.textColor = .systemBlue
            } else {
                self.sliderValueField?.textColor = .secondaryLabelColor
            }
            self.addArrangedSubview(view)
        } else {
            self.sliderValueField?.stringValue = ""
            self.sliderValueField?.textColor = .secondaryLabelColor
            self.minBtn?.state = .off
            self.maxBtn?.state = .off
            view.removeFromSuperview()
        }
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        self.setFrameSize(NSSize(width: self.frame.width, height: h + self.horizontalMargin))
        self.sizeCallback()
    }
    
    private func setSpeed(value: Int, then: @escaping () -> Void = {}) {
        self.sliderValueField?.stringValue = "\(value) RPM"
        self.sliderValueField?.textColor = .secondaryLabelColor
        self.fan.customSpeed = value
        
        self.debouncer?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                if let id = self?.fan.id {
                    SMCHelper.shared.setFanSpeed(id, speed: value)
                }
                then()
            }
        }
        
        self.debouncer = task
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3, execute: task)
    }
    
    @objc private func sliderCallback(_ sender: NSSlider) {
        var value = sender.doubleValue
        // Clamp to valid range: 0 (off) to maxSpeed
        if value > self.fan.maxSpeed {
            value = self.fan.maxSpeed
        } else if value < 0 {
            value = 0
        }

        self.minBtn?.state = .off
        self.maxBtn?.state = .off
        
        self.setSpeed(value: Int(value), then: {
            DispatchQueue.main.async {
                self.slider?.intValue = Int32(value)
                self.sliderValueField?.textColor = .systemBlue
            }
        })

        if sender.tag != 4 {
            if self.fan.maxSpeed > 0 {
                // Slider is now 0-maxSpeed, so percentage is simply value/maxSpeed
                let percentage = Int((100 * value) / self.fan.maxSpeed)
                NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["percentage": percentage])
            } else {
                NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["speed": Int(value)])
            }
        }
    }
    
    @objc func setMin(_ sender: NSButton) {
        self.slider?.doubleValue = self.fan.minSpeed
        self.maxBtn?.state = .off
        self.setSpeed(value: Int(self.fan.minSpeed))
        NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["speed": Int(self.fan.minSpeed)])
    }
    
    @objc func setMax(_ sender: NSButton) {
        self.slider?.doubleValue = self.fan.maxSpeed
        self.minBtn?.state = .off
        self.setSpeed(value: Int(self.fan.maxSpeed))
        NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["speed": Int(self.fan.maxSpeed)])
    }
    
    @objc private func wakeListener(aNotification: NSNotification) {
        // After wake, the system should be cool so keep fans in automatic mode
        // User can manually adjust if needed - no need to restore previous settings
        self.resetModeAfterSleep = true
    }
    
    @objc private func sleepListener(aNotification: NSNotification) {
        guard SMCHelper.shared.isActive() && self.fan.customMode != .automatic else { return }

        SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
        self.modeButtons?.setMode(.automatic)
    }
    
    @objc private func syncFanSpeed(_ notification: Notification) {
        guard self.syncState else { return }
        var speed = notification.userInfo?["speed"] as? Int
        if let percentage = notification.userInfo?["percentage"] as? Int {
            // Slider is now 0-maxSpeed
            speed = (Int(self.fan.maxSpeed) * percentage) / 100
        }

        guard let speed, self.fan.customSpeed != speed else { return }

        let slider = NSSlider()
        slider.tag = 4
        slider.maxValue = 30000
        slider.intValue = Int32(speed)

        self.sliderCallback(slider)
    }

    @objc private func handleFanError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fanId = userInfo["fanId"] as? Int,
              let message = userInfo["message"] as? String,
              fanId == self.fan.id else { return }

        // Show error to user on main thread
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = localizedString("Fan Control Error")
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    public func update(_ value: Fan) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.ready {
                self.fan.value = value.value
                
                var newValue = ""
                if value.value != 1 {
                    if self.fan.maxSpeed == 1 || self.fan.maxSpeed == 0 {
                        newValue = "\(Int(value.value)) RPM"
                    } else {
                        newValue = self.fanValue == .percentage ? "\(value.percentage)%" : value.formattedValue
                    }
                }
                
                self.valueField?.stringValue = newValue
                self.valueField?.toolTip = value.formattedValue
                
                if let v = self.barView {
                    let width: CGFloat = (80 * CGFloat(value.percentage < 0 ? 0 : value.percentage)) / 100
                    v.setFrameSize(NSSize(width: width, height: v.frame.height))
                }
                
                if self.resetModeAfterSleep && value.mode != .automatic {
                    if self.sliderValueField?.stringValue != "" && self.slider?.doubleValue != value.value {
                        self.slider?.doubleValue = value.value
                        self.sliderValueField?.stringValue = ""
                    }
                    self.modeButtons?.setMode(.forced)
                    self.resetModeAfterSleep = false
                }
                
                self.ready = true
            }
        })
    }
    
    @objc private func installHelper(_ sender: NSButton) {
        SMCHelper.shared.install { status in
            NotificationCenter.default.post(name: .fanHelperState, object: nil, userInfo: ["state": status])

            // Show error if installation failed
            if !status {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = localizedString("SMC Helper Installation Failed")
                    alert.informativeText = localizedString("Unable to install the privileged helper. Check Console.app for details.")
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    private func setupControls(_ isInstalled: Bool? = nil) {
        let helperState = isInstalled ?? SMCHelper.shared.isInstalled
        
        if !self.controlState {
            self.helperView?.removeFromSuperview()
            self.controlView?.removeFromSuperview()
            self.buttonsView?.removeFromSuperview()
        } else {
            if helperState {
                self.helperView?.removeFromSuperview()
                if self.fan.maxSpeed != self.fan.minSpeed, let v = self.buttonsView {
                    self.addArrangedSubview(v)
                }
                if self.fan.mode == .forced, let v = self.controlView {
                    self.addArrangedSubview(v)
                }
            } else {
                self.buttonsView?.removeFromSuperview()
                self.controlView?.removeFromSuperview()
                if let v = self.helperView {
                    self.addArrangedSubview(v)
                }
            }
        }
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        self.setFrameSize(NSSize(width: self.frame.width, height: h + self.horizontalMargin))
        self.sizeCallback()
    }
    
    @objc private func changeHelperState(_ notification: Notification) {
        guard let state = notification.userInfo?["state"] as? Bool else { return }
        self.setupControls(state)
    }
    
    @objc private func controlCallback(_ notification: Notification) {
        guard let state = notification.userInfo?["state"] as? Bool else { return }
        self.controlState = state
        self.setupControls()
    }
}

private class ModeButtons: NSStackView {
    public var callback: (FanMode) -> Void = {_ in }
    public var turbo: () -> Void = {}
    public var off: () -> Void = {}
    
    private var fansSyncState: Bool {
        Store.shared.bool(key: "Sensors_fansSync", defaultValue: false)
    }
    
    private var offBtn: NSButton
    private var autoBtn: NSButton = NSButton(title: localizedString("Automatic"), target: nil, action: #selector(autoMode))
    private var manualBtn: NSButton = NSButton(title: localizedString("Manual"), target: nil, action: #selector(manualMode))
    private var turboBtn: NSButton
    
    public init(frame: NSRect, mode: FanMode) {
        var turboIcon: NSImage = NSImage(named: NSImage.Name("ac_unit"))!
        var offIcon: NSImage = NSImage(named: NSImage.Name("ac_unit"))!
        if #available(macOS 12.0, *) {
            if let icon = iconFromSymbol(name: "snowflake", scale: .large) {
                turboIcon = icon
            }
            if let icon = iconFromSymbol(name: "fanblades.slash", scale: .medium) {
                offIcon = icon
            }
        }
        
        self.offBtn = NSButton(image: offIcon, target: nil, action: #selector(offMode))
        self.turboBtn = NSButton(image: turboIcon, target: nil, action: #selector(turboMode))
        
        super.init(frame: frame)
        
        self.orientation = .horizontal
        self.alignment = .centerY
        self.distribution = .fillProportionally
        self.spacing = 0
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        self.layer?.borderWidth = 1
        self.layer?.borderColor = NSColor.lightGray.cgColor
        
        let modes: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        modes.orientation = .horizontal
        modes.alignment = .centerY
        modes.distribution = .fillEqually
        
        self.autoBtn.setButtonType(.toggle)
        self.autoBtn.isBordered = false
        self.autoBtn.target = self
        self.autoBtn.state = mode == .automatic ? .on : .off
        
        self.manualBtn.setButtonType(.toggle)
        self.manualBtn.isBordered = false
        self.manualBtn.target = self
        self.manualBtn.state = mode == .forced ? .on : .off
        
        modes.addArrangedSubview(self.autoBtn)
        modes.addArrangedSubview(self.manualBtn)
        
        self.offBtn.setButtonType(.toggle)
        self.offBtn.isBordered = false
        self.offBtn.target = self
        
        self.turboBtn.setButtonType(.toggle)
        self.turboBtn.isBordered = false
        self.turboBtn.target = self
        
        NSLayoutConstraint.activate([
            self.offBtn.widthAnchor.constraint(equalToConstant: 26),
            self.offBtn.heightAnchor.constraint(equalToConstant: self.frame.height),
            self.turboBtn.widthAnchor.constraint(equalToConstant: 26),
            self.turboBtn.heightAnchor.constraint(equalToConstant: self.frame.height),
            modes.heightAnchor.constraint(equalToConstant: self.frame.height)
        ])
        
        self.addArrangedSubview(modes)
        self.addArrangedSubview(self.offBtn)
        self.addArrangedSubview(self.turboBtn)
        
        NotificationCenter.default.addObserver(self, selector: #selector(syncFanMode), name: .syncFansControl, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func autoMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.autoBtn.state = .on
            return
        }
        
        self.manualBtn.state = .off
        self.offBtn.state = .off
        self.turboBtn.state = .off
        self.callback(.automatic)
        
        NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["mode": "automatic"])
    }
    
    @objc private func manualMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.manualBtn.state = .on
            return
        }
        
        self.autoBtn.state = .off
        self.offBtn.state = .off
        self.turboBtn.state = .off
        self.callback(.forced)
        
        NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["mode": "forced"])
    }
    
    @objc private func offMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.offBtn.state = .on
            return
        }
        
        if !Store.shared.bool(key: "Sensors_turnOffFanAlert", defaultValue: false) {
            let alert = NSAlert()
            alert.messageText = localizedString("Turn off fan")
            alert.informativeText = localizedString("You are going to turn off the fan. This is not recommended action that can damage your mac, are you sure you want to do that?")
            alert.showsSuppressionButton = true
            alert.addButton(withTitle: localizedString("Turn off"))
            alert.addButton(withTitle: localizedString("Cancel"))
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let suppressionButton = alert.suppressionButton, suppressionButton.state == .on {
                    Store.shared.set(key: "Sensors_turnOffFanAlert", value: true)
                }
                self.toggleOffMode(sender)
            } else {
                self.offBtn.state = .off
            }
        } else {
            self.toggleOffMode(sender)
        }
    }
    
    private func toggleOffMode(_ sender: NSButton) {
        self.manualBtn.state = .off
        self.autoBtn.state = .off
        self.offBtn.state = .on
        self.turboBtn.state = .off
        self.off()
        
        if sender.tag != 4 {
            NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["mode": "off"])
        }
    }
    
    @objc private func turboMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.turboBtn.state = .on
            return
        }
        
        self.manualBtn.state = .off
        self.autoBtn.state = .off
        self.offBtn.state = .off
        self.turboBtn.state = .on
        self.turbo()
        
        if sender.tag != 4 {
            NotificationCenter.default.post(name: .syncFansControl, object: nil, userInfo: ["mode": "turbo"])
        }
    }
    
    @objc private func syncFanMode(_ notification: Notification) {
        guard let mode = notification.userInfo?["mode"] as? String, self.fansSyncState else {
            return
        }
        
        if mode == "automatic" {
            self.setMode(.automatic)
        } else if mode == "forced" {
            self.setMode(.forced)
        } else if mode == "off" {
            let btn = NSButton()
            btn.state = .on
            btn.tag = 4
            self.offMode(btn)
        } else if mode == "turbo" {
            let btn = NSButton()
            btn.state = .on
            btn.tag = 4
            self.turboMode(btn)
        }
    }
    
    public func setMode(_ mode: FanMode) {
        if mode == .automatic {
            self.autoBtn.state = .on
            self.manualBtn.state = .off
            self.offBtn.state = .off
            self.turboBtn.state = .off
            self.callback(.automatic)
        } else if mode == .forced {
            self.manualBtn.state = .on
            self.autoBtn.state = .off
            self.offBtn.state = .off
            self.turboBtn.state = .off
            self.callback(.forced)
        }
    }
}
