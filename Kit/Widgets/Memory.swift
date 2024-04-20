//
//  Memory.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 30/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class MemoryWidget: WidgetWrapper {
    private var orderReversedState: Bool = false
    private var value: (String, String) = ("0", "0")
    private var percentage: Double = 0
    private var pressureLevel: DispatchSource.MemoryPressureEvent = .normal
    private var symbolsState: Bool = true
    private var colorState: Color = .monochrome
    
    private let width: CGFloat = 50
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        let values = value.split(separator: ",").map{ (String($0) ) }
                        if values.count == 2 {
                            self.value.0 = values[0]
                            self.value.1 = values[1]
                        }
                    }
                }
            }
        }
        
        super.init(.memory, title: title, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: self.width + (Constants.Widget.margin.x*2),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.orderReversedState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_orderReversed", defaultValue: self.orderReversedState)
            self.symbolsState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_symbols", defaultValue: self.symbolsState)
            self.colorState = Color.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
        }
        
        if preview {
            self.orderReversedState = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let letterWidth: CGFloat = 8
        let rowHeight: CGFloat = self.frame.height / 2
        var width: CGFloat = self.width
        var x: CGFloat = 0
        
        let freeY: CGFloat = !self.orderReversedState ? rowHeight+1 : 1
        let usedY: CGFloat = !self.orderReversedState ? 1 : rowHeight+1
        
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        var attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        if self.symbolsState {
            var rect = CGRect(x: Constants.Widget.margin.x, y: freeY, width: letterWidth, height: rowHeight)
            var str = NSAttributedString.init(string: "F:", attributes: attributes)
            str.draw(with: rect)
            
            rect = CGRect(x: Constants.Widget.margin.x, y: usedY, width: letterWidth, height: rowHeight)
            str = NSAttributedString.init(string: "U:", attributes: attributes)
            str.draw(with: rect)
            
            x = letterWidth + Constants.Widget.spacing*2
            width += x
        }
        
        var freeColor: NSColor = .controlAccentColor
        var usedColor: NSColor = .controlAccentColor
        switch self.colorState {
        case .systemAccent: 
            freeColor = .controlAccentColor
            usedColor = .controlAccentColor
        case .utilization: 
            freeColor = (1 - self.percentage).usageColor()
            usedColor = self.percentage.usageColor()
        case .pressure:
            usedColor = self.pressureLevel.pressureColor()
            freeColor = self.pressureLevel.pressureColor()
        case .monochrome:
            freeColor = (isDarkMode ? NSColor.white : NSColor.black)
            usedColor = (isDarkMode ? NSColor.white : NSColor.black)
        default: 
            freeColor = self.colorState.additional as? NSColor ?? .controlAccentColor
            usedColor = self.colorState.additional as? NSColor ?? .controlAccentColor
        }
        
        attributes[NSAttributedString.Key.foregroundColor] = freeColor
        var rect = CGRect(x: x, y: freeY, width: width - x, height: rowHeight)
        var str = NSAttributedString.init(string: self.value.0, attributes: attributes)
        str.draw(with: rect)
        
        attributes[NSAttributedString.Key.foregroundColor] = usedColor
        rect = CGRect(x: x, y: usedY, width: width - x, height: rowHeight)
        str = NSAttributedString.init(string: self.value.1, attributes: attributes)
        str.draw(with: rect)
        
        self.setWidth(width + (Constants.Widget.margin.x*2))
    }
    
    public func setValue(_ value: (String, String), usedPercentage: Double) {
        self.value = value
        self.percentage = usedPercentage
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public func setPressure(_ newPressureLevel: DispatchSource.MemoryPressureEvent) {
        guard self.pressureLevel != newPressureLevel else { return }
        self.pressureLevel = newPressureLevel
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Reverse values order"),
            action: #selector(self.toggleOrder),
            state: self.orderReversedState
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Show symbols"),
            action: #selector(self.toggleSymbols),
            state: self.symbolsState
        ))
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Color"),
            action: #selector(self.toggleColor),
            items: Color.allCases.filter({ $0 != .cluster }),
            selected: self.colorState.key
        ))
        
        return view
    }
    
    @objc private func toggleOrder(_ sender: NSControl) {
        self.orderReversedState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_orderReversed", value: self.orderReversedState)
        self.display()
    }
    
    @objc private func toggleSymbols(_ sender: NSControl) {
        self.symbolsState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_symbols", value: self.symbolsState)
        self.display()
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newColor = Color.allCases.first(where: { $0.key == key }) {
            self.colorState = newColor
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: key)
        self.display()
    }
}
