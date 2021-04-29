//
//  Sensors.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class SensorsWidget: WidgetWrapper {
    private var modeState: String = "automatic"
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
        
        if title == "Fans" { // hack for fans. Because fan value contain RPM.
            self.oneRowWidth = 66
            self.twoRowWidth = 50
        }
        
        super.init(.sensors, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.modeState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard self.values.count != 0 else {
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
        var font: NSFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        if #available(OSX 10.15, *) {
            font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let rect = CGRect(x: x, y: (Constants.Widget.height-13)/2, width: self.oneRowWidth, height: 13)
        let str = NSAttributedString.init(string: sensor.value, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ])
        str.draw(with: rect)
        
        return self.oneRowWidth
    }
    
    private func drawTwoRows(topSensor: KeyValue_t, bottomSensor: KeyValue_t?, x: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = self.frame.height / 2
        
        var font: NSFont = NSFont.systemFont(ofSize: 10, weight: .light)
        if #available(OSX 10.15, *) {
            font = NSFont.monospacedSystemFont(ofSize: 10, weight: .light)
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        var rect = CGRect(x: x, y: rowHeight+1, width: self.twoRowWidth, height: rowHeight)
        var str = NSAttributedString.init(string: topSensor.value, attributes: attributes)
        str.draw(with: rect)
        
        if bottomSensor != nil {
            rect = CGRect(x: x, y: 1, width: self.twoRowWidth, height: rowHeight)
            str = NSAttributedString.init(string: bottomSensor!.value, attributes: attributes)
            str.draw(with: rect)
        }
        
        return self.twoRowWidth
    }
    
    public func setValues(_ values: [KeyValue_t]) {
        self.values = values
        
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings(width: CGFloat) -> NSView {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 1) + Constants.Settings.margin
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: width - (Constants.Settings.margin*2),
            height: height
        ))
        
        view.addSubview(SelectRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Display mode"),
            action: #selector(changeMode),
            items: SensorsWidgetMode,
            selected: self.modeState
        ))
        
        return view
    }
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.modeState = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
    }
}
