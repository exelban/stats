//
//  Mini.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class Mini: WidgetWrapper {
    private var labelState: Bool = true
    private var colorState: SColor = .monochrome
    private var alignmentState: String = "left"
    private var supportsGB: Bool = false
    private var showFreeInGBState: Bool = false
    private var absoluteUnitsState: Bool = false
    private var _usedBytes: Int64 = 0
    
    private var colors: [SColor] = SColor.allCases
    
    private var _value: Double = 0
    private var _pressureLevel: RAMPressure = .normal
    private var _colorZones: colorZones = (0.6, 0.8)
    private var _suffix: String = "%"
    
    private var defaultLabel: String
    private var _label: String
    
    private var width: CGFloat {
        (self.labelState ? 31 : 36) + (2*Constants.Widget.margin.x)
    }
    
    private var alignment: NSTextAlignment {
        if let alignmentPair = Alignments.first(where: { $0.key == self.alignmentState }) {
            return alignmentPair.additional as? NSTextAlignment ?? .left
        }
        return .left
    }
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self._value = Double(value) ?? 0
                    }
                    if let freeDiskSize = configuration["FreeDiskSize"] as? Int64 {
                        self._usedBytes = freeDiskSize
                    }
                    if let absoluteUnits = configuration["AbsoluteUnits"] as? Bool {
                        self.absoluteUnitsState = absoluteUnits
                    }
                }
            }
            
            if let titleFromConfig = configuration["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
            if let unsupportedColors = configuration["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter{ !unsupportedColors.contains($0.key) }
            }
            if let color = configuration["Color"] as? String {
                if let defaultColor = colors.first(where: { "\($0.self)" == color }) {
                    self.colorState = defaultColor
                }
            }
            if let configSupportsGB = configuration["SupportsGB"] as? Bool {
                self.supportsGB = configSupportsGB
            }
        }
        
        self.defaultLabel = widgetTitle
        self._label = widgetTitle
        super.init(.mini, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.colorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.alignmentState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_alignment", defaultValue: self.alignmentState)
            if self.supportsGB {
                self.showFreeInGBState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_showGB", defaultValue: false)
                self.absoluteUnitsState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_absoluteUnits", defaultValue: false)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleAbsoluteUnitsNotification(_:)), name: NSNotification.Name("toggleAbsoluteUnits"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAbsoluteUnitsNotification(_ notification: Notification) {
        if let isEnabled = notification.userInfo?["isEnabled"] as? Bool {
            self.absoluteUnitsState = isEnabled
            DispatchQueue.main.async {
                self.display()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var value: Double = 0
        var pressureLevel: RAMPressure = .normal
        var colorZones: colorZones = (0.6, 0.8)
        var label: String = ""
        var suffix: String = ""
        self.queue.sync {
            value = self._value
            pressureLevel = self._pressureLevel
            colorZones = self._colorZones
            label = self._label
            suffix = self._suffix
        }
        
        let initialValueSize: CGFloat = self.labelState ? 12 : 14
        var valueSize: CGFloat = initialValueSize
        var origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: (Constants.Widget.height-valueSize)/2)
        let style = NSMutableParagraphStyle()
        style.alignment = self.labelState ? self.alignment : .center
        
        if self.labelState {
            let labelStyle = NSMutableParagraphStyle()
            labelStyle.alignment = self.alignment
            
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: labelStyle
            ]
            let rect = CGRect(x: origin.x, y: 12, width: self.width - (Constants.Widget.margin.x*2), height: 7)
            let str = NSAttributedString.init(string: label, attributes: stringAttributes)
            str.draw(with: rect)
            
            origin.y = 1
        }
        
        var color: NSColor = .controlAccentColor
        switch self.colorState {
        case .systemAccent: color = .controlAccentColor
        case .utilization: color = value.usageColor(zones: colorZones, reversed: self.title == "BAT")
        case .pressure: color = pressureLevel.pressureColor()
        case .monochrome: color = (isDarkMode ? NSColor.white : NSColor.black)
        default: color = self.colorState.additional as? NSColor ?? .controlAccentColor
        }
        
        let displayText: String
        if self.supportsGB && self.absoluteUnitsState && self._usedBytes > 0 {
            displayText = DiskSize(self._usedBytes).getReadableMemory()
        } else {
            displayText = "\(Int(value.rounded(toPlaces: 2) * 100))\(suffix)"
        }
        
        let availableWidth = self.width - (2 * Constants.Widget.margin.x)
        
        let measureFont = NSFont.systemFont(ofSize: valueSize, weight: .regular)
        let measureAttributes: [NSAttributedString.Key: Any] = [
            .font: measureFont,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        
        var textSize = (displayText as NSString).size(withAttributes: measureAttributes)
        
        while textSize.width > availableWidth && valueSize > 8 {
            valueSize -= 0.5
            let newFont = NSFont.systemFont(ofSize: valueSize, weight: .regular)
            let newAttributes: [NSAttributedString.Key: Any] = [
                .font: newFont,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
            textSize = (displayText as NSString).size(withAttributes: newAttributes)
        }
        
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        let rect = CGRect(x: origin.x, y: origin.y, width: availableWidth, height: valueSize+1)
        let str = NSAttributedString.init(string: displayText, attributes: stringAttributes)
        str.draw(with: rect)
        
        self.setWidth(width)
    }
    
    public func setValue(_ newValue: Double) {
        guard self._value != newValue else { return }
        self._value = newValue
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setUsedBytes(_ bytes: Int64) {
        self._usedBytes = bytes
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setPressure(_ newPressureLevel: RAMPressure) {
        guard self._pressureLevel != newPressureLevel else { return }
        self._pressureLevel = newPressureLevel
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setTitle(_ newTitle: String?) {
        var title = self.defaultLabel
        if let new = newTitle {
            title = new
        }
        guard self._label != title else { return }
        self._label = title
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setColorZones(_ newColorZones: colorZones) {
        guard self._colorZones != newColorZones else { return }
        self._colorZones = newColorZones
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setSuffix(_ newSuffix: String) {
        guard self._suffix != newSuffix else { return }
        self._suffix = newSuffix
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        var preferences: [PreferencesRow] = []
        
        if self.supportsGB {
            preferences.append(PreferencesRow(localizedString("Absolute units (MB/GB/TB)"), component: switchView(
                action: #selector(self.toggleAbsoluteUnitsSwitch),
                state: self.absoluteUnitsState
            )))
        }
        
        preferences += [
            PreferencesRow(localizedString("Label"), component: switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Color"), component: selectView(
                action: #selector(self.toggleColor),
                items: self.colors,
                selected: self.colorState.key
            )),
            PreferencesRow(localizedString("Alignment"), component: selectView(
                action: #selector(self.toggleAlignment),
                items: Alignments,
                selected: self.alignmentState
            ))
        ]
        
        view.addArrangedSubview(PreferencesSection(preferences))
        
        return view
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = SColor.allCases.first(where: { $0.key == key }) {
            self.colorState = newColor
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: key)
        self.display()
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        self.labelState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        self.display()
    }
    
    @objc private func toggleAlignment(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newAlignment = Alignments.first(where: { $0.key == key }) {
            self.alignmentState = newAlignment.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_alignment", value: key)
        self.display()
    }
    
    @objc private func toggleShowGB(_ sender: NSControl) {
        self.showFreeInGBState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_showGB", value: self.showFreeInGBState)
        self.display()
    }
    
    @objc private func toggleAbsoluteUnitsSwitch(_ sender: NSControl) {
        self.absoluteUnitsState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_absoluteUnits", value: self.absoluteUnitsState)
        NotificationCenter.default.post(name: NSNotification.Name("toggleAbsoluteUnits"), object: nil, userInfo: ["isEnabled": self.absoluteUnitsState])
        self.display()
    }
}
