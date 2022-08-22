//
//  Battery.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class BatterykWidget: WidgetWrapper {
    private var additional: String = "none"
    private var timeFormat: String = "short"
    private var iconState: Bool = true
    private var colorState: Bool = false
    private var hideAdditionalWhenFull: Bool = true
    private var lowPowerModeState: Bool = true
    
    private var percentage: Double? = nil
    private var time: Int = 0
    private var charging: Bool = false
    private var ACStatus: Bool = false
    private var lowPowerMode: Bool = false
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        let widgetTitle: String = title
        
        super.init(.battery, title: widgetTitle, frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: 30 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.additional = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_additional", defaultValue: self.additional)
            self.timeFormat = Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
            self.iconState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_icon", defaultValue: self.iconState)
            self.colorState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState)
            self.hideAdditionalWhenFull = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_hideAdditionalWhenFull", defaultValue: self.hideAdditionalWhenFull)
            self.lowPowerModeState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_lowPowerMode", defaultValue: self.lowPowerMode)
        }
        
        if preview {
            self.percentage = 0.72
            self.additional = "none"
            self.iconState = true
            self.colorState = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // swiftlint:disable function_body_length
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        var width: CGFloat = Constants.Widget.margin.x*2
        var x: CGFloat = 0
        let isShortTimeFormat: Bool = self.timeFormat == "short"
        
        if !self.hideAdditionalWhenFull || (self.hideAdditionalWhenFull && self.percentage != 1) {
            switch self.additional {
            case "percentage":
                var value = "n/a"
                if let percentage = self.percentage {
                    value = "\(Int((percentage.rounded(toPlaces: 2)) * 100))%"
                }
                let rowWidth = self.drawOneRow(value: value, x: x).rounded(.up)
                width += rowWidth + Constants.Widget.spacing
                x += rowWidth + Constants.Widget.spacing
            case "time":
                let rowWidth = self.drawOneRow(
                    value: Double(self.time*60).printSecondsToHoursMinutesSeconds(short: isShortTimeFormat),
                    x: x
                ).rounded(.up)
                width += rowWidth + Constants.Widget.spacing
                x += rowWidth + Constants.Widget.spacing
            case "percentageAndTime":
                var value = "n/a"
                if let percentage = self.percentage {
                    value = "\(Int((percentage.rounded(toPlaces: 2)) * 100))%"
                }
                let rowWidth = self.drawTwoRows(
                    first: value,
                    second: Double(self.time*60).printSecondsToHoursMinutesSeconds(short: isShortTimeFormat),
                    x: x
                ).rounded(.up)
                width += rowWidth + Constants.Widget.spacing
                x += rowWidth + Constants.Widget.spacing
            case "timeAndPercentage":
                var value = "n/a"
                if let percentage = self.percentage {
                    value = "\(Int((percentage.rounded(toPlaces: 2)) * 100))%"
                }
                let rowWidth = self.drawTwoRows(
                    first: Double(self.time*60).printSecondsToHoursMinutesSeconds(short: isShortTimeFormat),
                    second: value,
                    x: x
                ).rounded(.up)
                width += rowWidth + Constants.Widget.spacing
                x += rowWidth + Constants.Widget.spacing
            default: break
            }
        }
        
        let borderWidth: CGFloat = 1
        let batterySize: CGSize = CGSize(width: 22, height: 12)
        let offset: CGFloat = 0.5 // contant!
        width += batterySize.width + borderWidth*2 // add battery width
        
        let batteryFrame = NSBezierPath(roundedRect: NSRect(
            x: x + borderWidth + offset,
            y: ((dirtyRect.size.height - batterySize.height)/2) + offset,
            width: batterySize.width - borderWidth,
            height: batterySize.height - borderWidth
        ), xRadius: 2, yRadius: 2)
        
        NSColor.textColor.withAlphaComponent(0.5).set()
        batteryFrame.lineWidth = borderWidth
        batteryFrame.stroke()
        
        let bPX: CGFloat = batteryFrame.bounds.origin.x + batteryFrame.bounds.width + 1
        let bPY: CGFloat = batteryFrame.bounds.origin.y + batteryFrame.bounds.height/2 - 2
        let batteryPoint = NSBezierPath(roundedRect: NSRect(x: bPX - 1, y: bPY, width: 3, height: 4), xRadius: 2, yRadius: 2)
        batteryPoint.fill()
        
        let batteryPointSeparator = NSBezierPath()
        batteryPointSeparator.move(to: CGPoint(x: bPX, y: batteryFrame.bounds.origin.y))
        batteryPointSeparator.line(to: CGPoint(x: bPX, y: batteryFrame.bounds.origin.y + batteryFrame.bounds.height))
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        NSColor.textColor.set()
        batteryPointSeparator.lineWidth = borderWidth
        batteryPointSeparator.stroke()
        ctx.restoreGState()
        width += 2 // add battery point width
        
        if let percentage = self.percentage {
            let maxWidth = batterySize.width - offset*2 - borderWidth*2 - 1
            let innerWidth: CGFloat = max(1, maxWidth * CGFloat(percentage))
            let innerOffset: CGFloat = -offset + borderWidth + 1
            let inner = NSBezierPath(roundedRect: NSRect(
                x: batteryFrame.bounds.origin.x + innerOffset,
                y: batteryFrame.bounds.origin.y + innerOffset,
                width: innerWidth,
                height: batterySize.height - offset*2 - borderWidth*2 - 1
            ), xRadius: 1, yRadius: 1)
            if self.lowPowerModeState {
                percentage.batteryColor(color: self.colorState, lowPowerMode: self.lowPowerMode).set()
            } else {
                percentage.batteryColor(color: self.colorState).set()
            }
            inner.fill()
        } else {
            let attributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            let batteryCenter: CGPoint = CGPoint(
                x: batteryFrame.bounds.origin.x + (batteryFrame.bounds.width/2),
                y: batteryFrame.bounds.origin.y + (batteryFrame.bounds.height/2)
            )
            
            let rect = CGRect(x: batteryCenter.x-2, y: batteryCenter.y-4, width: 8, height: 12)
            NSAttributedString.init(string: "?", attributes: attributes).draw(with: rect)
        }
        
        if self.ACStatus {
            let batteryCenter: CGPoint = CGPoint(
                x: batteryFrame.bounds.origin.x + (batteryFrame.bounds.width/2),
                y: batteryFrame.bounds.origin.y + (batteryFrame.bounds.height/2)
            )
            var points: [CGPoint] = []
            
            if self.charging {
                let iconSize: CGSize = CGSize(width: 9, height: batterySize.height + 6)
                let min = CGPoint(
                    x: batteryCenter.x - (iconSize.width/2),
                    y: batteryCenter.y - (iconSize.height/2)
                )
                let max = CGPoint(
                    x: batteryCenter.x + (iconSize.width/2),
                    y: batteryCenter.y + (iconSize.height/2)
                )
                
                points = [
                    CGPoint(x: batteryCenter.x-3, y: min.y), // bottom
                    CGPoint(x: max.x, y: batteryCenter.y+1.5),
                    CGPoint(x: batteryCenter.x+1, y: batteryCenter.y+1.5),
                    CGPoint(x: batteryCenter.x+3, y: max.y), // top
                    CGPoint(x: min.x, y: batteryCenter.y-1.5),
                    CGPoint(x: batteryCenter.x-1, y: batteryCenter.y-1.5)
                ]
            } else {
                let iconSize: CGSize = CGSize(width: 9, height: batterySize.height + 2)
                let minY = batteryCenter.y - (iconSize.height/2)
                let maxY = batteryCenter.y + (iconSize.height/2)
                
                points = [
                    CGPoint(x: batteryCenter.x-1.5, y: minY+0.5),
                    
                    CGPoint(x: batteryCenter.x+1.5, y: minY+0.5),
                    CGPoint(x: batteryCenter.x+1.5, y: batteryCenter.y - 2.5),
                    
                    CGPoint(x: batteryCenter.x+4, y: batteryCenter.y + 0.5),
                    CGPoint(x: batteryCenter.x+4, y: batteryCenter.y + 4.25),
                    
                    // right
                    CGPoint(x: batteryCenter.x+2.75, y: batteryCenter.y + 4.25),
                    CGPoint(x: batteryCenter.x+2.75, y: maxY-0.25),
                    CGPoint(x: batteryCenter.x+0.25, y: maxY-0.25),
                    CGPoint(x: batteryCenter.x+0.25, y: batteryCenter.y + 4.25),
                    
                    // left
                    CGPoint(x: batteryCenter.x-0.25, y: batteryCenter.y + 4.25),
                    CGPoint(x: batteryCenter.x-0.25, y: maxY-0.25),
                    CGPoint(x: batteryCenter.x-2.75, y: maxY-0.25),
                    CGPoint(x: batteryCenter.x-2.75, y: batteryCenter.y + 4.25),
                    
                    CGPoint(x: batteryCenter.x-4, y: batteryCenter.y + 4.25),
                    CGPoint(x: batteryCenter.x-4, y: batteryCenter.y + 0.5),
                    
                    CGPoint(x: batteryCenter.x-1.5, y: batteryCenter.y - 2.5),
                    CGPoint(x: batteryCenter.x-1.5, y: minY+0.5)
                ]
            }
            
            let linePath = NSBezierPath()
            linePath.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for i in 1..<points.count {
                linePath.line(to: CGPoint(x: points[i].x, y: points[i].y))
            }
            linePath.line(to: CGPoint(x: points[0].x, y: points[0].y))
            
            NSColor.textColor.set()
            linePath.fill()
            
            ctx.saveGState()
            ctx.setBlendMode(.destinationOut)
            
            NSColor.orange.set()
            linePath.lineWidth = borderWidth
            linePath.stroke()
            
            ctx.restoreGState()
        }
        
        self.setWidth(width)
    }
    
    private func drawOneRow(value: String, x: CGFloat) -> CGFloat {
        let attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12, weight: .regular),
            NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
        ]
        
        let rowWidth = value.widthOfString(usingFont: .systemFont(ofSize: 12, weight: .regular))
        let rect = CGRect(x: x, y: (Constants.Widget.height-12)/2, width: rowWidth, height: 12)
        let str = NSAttributedString.init(string: value, attributes: attributes)
        str.draw(with: rect)
        
        return rowWidth
    }
    
    private func drawTwoRows(first: String, second: String, x: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let rowHeight: CGFloat = self.frame.height / 2
        
        let rowWidth = max(
            first.widthOfString(usingFont: .systemFont(ofSize: 9, weight: .regular)),
            second.widthOfString(usingFont: .systemFont(ofSize: 9, weight: .regular))
        )
        
        var str = NSAttributedString.init(string: first, attributes: attributes)
        str.draw(with: CGRect(x: x, y: rowHeight+1, width: rowWidth, height: rowHeight))
        
        str = NSAttributedString.init(string: second, attributes: attributes)
        str.draw(with: CGRect(x: x, y: 1, width: rowWidth, height: rowHeight))
        
        return rowWidth
    }
    
    public func setValue(percentage: Double? = nil, ACStatus: Bool? = nil, isCharging: Bool? = nil, lowPowerMode: Bool? = nil, time: Int? = nil) {
        var updated: Bool = false
        let timeFormat: String = Store.shared.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
        
        if self.percentage != percentage {
            self.percentage = percentage
            updated = true
        }
        if let status = ACStatus, self.ACStatus != status {
            self.ACStatus = status
            updated = true
        }
        if let charging = isCharging, self.charging != charging {
            self.charging = charging
            updated = true
        }
        if let time = time, self.time != time {
            self.time = time
            updated = true
        }
        if self.timeFormat != timeFormat {
            self.timeFormat = timeFormat
            updated = true
        }
        if let state = lowPowerMode, self.lowPowerMode != state {
            self.lowPowerMode = state
            updated = true
        }
        
        if updated {
            DispatchQueue.main.async(execute: {
                self.display()
            })
        }
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        var additionalOptions = BatteryAdditionals
        if self.title == "Bluetooth" {
            additionalOptions = additionalOptions.filter({ $0.key == "none" || $0.key == "percentage" })
        }
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Additional information"),
            action: #selector(toggleAdditional),
            items: additionalOptions,
            selected: self.additional
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Hide additional information when full"),
            action: #selector(toggleHideAdditionalWhenFull),
            state: self.hideAdditionalWhenFull
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Low power mode"),
            action: #selector(toggleLowPowerMode),
            state: self.lowPowerModeState
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Colorize"),
            action: #selector(toggleColor),
            state: self.colorState
        ))
        
        return view
    }
    
    @objc private func toggleAdditional(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.additional = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_additional", value: key)
        self.display()
    }
    
    @objc private func toggleHideAdditionalWhenFull(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.hideAdditionalWhenFull = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_hideAdditionalWhenFull", value: self.hideAdditionalWhenFull)
        self.display()
    }
    
    @objc private func toggleColor(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.colorState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState)
        self.display()
    }
    
    @objc private func toggleLowPowerMode(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.lowPowerModeState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_lowPowerMode", value: self.lowPowerModeState)
        self.display()
    }
}
