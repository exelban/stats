//
//  Battery.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 06/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class BatterykWidget: Widget {
    private var additional: String = "none"
    private var timeFormat: String = "short"
    private var iconState: Bool = true
    private var colorState: Bool = false
    private var hideAdditionalWhenFull: Bool = true
    
    private let store: UnsafePointer<Store>?
    
    private var percentage: Double = 1
    private var time: Int = 0
    private var charging: Bool = false
    private var ACStatus: Bool = false
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        let widgetTitle: String = title
        self.store = store
        
        super.init(frame: CGRect(
            x: Constants.Widget.margin.x,
            y: Constants.Widget.margin.y,
            width: 30 + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.title = widgetTitle
        self.type = .battery
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.additional = store!.pointee.string(key: "\(self.title)_\(self.type.rawValue)_additional", defaultValue: self.additional)
            self.timeFormat = store!.pointee.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
            self.iconState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_icon", defaultValue: self.iconState)
            self.colorState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState)
            self.hideAdditionalWhenFull = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_hideAdditionalWhenFull", defaultValue: self.hideAdditionalWhenFull)
        }
        
        if self.preview {
            self.percentage = 0.72
            self.additional = "none"
            self.iconState = true
            self.colorState = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        var width: CGFloat = Constants.Widget.margin.x*2
        var x: CGFloat = 0
        let isShortTimeFormat: Bool = self.timeFormat == "short"
        
        if !self.hideAdditionalWhenFull || (self.hideAdditionalWhenFull && self.percentage != 1) {
            switch self.additional {
            case "percentage":
                let rowWidth = self.drawOneRow(
                    value: "\(Int((self.percentage.rounded(toPlaces: 2)) * 100))%",
                    x: x
                ).rounded(.up)
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
                let rowWidth = self.drawTwoRows(
                    first: "\(Int((self.percentage.rounded(toPlaces: 2)) * 100))%",
                    second: Double(self.time*60).printSecondsToHoursMinutesSeconds(short: isShortTimeFormat),
                    x: x
                ).rounded(.up)
                width += rowWidth + Constants.Widget.spacing
                x += rowWidth + Constants.Widget.spacing
            case "timeAndPercentage":
                let rowWidth = self.drawTwoRows(
                    first: Double(self.time*60).printSecondsToHoursMinutesSeconds(short: isShortTimeFormat),
                    second: "\(Int((self.percentage.rounded(toPlaces: 2)) * 100))%",
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
        
        let maxWidth = batterySize.width - offset*2 - borderWidth*2 - 1
        let innerWidth: CGFloat = self.ACStatus && !self.charging ? maxWidth : max(1, maxWidth * CGFloat(self.percentage))
        let innerOffset: CGFloat = -offset + borderWidth + 1
        let inner = NSBezierPath(roundedRect: NSRect(
            x: batteryFrame.bounds.origin.x + innerOffset,
            y: batteryFrame.bounds.origin.y + innerOffset,
            width: innerWidth,
            height: batterySize.height - offset*2 - borderWidth*2 - 1
        ), xRadius: 1, yRadius: 1)
        self.percentage.batteryColor(color: self.colorState).set()
        inner.fill()
        
        if self.ACStatus {
            let batteryCenter: CGPoint = CGPoint(
                x: batteryFrame.bounds.origin.x + (batteryFrame.bounds.width/2),
                y: batteryFrame.bounds.origin.y + (batteryFrame.bounds.height/2)
            )
            let boltSize: CGSize = CGSize(width: 9, height: batterySize.height + 6)
            
            let minX = batteryCenter.x - (boltSize.width/2)
            let maxX = batteryCenter.x + (boltSize.width/2)
            let minY = batteryCenter.y - (boltSize.height/2)
            let maxY = batteryCenter.y + (boltSize.height/2)
            
            let points: [CGPoint] = [
                CGPoint(x: batteryCenter.x-3, y: minY), // bottom
                CGPoint(x: maxX, y: batteryCenter.y+1.5),
                CGPoint(x: batteryCenter.x+1, y: batteryCenter.y+1.5),
                CGPoint(x: batteryCenter.x+3, y: maxY), // top
                CGPoint(x: minX, y: batteryCenter.y-1.5),
                CGPoint(x: batteryCenter.x-1, y: batteryCenter.y-1.5),
            ]
            
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
    
    public func setValue(percentage: Double, ACStatus: Bool, isCharging: Bool, time: Int) {
        var updated: Bool = false
        let timeFormat: String = store!.pointee.string(key: "\(self.title)_timeFormat", defaultValue: self.timeFormat)
        
        if self.percentage != percentage {
            self.percentage = percentage
            updated = true
        }
        if self.ACStatus != ACStatus {
            self.ACStatus = ACStatus
            updated = true
        }
        if self.charging != isCharging {
            self.charging = isCharging
            updated = true
        }
        if self.time != time {
            self.time = time
            updated = true
        }
        if self.timeFormat != timeFormat {
            self.timeFormat = timeFormat
            updated = true
        }
        
        if updated {
            DispatchQueue.main.async(execute: {
                self.display()
            })
        }
    }
    
    // MARK: - Settings
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 3) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: superview.frame.width - (Constants.Settings.margin*2),
            height: superview.frame.height - (Constants.Settings.margin*2)
        ))
        
        view.addSubview(SelectRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 2, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Additional information"),
            action: #selector(toggleAdditional),
            items: BatteryAdditionals,
            selected: self.additional
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 1, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Hide additional information when full"),
            action: #selector(toggleHideAdditionalWhenFull),
            state: self.hideAdditionalWhenFull
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: (rowHeight + Constants.Settings.margin) * 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Colorize"),
            action: #selector(toggleColor),
            state: self.colorState
        ))
        
        superview.addSubview(view)
    }
    
    @objc private func toggleAdditional(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.additional = key
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_additional", value: key)
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
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_hideAdditionalWhenFull", value: self.hideAdditionalWhenFull)
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
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState)
        self.display()
    }
}
