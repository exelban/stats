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

public struct SensorValue_t {
    public let icon: NSImage?
    public var value: String
    
    public init(_ value: String, icon: NSImage? = nil){
        self.value = value
        self.icon = icon
    }
}

public class SensorsWidget: Widget {
    private var modeState: String = "automatic"
    private var iconState: Bool = false
    private let store: UnsafePointer<Store>?
    
    private var values: [SensorValue_t] = []
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        self.store = store
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Values"] as? String {
                        self.values = value.split(separator: ",").map{ (SensorValue_t(String($0)) ) }
                    }
                }
            }
        }
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: Constants.Widget.width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = title
        self.type = .sensors
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.modeState = store!.pointee.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState)
            self.iconState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_icon", defaultValue: self.iconState)
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
        var totalWidth: CGFloat = Constants.Widget.margin  // opening space
        var x: CGFloat = Constants.Widget.margin
        
        var i = 0
        while i < self.values.count {
            switch self.modeState {
            case "automatic", "twoRows":
                let firstSensor: SensorValue_t? = self.values[i]
                let secondSensor: SensorValue_t? = self.values.indices.contains(i+1) ? self.values[i+1] : nil
                
                var width: CGFloat = 0
                if self.modeState == "automatic" && secondSensor == nil {
                    width += self.drawOneRow(firstSensor!, x: x)
                } else {
                    width += self.drawTwoRows(topSensor: firstSensor, bottomSensor: secondSensor, x: x)
                }
                
                x += width
                totalWidth += width
                
                if num != 1 && (i/2) != num {
                    x += Constants.Widget.margin
                    totalWidth += Constants.Widget.margin
                }
                
                i += 1
            case "oneRow":
                let width = self.drawOneRow(self.values[i], x: x)
                
                x += width
                totalWidth += width
                
                // add margins between columns
                if self.values.count != 1 && i != self.values.count {
                    x += Constants.Widget.margin
                    totalWidth += Constants.Widget.margin
                }
            default: break
            }
            
            i += 1
        }
        totalWidth += Constants.Widget.margin // closing space
        
        if abs(self.frame.width - totalWidth) < 2 {
            return
        }
        self.setWidth(totalWidth)
    }
    
    private func drawOneRow(_ sensor: SensorValue_t, x: CGFloat) -> CGFloat {
        var width: CGFloat = 0
        var paddingLeft: CGFloat = 0
        
        let font: NSFont = NSFont.systemFont(ofSize: 13, weight: .light)
        width = sensor.value.widthOfString(usingFont: font).rounded(.up) + 2
        
        if let icon = sensor.icon, self.iconState {
            let iconSize: CGFloat = 11
            icon.draw(in: NSRect(x: x, y: ((Constants.Widget.height-iconSize)/2)-2, width: iconSize, height: iconSize))
            paddingLeft = iconSize + (Constants.Widget.margin*3)
            width += paddingLeft
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let rect = CGRect(x: x+paddingLeft, y: (Constants.Widget.height-13)/2, width: width-paddingLeft, height: 13)
        let str = NSAttributedString.init(string: sensor.value, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ])
        str.draw(with: rect)
        
        return width
    }
    
    private func drawTwoRows(topSensor: SensorValue_t?, bottomSensor: SensorValue_t?, x: CGFloat) -> CGFloat {
        var width: CGFloat = 0
        var paddingLeft: CGFloat = 0
        let rowHeight: CGFloat = self.frame.height / 2
        
        var font: NSFont = NSFont.systemFont(ofSize: 9, weight: .light)
        if #available(OSX 10.15, *) {
            font = NSFont.monospacedSystemFont(ofSize: 9, weight: .light)
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        
        let firstRowWidth = topSensor?.value.widthOfString(usingFont: font)
        let secondRowWidth = bottomSensor?.value.widthOfString(usingFont: font)
        width = max(20, max(firstRowWidth ?? 0, secondRowWidth ?? 0)).rounded(.up)
        
        if self.iconState && (topSensor?.icon != nil || bottomSensor?.icon != nil) {
            let iconSize: CGFloat = 8
            if let icon = topSensor?.icon {
                icon.draw(in: NSRect(x: x, y: rowHeight+((rowHeight-iconSize)/2), width: iconSize, height: iconSize))
            }
            if let icon = bottomSensor?.icon {
                icon.draw(in: NSRect(x: x, y: (rowHeight-iconSize)/2, width: iconSize, height: iconSize))
            }
            
            paddingLeft = iconSize + (Constants.Widget.margin*3)
            width += paddingLeft
        }
        
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        if topSensor != nil {
            let rect = CGRect(x: x+paddingLeft, y: rowHeight+1, width: width-paddingLeft, height: rowHeight)
            let str = NSAttributedString.init(string: topSensor!.value, attributes: attributes)
            str.draw(with: rect)
        }
        
        if bottomSensor != nil {
            let rect = CGRect(x: x+paddingLeft, y: 1, width: width-paddingLeft, height: rowHeight)
            let str = NSAttributedString.init(string: bottomSensor!.value, attributes: attributes)
            str.draw(with: rect)
        }
        
        return width
    }
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 1) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 1, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Pictogram"),
            action: #selector(toggleIcom),
            state: self.iconState
        ))
        
        view.addSubview(SelectRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Display mode"),
            action: #selector(changeMode),
            items: SensorsWidgetMode,
            selected: self.modeState
        ))
        
        superview.addSubview(view)
    }
    
    public func setValues(_ values: [SensorValue_t]) {
        self.values = values
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
    
    @objc private func toggleIcom(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.iconState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_icon", value: self.iconState)
        self.display()
    }
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.modeState = key
        store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
    }
}
