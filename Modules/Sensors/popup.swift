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
            
            groups.reversed().forEach { (group: SensorGroup) in
                filtered.filter{ $0.group == group }.forEach { (s: Sensor_p) in
                    let (key, value) = popupRow(self, n: 0, title: "\(s.name):", value: s.formattedValue)
                    key.toolTip = s.key
                    self.list[s.key] = value
                }
            }
        }
        
        self.recalculateHeight()
    }
    
    // swiftlint:disable empty_enum_arguments
    internal func usageCallback(_ values: [Sensor_p]) {
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                values.forEach { (s: Sensor_p) in
                    switch self.list[s.key] {
                    case let fan as FanView:
                        if let f = s as? Fan {
                            fan.update(f)
                        }
                    case let sensors as NSTextField:
                        sensors.stringValue = s.formattedValue
                    case .none, .some(_):
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

internal class FanView: NSStackView {
    public var sizeCallback: (() -> Void)
    
    private var fan: Fan
    private var ready: Bool = false
    
    private var valueField: NSTextField? = nil
    private var percentageField: NSTextField? = nil
    private var sliderValueField: NSTextField? = nil
    
    private var slider: NSSlider? = nil
    private var controlView: NSView? = nil
    private var modeButtons: ModeButtons? = nil
    private var debouncer: DispatchWorkItem? = nil
    
    private var minBtn: NSButton? = nil
    private var maxBtn: NSButton? = nil
    
    private var speedState: Bool {
        get {
            return Store.shared.bool(key: "Fans_speed", defaultValue: false)
        }
    }
    private var speedValue: Int? {
        get {
            if !Store.shared.exist(key: "fan_\(self.fan.id)_speed") {
                return nil
            }
            return Store.shared.int(key: "fan_\(self.fan.id)_speed", defaultValue: Int(self.fan.minSpeed))
        }
        set {
            if let value = newValue {
                Store.shared.set(key: "fan_\(self.fan.id)_speed", value: value)
            } else {
                Store.shared.remove("fan_\(self.fan.id)_speed")
            }
        }
    }
    private var speed: Double {
        get {
            if let v = self.speedValue, self.speedState {
                return Double(v)
            }
            return self.fan.value
        }
    }
    private var resetModeAfterSleep: Bool = false
    
    public init(_ fan: Fan, width: CGFloat, callback: @escaping (() -> Void)) {
        self.fan = fan
        self.sizeCallback = callback
        
        let inset: CGFloat = 5
        super.init(frame: NSRect(x: 0, y: 0, width: width - (inset*2), height: 0))
        
        self.controlView = self.control()
        
        self.orientation = .vertical
        self.alignment = .centerX
        self.distribution = .fillProportionally
        self.spacing = 0
        self.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        self.layer?.backgroundColor = NSColor.red.cgColor
        
        self.addArrangedSubview(self.nameAndSpeed())
        self.addArrangedSubview(self.keyAndPercentage())
        self.addArrangedSubview(self.mode())
        
        if let view = self.controlView, fan.mode == .forced {
            self.addArrangedSubview(view)
        }
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +) + (inset*2)
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.sizeCallback()
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeListener), name: NSWorkspace.didWakeNotification, object: nil)
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
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 16))
        row.heightAnchor.constraint(equalToConstant: row.bounds.height).isActive = true
        
        let valueWidth: CGFloat = 80
        let nameField: NSTextField = TextView(frame: NSRect(
            x: 0,
            y: 0,
            width: row.frame.width - valueWidth,
            height: row.frame.height
        ))
        nameField.stringValue = self.fan.name
        nameField.cell?.truncatesLastVisibleLine = true
        
        let valueField: NSTextField = TextView(frame: NSRect(
            x: row.frame.width - valueWidth,
            y: 0,
            width: valueWidth,
            height: row.frame.height
        ))
        valueField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        valueField.stringValue = self.fan.formattedValue
        valueField.alignment = .right
        
        row.addSubview(nameField)
        row.addSubview(valueField)
        self.valueField = valueField
        
        return row
    }
    
    private func keyAndPercentage() -> NSView {
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 14))
        row.heightAnchor.constraint(equalToConstant: row.bounds.height).isActive = true
        
        let value = self.fan.value
        var percentage = ""
        if value != 1 && self.fan.maxSpeed != 1 {
            percentage = "\((100*Int(value)) / Int(self.fan.maxSpeed))%"
        }
        let percentageWidth: CGFloat = 40
        
        let keyField: NSTextField = TextView(frame: NSRect(
            x: 0,
            y: 0,
            width: row.frame.width - percentageWidth,
            height: row.frame.height
        ))
        keyField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        keyField.textColor = .secondaryLabelColor
        keyField.stringValue = "Fan #\(self.fan.id)"
        keyField.alignment = .left
        
        let percentageField: NSTextField = TextView(frame: NSRect(
            x: row.frame.width - percentageWidth,
            y: 0,
            width: percentageWidth,
            height: row.frame.height
        ))
        percentageField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        percentageField.textColor = .secondaryLabelColor
        percentageField.stringValue = percentage
        percentageField.alignment = .right
        
        row.addSubview(keyField)
        row.addSubview(percentageField)
        self.percentageField = percentageField
        
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
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +) + 10
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.sizeCallback()
    }
    
    private func setSpeed(value: Int, then: @escaping () -> Void = {}) {
        self.sliderValueField?.stringValue = "\(value) RPM"
        self.sliderValueField?.textColor = .secondaryLabelColor
        self.speedValue = value
        
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
    }
    
    public func update(_ value: Fan) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.ready {
                self.fan.value = value.value
                
                var percentage = ""
                if value.value != 1 && self.fan.maxSpeed != 1 {
                    percentage = "\((100*Int(value.value)) / Int(self.fan.maxSpeed))%"
                }
                
                self.percentageField?.stringValue = percentage
                self.valueField?.stringValue = value.formattedValue
                
                if self.resetModeAfterSleep && value.mode != .automatic {
                    if self.sliderValueField?.stringValue != "" && self.slider?.doubleValue != value.value {
                        self.slider?.doubleValue = value.value
                        self.sliderValueField?.stringValue = ""
                    }
                    self.modeButtons?.setManualMode()
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
    
    public func setManualMode() {
        self.manualBtn.state = .on
        self.autoBtn.state = .off
        self.turboBtn.state = .off
        self.callback(.forced)
    }
}
