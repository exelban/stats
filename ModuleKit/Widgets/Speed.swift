//
//  Speed.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit

public class SpeedWidget: WidgetWrapper {
    private var icon: String = "dots"
    private var state: Bool = false
    private var valueState: Bool = true
    private var baseValue: String = "byte"
    
    private var symbols: [String] = ["U", "D"]
    
    private var uploadField: NSTextField? = nil
    private var downloadField: NSTextField? = nil
    
    private var uploadValue: Int64 = 0
    private var downloadValue: Int64 = 0
    
    private let store: UnsafePointer<Store>?
    private var width: CGFloat = 58
    
    public init(title: String, config: NSDictionary?, store: UnsafePointer<Store>?, preview: Bool = false) {
        let widgetTitle: String = title
        self.store = store
        if config != nil {
            if let symbols = config!["Symbols"] as? [String] {
                self.symbols = symbols
            }
            if let icon = config!["Icon"] as? String {
                self.icon = icon
            }
        }
        
        super.init(.speed, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: width,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if self.store != nil && !preview {
            self.valueState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_value", defaultValue: self.valueState)
            self.icon = store!.pointee.string(key: "\(self.title)_\(self.type.rawValue)_icon", defaultValue: self.baseValue)
            self.baseValue = store!.pointee.string(key: "\(self.title)_base", defaultValue: self.baseValue)
        }
        
        if self.valueState && self.icon != "none" {
            self.state = true
        }
        
        if preview {
            self.downloadValue = 8947141
            self.uploadValue = 478678
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var width: CGFloat = 10
        var x: CGFloat = 10
        
        switch self.icon {
        case "dots":
            self.drawDots(dirtyRect)
        case "arrows":
            self.drawArrows(dirtyRect)
        case "chars":
            self.drawChars(dirtyRect)
        default:
            x = 0
            width = 0
            break
        }
        
        if self.valueState {
            let rowWidth: CGFloat = 48
            let rowHeight: CGFloat = self.frame.height / 2
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
                NSAttributedString.Key.foregroundColor: NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let base: DataSizeBase = DataSizeBase(rawValue: self.baseValue) ?? .byte
            var rect = CGRect(x: Constants.Widget.margin.x + x, y: 1, width: rowWidth - (Constants.Widget.margin.x*2), height: rowHeight)
            let download = NSAttributedString.init(string: Units(bytes: self.downloadValue).getReadableSpeed(base: base), attributes: stringAttributes)
            download.draw(with: rect)
            
            rect = CGRect(x: Constants.Widget.margin.x + x, y: rect.height+1, width: rowWidth - (Constants.Widget.margin.x*2), height: rowHeight)
            let upload = NSAttributedString.init(string: Units(bytes: self.uploadValue).getReadableSpeed(base: base), attributes: stringAttributes)
            upload.draw(with: rect)
            
            width += rowWidth
        }
        
        if width == 0 {
            width = 1
        }
        self.setWidth(width)
    }
    
    private func drawDots(_ dirtyRect: NSRect) {
        let rowHeight: CGFloat = self.frame.height / 2
        let size: CGFloat = 6
        let y: CGFloat = (rowHeight-size)/2
        
        var downloadCircle = NSBezierPath()
        downloadCircle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin.x, y: y-0.2, width: size, height: size))
        if self.downloadValue >= 1_024 {
            NSColor.systemBlue.set()
        } else {
            NSColor.textColor.setFill()
        }
        downloadCircle.fill()
        
        var uploadCircle = NSBezierPath()
        uploadCircle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin.x, y: 10.5, width: size, height: size))
        if self.uploadValue >= 1_024 {
            NSColor.red.setFill()
        } else {
            NSColor.textColor.setFill()
        }
        uploadCircle.fill()
    }
    
    private func drawArrows(_ dirtyRect: NSRect) {
        let arrowAngle = CGFloat(Double.pi / 5)
        let half = self.frame.size.height / 2
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth: CGFloat = 1
        let arrowSize: CGFloat = 3 + (scaleFactor/2)
        let x = Constants.Widget.margin.x + arrowSize + (lineWidth / 2)
        
        let downloadArrow = NSBezierPath()
        downloadArrow.addArrow(
            start: CGPoint(x: x, y: half - Constants.Widget.spacing/2),
            end: CGPoint(x: x, y: 0),
            pointerLineLength: arrowSize,
            arrowAngle: arrowAngle
        )
        
        if self.downloadValue >= 1_024 {
            NSColor.systemBlue.set()
        } else {
            NSColor.textColor.set()
        }
        downloadArrow.lineWidth = lineWidth
        downloadArrow.stroke()
        downloadArrow.close()
        
        let uploadArrow = NSBezierPath()
        uploadArrow.addArrow(
            start: CGPoint(x: x, y: half + Constants.Widget.spacing/2),
            end: CGPoint(x: x, y: self.frame.size.height),
            pointerLineLength: arrowSize,
            arrowAngle: arrowAngle
        )

        if self.uploadValue >= 1_024 {
            NSColor.red.set()
        } else {
            NSColor.textColor.set()
        }
        uploadArrow.lineWidth = lineWidth
        uploadArrow.stroke()
        uploadArrow.close()
    }
    
    private func drawChars(_ dirtyRect: NSRect) {
        let rowHeight: CGFloat = self.frame.height / 2
        
        if self.symbols.count > 1 {
            let downloadAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
                NSAttributedString.Key.foregroundColor: downloadValue >= 1_024 ? NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8) : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let rect = CGRect(x: Constants.Widget.margin.x, y: 1, width: 8, height: rowHeight)
            let str = NSAttributedString.init(string: self.symbols[1], attributes: downloadAttributes)
            str.draw(with: rect)
        }
        
        if self.symbols.count > 0 {
            let uploadAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
                NSAttributedString.Key.foregroundColor: uploadValue >= 1_024 ? NSColor.red : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let rect = CGRect(x: Constants.Widget.margin.x, y: rowHeight+1, width: 8, height: rowHeight)
            let str = NSAttributedString.init(string: self.symbols[0], attributes: uploadAttributes)
            str.draw(with: rect)
        }
    }
    
    public override func settings(width: CGFloat) -> NSView {
        let height: CGFloat = 90 + (Constants.Settings.margin*4)
        let rowHeight: CGFloat = 30
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: width - (Constants.Settings.margin*2),
            height: height
        ))
        
        view.addSubview(SelectRow(
            frame: NSRect(x: 0, y: (rowHeight+Constants.Settings.margin) * 2, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Pictogram"),
            action: #selector(toggleIcon),
            items: SpeedPictogram,
            selected: self.icon
        ))
        
        view.addSubview(SelectRow(
            frame: NSRect(x: 0, y: rowHeight + Constants.Settings.margin, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Base"),
            action: #selector(toggleBase),
            items: SpeedBase,
            selected: self.baseValue
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Value"),
            action: #selector(toggleValue),
            state: self.valueState
        ))
        
        return view
    }
    
    @objc private func toggleValue(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.valueState = state! == .on ? true : false
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_value", value: self.valueState)
        self.display()
        
        if !self.valueState && self.icon == .none {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.title, "state": false])
            self.state = false
        } else if !self.state {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.title, "state": true])
            self.state = true
        }
    }
    
    @objc private func toggleIcon(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.icon = key
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_icon", value: key)
        self.display()
        
        if !self.valueState && self.icon == "none" {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.title, "state": false])
            self.state = false
        } else if !self.state {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.title, "state": true])
            self.state = true
        }
    }
    
    @objc private func toggleBase(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.baseValue = key
        self.store?.pointee.set(key: "\(self.title)_base", value: self.baseValue)
    }
    
    public func setValue(upload: Int64, download: Int64) {
        var updated: Bool = false
        
        if self.downloadValue != download {
            self.downloadValue = abs(download)
            updated = true
        }
        if self.uploadValue != upload {
            self.uploadValue = abs(upload)
            updated = true
        }
        
        if updated {
            DispatchQueue.main.async(execute: {
                self.display()
            })
        }
    }
}
