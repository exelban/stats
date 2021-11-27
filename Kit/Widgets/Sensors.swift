//
//  Sensors.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class SensorsWidget: WidgetWrapper {
    private var modeState: String = "automatic"
    private var fixedSizeState: Bool = false
    private var values: [KeyValue_t] = []
    
    private var oneRowWidth: CGFloat = 36
    private var twoRowWidth: CGFloat = 26
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Values"] as? String {
                        for (i, value) in value.split(separator: ",").enumerated() {
                            self.values.append(KeyValue_t(key: "\(i)", value: String(value)))
                        }
                    }
                }
            }
        }
        
        super.init(.sensors, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        if !preview {
            self.modeState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState)
            self.fixedSizeState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_size", defaultValue: self.fixedSizeState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !self.values.isEmpty else {
            self.setWidth(1)
            return
        }
        
        let num: Int = Int(round(Double(self.values.count) / 2))
        var totalWidth: CGFloat = Constants.Widget.spacing  // opening space
        var x: CGFloat = Constants.Widget.spacing
        
        var i = 0
        while i < self.values.count {
            switch self.modeState {
            case "automatic", "twoRows":
                let firstSensor: KeyValue_t = self.values[i]
                let secondSensor: KeyValue_t? = self.values.indices.contains(i+1) ? self.values[i+1] : nil
                
                var width: CGFloat = 0
                if self.modeState == "automatic" && secondSensor == nil {
                    width += self.drawOneRow(firstSensor, x: x)
                } else {
                    width += self.drawTwoRows(topSensor: firstSensor, bottomSensor: secondSensor, x: x)
                }
                
                x += width
                totalWidth += width
                
                if num != 1 && (i/2) != num {
                    x += Constants.Widget.spacing
                    totalWidth += Constants.Widget.spacing
                }
                
                i += 1
            case "oneRow":
                let width = self.drawOneRow(self.values[i], x: x)
                
                x += width
                totalWidth += width
                
                // add margins between columns
                if self.values.count != 1 && i != self.values.count {
                    x += Constants.Widget.spacing
                    totalWidth += Constants.Widget.spacing
                }
            default: break
            }
            
            i += 1
        }
        totalWidth += Constants.Widget.spacing // closing space
        
        if abs(self.frame.width - totalWidth) < 2 {
            return
        }
        self.setWidth(totalWidth)
    }
    
    private func drawOneRow(_ sensor: KeyValue_t, x: CGFloat) -> CGFloat {
        let font: NSFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        var width: CGFloat = self.oneRowWidth
        if !self.fixedSizeState {
            width = sensor.value.widthOfString(usingFont: font).rounded(.up) + 2
        }
        
        let rect = CGRect(x: x, y: (Constants.Widget.height-13)/2, width: width, height: 13)
        let str = NSAttributedString.init(string: sensor.value, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ])
        str.draw(with: rect)
        
        return width
    }
    
    private func drawTwoRows(topSensor: KeyValue_t, bottomSensor: KeyValue_t?, x: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = self.frame.height / 2
        
        let font: NSFont = NSFont.systemFont(ofSize: 10, weight: .light)
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        var width: CGFloat = self.twoRowWidth
        if !self.fixedSizeState {
            let firstRowWidth = topSensor.value.widthOfString(usingFont: font)
            let secondRowWidth = bottomSensor?.value.widthOfString(usingFont: font) ?? 0
            width = max(20, max(firstRowWidth, secondRowWidth)).rounded(.up) + 2
        }
        
        var rect = CGRect(x: x, y: rowHeight+1, width: width, height: rowHeight)
        var str = NSAttributedString.init(string: topSensor.value, attributes: attributes)
        str.draw(with: rect)
        
        if bottomSensor != nil {
            rect = CGRect(x: x, y: 1, width: width, height: rowHeight)
            str = NSAttributedString.init(string: bottomSensor!.value, attributes: attributes)
            str.draw(with: rect)
        }
        
        return width
    }
    
    public func setValues(_ values: [KeyValue_t]) {
        self.values = values
        
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Display mode"),
            action: #selector(changeDisplayMode),
            items: SensorsWidgetMode,
            selected: self.modeState
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Static width"),
            action: #selector(toggleSize),
            state: self.fixedSizeState
        ))
        
        return view
    }
    
    @objc private func changeDisplayMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.modeState = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
    }
    
    @objc private func toggleSize(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.fixedSizeState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_size", value: self.fixedSizeState)
        self.display()
    }
}
