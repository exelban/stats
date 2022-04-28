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
// swiftlint:disable file_length

import Cocoa
import Kit

internal class Popup: NSStackView, Popup_p {
    private var list: [String: NSView] = [:]
    
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    public init() {
        super.init(frame: NSRect( x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.spacing = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func setup(_ values: [Sensor_p]?) {
        guard let fans = values?.filter({ $0.type == .fan }),
              let sensors = values?.filter({ $0.type != .fan }) else {
            return
        }
        
        self.subviews.forEach { (v: NSView) in
            v.removeFromSuperview()
        }
        
        if !fans.isEmpty {
            let container = NSStackView()
            container.orientation = .vertical
            container.spacing = Constants.Popup.margins
            
            fans.forEach { (f: Sensor_p) in
                if let fan = f as? Fan {
                    let view = FanView(fan, width: self.frame.width) { [weak self] in
                        let h = container.arrangedSubviews.map({ $0.bounds.height + container.spacing }).reduce(0, +) - container.spacing
                        if container.frame.size.height != h {
                            container.setFrameSize(NSSize(width: container.frame.width, height: h))
                        }
                        self?.recalculateHeight()
                    }
                    self.list[fan.key] = view
                    container.addArrangedSubview(view)
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
            let filtered = sensors.filter{ $0.type == typ }
            var groups: [SensorGroup] = []
            filtered.forEach { (s: Sensor_p) in
                if !groups.contains(s.group) {
                    groups.append(s.group)
                }
            }
            
            self.addArrangedSubview(separatorView(
                localizedString(typ.rawValue),
                width: self.frame.width
            ))
            
            groups.forEach { (group: SensorGroup) in
                filtered.filter{ $0.group == group }.forEach { (s: Sensor_p) in
                    let sensor = SensorView(s, width: self.frame.width)  { [weak self] in
                        self?.recalculateHeight()
                    }
                    self.addArrangedSubview(sensor)
                    self.list[s.key] = sensor
                }
            }
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
}

// MARK: - Sensor view

internal class SensorView: NSStackView {
    public var sizeCallback: (() -> Void)
    
    private var valueView: ValueSensorView!
    private var chartView: ChartSensorView!
    
    private var openned: Bool = false
    
    public init(_ sensor: Sensor_p, width: CGFloat, callback: @escaping (() -> Void)) {
        self.sizeCallback = callback
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        
        self.orientation = .vertical
        self.distribution = .fillProportionally
        self.spacing = 0
        
        self.valueView = ValueSensorView(sensor, width: width, callback: { [weak self] in
            self?.open()
        })
        self.chartView = ChartSensorView(width: width)
        
        self.addArrangedSubview(self.valueView)
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: self.bounds.width)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ sensor: Sensor_p) {
        self.valueView.update(sensor.formattedValue)
    }
    
    public func addHistoryPoint(_ sensor: Sensor_p) {
        self.chartView.update(sensor.value)
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
        let view = LabelField(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        view.cell?.truncatesLastVisibleLine = true
        return view
    }()
    private var valueView: ValueField = ValueField(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
    
    public init(_ sensor: Sensor_p, width: CGFloat, callback: @escaping (() -> Void)) {
        self.callback = callback
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
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: self.frame.width, height: 22),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
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
        self.callback()
    }
    
    public override func mouseEntered(with: NSEvent) {
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.05)
    }
    
    public override func mouseExited(with: NSEvent) {
        self.layer?.backgroundColor = .none
    }
}

internal class ChartSensorView: NSStackView {
    private var chart: LineChartView? = nil
    
    public init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 60))
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.layer?.cornerRadius = 3
        
        self.chart = LineChartView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height), num: 120)
        
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
    
    public func update(_ value: Double) {
        self.chart?.addValue(value/100)
    }
}

// MARK: - Fan view

internal class FanView: NSStackView {
    public var sizeCallback: (() -> Void)
    
    private var fan: Fan
    private var ready: Bool = false
    
    private var valueField: NSTextField? = nil
    private var sliderValueField: NSTextField? = nil
    
    private var slider: NSSlider? = nil
    private var controlView: NSView? = nil
    private var modeButtons: ModeButtons? = nil
    private var debouncer: DispatchWorkItem? = nil
    
    private var minBtn: NSButton? = nil
    private var maxBtn: NSButton? = nil
    
    private var speedState: Bool {
        get {
            return Store.shared.bool(key: "Sensors_speed", defaultValue: false)
        }
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
    
    private var horizontalMargin: CGFloat {
        get {
            return self.edgeInsets.top + self.edgeInsets.bottom + (self.spacing*CGFloat(self.arrangedSubviews.count))
        }
    }
    
    public init(_ fan: Fan, width: CGFloat, callback: @escaping (() -> Void)) {
        self.fan = fan
        self.sizeCallback = callback
        
        let inset: CGFloat = 5
        super.init(frame: NSRect(x: 0, y: 0, width: width - (inset*2), height: 0))
        
        self.controlView = self.control()
        
        self.orientation = .vertical
        self.alignment = .centerX
        self.distribution = .fillProportionally
        self.spacing = 1
        self.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.backgroundColor = NSColor.red.cgColor
        
        self.addArrangedSubview(self.nameAndSpeed())
        if self.fan.maxSpeed != self.fan.minSpeed {
            self.addArrangedSubview(self.mode())
        }
        
        if let view = self.controlView, fan.mode == .forced {
            self.addArrangedSubview(view)
        }
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        self.setFrameSize(NSSize(width: self.frame.width, height: h + self.horizontalMargin))
        self.sizeCallback()
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeListener), name: NSWorkspace.didWakeNotification, object: nil)
        
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
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    private func nameAndSpeed() -> NSView {
        let row: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 16))
        row.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        row.heightAnchor.constraint(equalToConstant: row.bounds.height).isActive = true
        row.orientation = .horizontal
        row.distribution = .fillProportionally
        row.spacing = 0
        
        let nameField: NSTextField = TextView()
        nameField.stringValue = self.fan.name
        nameField.toolTip = self.fan.key
        nameField.cell?.truncatesLastVisibleLine = true
        
        let value = self.fan.value
        var percentage = ""
        if value != 1 && self.fan.maxSpeed != 1 {
            percentage = "\((100*Int(value)) / Int(self.fan.maxSpeed))%"
        }
        
        let valueField: NSTextField = TextView()
        valueField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        valueField.stringValue = self.fan.formattedValue
        valueField.alignment = .right
        valueField.stringValue = percentage
        valueField.toolTip = "\(value)"
        
        row.addArrangedSubview(nameField)
        row.addArrangedSubview(valueField)
        
        self.valueField = valueField
        
        return row
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
            self?.toggleControlView(mode == .forced)
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
            self?.toggleControlView(false)
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
        slider.minValue = self.fan.minSpeed
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
            if self.speedState {
                self.setSpeed(value: Int(self.speed), then: {
                    DispatchQueue.main.async {
                        self.sliderValueField?.textColor = .systemBlue
                    }
                })
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
        let value = sender.doubleValue
        
        self.minBtn?.state = .off
        self.maxBtn?.state = .off
        
        self.setSpeed(value: Int(value), then: {
            DispatchQueue.main.async {
                self.sliderValueField?.textColor = .systemBlue
            }
        })
    }
    
    @objc func setMin(_ sender: NSButton) {
        self.slider?.doubleValue = self.fan.minSpeed
        self.maxBtn?.state = .off
        self.setSpeed(value: Int(self.fan.minSpeed))
    }
    
    @objc func setMax(_ sender: NSButton) {
        self.slider?.doubleValue = self.fan.maxSpeed
        self.minBtn?.state = .off
        self.setSpeed(value: Int(self.fan.maxSpeed))
    }
    
    @objc private func wakeListener(aNotification: NSNotification) {
        self.resetModeAfterSleep = true
        if let value = self.fan.customSpeed, self.fan.mode != .automatic {
            self.setSpeed(value: value)
        }
    }
    
    public func update(_ value: Fan) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.ready {
                self.fan.value = value.value
                
                var speed = ""
                if value.value != 1 {
                    if self.fan.maxSpeed == 1 || self.fan.maxSpeed == 0 {
                        speed = "\(Int(value.value)) RPM"
                    } else {
                        speed = "\((100*Int(value.value)) / Int(self.fan.maxSpeed))%"
                    }
                }
                
                self.valueField?.stringValue = speed
                self.valueField?.toolTip = value.formattedValue
                
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
}

private class ModeButtons: NSStackView {
    public var callback: (FanMode) -> Void = {_ in }
    public var turbo: () -> Void = {}
    
    private var autoBtn: NSButton = NSButton(title: localizedString("Automatic"), target: nil, action: #selector(autoMode))
    private var manualBtn: NSButton = NSButton(title: localizedString("Manual"), target: nil, action: #selector(manualMode))
    private var turboBtn: NSButton = NSButton(image: NSImage(named: NSImage.Name("ac_unit"))!, target: nil, action: #selector(turboMode))
    
    public init(frame: NSRect, mode: FanMode) {
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
        
        self.turboBtn.setButtonType(.toggle)
        self.turboBtn.isBordered = false
        self.turboBtn.target = self
        
        NSLayoutConstraint.activate([
            self.turboBtn.widthAnchor.constraint(equalToConstant: 26),
            self.turboBtn.heightAnchor.constraint(equalToConstant: self.frame.height),
            modes.heightAnchor.constraint(equalToConstant: self.frame.height)
        ])
        
        self.addArrangedSubview(modes)
        self.addArrangedSubview(self.turboBtn)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func autoMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.autoBtn.state = .on
            return
        }
        
        self.manualBtn.state = .off
        self.turboBtn.state = .off
        self.callback(.automatic)
    }
    
    @objc private func manualMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.manualBtn.state = .on
            return
        }
        
        self.autoBtn.state = .off
        self.turboBtn.state = .off
        self.callback(.forced)
    }
    
    @objc private func turboMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.turboBtn.state = .on
            return
        }
        
        self.manualBtn.state = .off
        self.autoBtn.state = .off
        self.turbo()
    }
    
    public func setMode(_ mode: FanMode) {
        if mode == .automatic {
            self.autoBtn.state = .on
            self.manualBtn.state = .off
            self.turboBtn.state = .off
            self.callback(.automatic)
        } else if mode == .forced {
            self.manualBtn.state = .on
            self.autoBtn.state = .off
            self.turboBtn.state = .off
            self.callback(.forced)
        }
    }
}
