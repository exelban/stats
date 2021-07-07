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
    private var colorState: Color = .monochrome
    private var alignmentState: String = "left"
    
    private var labelLayer: CATextLayer? = nil
    private var valueLayer: CATextLayer? = nil
    
    private let onlyValueWidth: CGFloat = 40
    private var colors: [Color] = Color.allCases
    
    private var value: Double = 0
    private var pressureLevel: Int = 0
    private var defaultLabel: String
    private var label: String
    
    private var width: CGFloat {
        get {
            return (self.labelState ? 31 : 36) + (2*Constants.Widget.margin.x)
        }
    }
    
    private var alignment: NSTextAlignment {
        get {
            if let alignmentPair = Alignments.first(where: { $0.key == self.alignmentState }) {
                return alignmentPair.additional as? NSTextAlignment ?? .left
            }
            return .left
        }
    }
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self.value = Double(value) ?? 0
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
        }
        
        self.defaultLabel = widgetTitle
        self.label = widgetTitle
        super.init(.mini, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.colorState = Color.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.alignmentState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_alignment", defaultValue: self.alignmentState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let valueSize: CGFloat = self.labelState ? 12 : 14
        var origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: (Constants.Widget.height-valueSize)/2)
        let style = NSMutableParagraphStyle()
        style.alignment = self.labelState ? self.alignment : .center
        
        if self.labelState {
            let style = NSMutableParagraphStyle()
            style.alignment = self.alignment
            
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            let rect = CGRect(x: origin.x, y: 12, width: self.width - (Constants.Widget.margin.x*2), height: 7)
            let str = NSAttributedString.init(string: self.label, attributes: stringAttributes)
            str.draw(with: rect)
            
            origin.y = 1
        }
        
        var color: NSColor = controlAccentColor
        switch self.colorState {
        case .systemAccent: color = controlAccentColor
        case .utilization: color = value.usageColor()
        case .pressure: color = self.pressureLevel.pressureColor()
        case .monochrome: color = (isDarkMode ? NSColor.white : NSColor.black)
        default: color = self.colorState.additional as? NSColor ?? controlAccentColor
        }
        
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let rect = CGRect(x: origin.x, y: origin.y, width: self.width - (Constants.Widget.margin.x*2), height: valueSize+1)
        let str = NSAttributedString.init(string: "\(Int(self.value.rounded(toPlaces: 2) * 100))%", attributes: stringAttributes)
        str.draw(with: rect)
        
        self.setWidth(width)
    }
    
    public func setValue(_ value: Double) {
        if self.value == value {
            return
        }
        
        self.value = value
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setPressure(_ level: Int) {
        if self.pressureLevel == level {
            return
        }
        
        self.pressureLevel = level
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setTitle(_ newTitle: String?) {
        var title = self.defaultLabel
        if let new = newTitle {
            title = new
        }
        
        if self.label == title {
            return
        }
        
        self.label = title
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings(width: CGFloat) -> NSView {
        let view = SettingsContainerView(width: width)
        
        view.addArrangedSubview(toggleTitleRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Settings.row),
            title: localizedString("Label"),
            action: #selector(toggleLabel),
            state: self.labelState
        ))
        
        view.addArrangedSubview(selectRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Settings.row),
            title: localizedString("Color"),
            action: #selector(toggleColor),
            items: self.colors,
            selected: self.colorState.key
        ))
        
        view.addArrangedSubview(selectRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Settings.row),
            title: localizedString("Alignment"),
            action: #selector(toggleAlignment),
            items: Alignments,
            selected: self.alignmentState
        ))
        
        return view
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        if let newColor = Color.allCases.first(where: { $0.key == key }) {
            self.colorState = newColor
        }
        
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: key)
        self.display()
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.labelState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        self.display()
    }
    
    @objc private func toggleAlignment(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        
        if let newAlignment = Alignments.first(where: { $0.key == key }) {
            self.alignmentState = newAlignment.key
        }
        
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_alignment", value: key)
        self.display()
    }
}
