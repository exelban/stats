//
//  settings.swift
//  Fans
//
//  Created by Serhiy Mytrovtsiy on 21/10/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSStackView, Popup_p {
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    private var list: [Int: FanView] = [:]
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.margins
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func setup(_ values: [Fan]) {
        values.forEach { (f: Fan) in
            let view = FanView(f, width: self.frame.width, callback: self.recalculateHeight)
            self.list[f.id] = view
            self.addArrangedSubview(view)
        }
        
        self.recalculateHeight()
    }
    
    internal func usageCallback(_ values: [Fan]) {
        DispatchQueue.main.async(execute: {
            if self.window?.isVisible ?? false {
                values.forEach { (f: Fan) in
                    if self.list[f.id] != nil {
                        self.list[f.id]?.update(f)
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
    private var debouncer: DispatchWorkItem? = nil
    
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
        self.edgeInsets = NSEdgeInsets(
            top: inset,
            left: inset,
            bottom: inset,
            right: inset
        )
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        let percentage = "\((100*Int(value)) / Int(self.fan.maxSpeed))%"
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
            self?.fan.mode = mode
            if let fan = self?.fan {
                SMC.shared.setFanMode(fan.id, mode: mode)
            }
            self?.toggleMode()
        }
        
        let rootBtn: NSButton = NSButton(frame: NSRect(x: 0, y: 4, width: view.frame.width, height: view.frame.height - 8))
        rootBtn.title = "Control fan (root required)"
        rootBtn.setButtonType(.momentaryLight)
        rootBtn.isBordered = false
        rootBtn.target = self
        rootBtn.action = #selector(self.askForRoot)
        rootBtn.wantsLayer = true
        rootBtn.layer?.cornerRadius = 3
        rootBtn.layer?.borderWidth = 1
        rootBtn.layer?.borderColor = NSColor.lightGray.cgColor
        
        view.addSubview(isRoot() ? buttons : rootBtn)
        
        return view
    }
    
    private func control() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 44))
        view.identifier = NSUserInterfaceItemIdentifier(rawValue: "control")
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let controls: NSStackView = NSStackView(frame: NSRect(x: 0, y: 14, width: view.frame.width, height: 30))
        controls.orientation = .horizontal
        controls.spacing = 0
        
        let slider: NSSlider = NSSlider(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 26))
        slider.minValue = self.fan.minSpeed
        slider.doubleValue = self.fan.value
        slider.maxValue = self.fan.maxSpeed
        slider.isContinuous = true
        slider.action = #selector(self.speedChange)
        slider.target = self
        
        let levels: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 14))
        
        let minField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 80, height: levels.frame.height))
        minField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        minField.textColor = .secondaryLabelColor
        minField.stringValue = "\(localizedString("Min")): \(Int(self.fan.minSpeed))"
        minField.alignment = .left
        
        let valueField: NSTextField = TextView(frame: NSRect(x: 80, y: 0, width: levels.frame.width - 160, height: levels.frame.height))
        valueField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        valueField.textColor = .secondaryLabelColor
        valueField.alignment = .center
        
        let maxField: NSTextField = TextView(frame: NSRect(x: levels.frame.width - 80, y: 0, width: 80, height: levels.frame.height))
        maxField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        maxField.textColor = .secondaryLabelColor
        maxField.stringValue = "\(localizedString("Max")): \(Int(self.fan.maxSpeed))"
        maxField.alignment = .right
        
        controls.addArrangedSubview(slider)
        
        levels.addSubview(minField)
        levels.addSubview(valueField)
        levels.addSubview(maxField)
        
        view.addSubview(controls)
        view.addSubview(levels)
        
        self.slider = slider
        self.sliderValueField = valueField
        return view
    }
    
    @objc private func askForRoot(_ sender: NSButton) {
        DispatchQueue.main.async {
            ensureRoot()
        }
    }
    
    @objc private func speedChange(_ sender: NSSlider) {
        guard let field = self.sliderValueField else {
            return
        }
        
        let value = sender.doubleValue
        field.stringValue = "\(Int(value)) RPM"
        field.textColor = .secondaryLabelColor
        
        self.debouncer?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                if let id = self?.fan.id {
                    SMC.shared.setFanSpeed(id, speed: Int(value))
                }
                DispatchQueue.main.async {
                    field.textColor = .systemBlue
                }
            }
        }
        
        self.debouncer = task
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3, execute: task)
    }
    
    private func toggleMode() {
        guard let view = self.controlView else {
            return
        }
        
        if self.fan.mode == .automatic {
            view.removeFromSuperview()
            self.sliderValueField?.stringValue = ""
            self.slider?.doubleValue = self.fan.minSpeed
        } else if self.fan.mode == .forced {
            self.addArrangedSubview(view)
        }
        
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +) + 10
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.sizeCallback()
    }
    
    public func update(_ value: Fan) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.ready {
                if let view = self.valueField {
                    view.stringValue = value.formattedValue
                }
                
                if let view = self.percentageField {
                    view.stringValue = "\((100*Int(value.value)) / Int(self.fan.maxSpeed))%"
                }
                
                self.ready = true
            }
        })
    }
}

private class ModeButtons: NSStackView {
    public var callback: (FanMode) -> Void = {_ in }
    
    private var autoBtn: NSButton = NSButton(title: localizedString("Automatic"), target: nil, action: #selector(autoMode))
    private var manualBtn: NSButton = NSButton(title: localizedString("Manual"), target: nil, action: #selector(manualMode))
    
    public init(frame: NSRect, mode: FanMode) {
        super.init(frame: frame)
        
        self.orientation = .horizontal
        self.alignment = .centerY
        self.distribution = .fillEqually
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        self.layer?.borderWidth = 1
        self.layer?.borderColor = NSColor.lightGray.cgColor
        
        self.autoBtn.setButtonType(.toggle)
        self.autoBtn.isBordered = false
        self.autoBtn.target = self
        self.autoBtn.state = mode == .automatic ? .on : .off
        
        self.manualBtn.setButtonType(.toggle)
        self.manualBtn.isBordered = false
        self.manualBtn.target = self
        self.manualBtn.state = mode == .forced ? .on : .off
        
        self.addArrangedSubview(self.autoBtn)
        self.addArrangedSubview(self.manualBtn)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func autoMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.autoBtn.state = .on
            return
        }
        
        self.manualBtn.state = .off
        self.callback(.automatic)
    }
    
    @objc func manualMode(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            self.manualBtn.state = .on
            return
        }
        
        self.autoBtn.state = .off
        self.callback(.forced)
    }
}
