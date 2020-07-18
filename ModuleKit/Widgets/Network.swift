//
//  Network.swift
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

public enum network_icon_t: String {
    case none = "None"
    case separator = "separator"
    case dot = "Dots"
    case arrow = "Arrows"
    case char = "Character"
}
extension network_icon_t: CaseIterable {}

public class NetworkWidget: Widget {
    private var icon: network_icon_t = .dot
    private var state: Bool = false
    private var valueState: Bool = true
    
    private var uploadField: NSTextField? = nil
    private var downloadField: NSTextField? = nil
    
    private var uploadValue: Int64 = 0
    private var downloadValue: Int64 = 0
    
    private let store: UnsafePointer<Store>?
    private var width: CGFloat = 58
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        let widgetTitle: String = title
        self.store = store
        super.init(frame: CGRect(x: 0, y: Constants.Widget.margin, width: width, height: Constants.Widget.height - (2*Constants.Widget.margin)))
        self.title = widgetTitle
        self.type = .network
        self.preview = preview
        self.canDrawConcurrently = true
        
        if self.store != nil {
            self.valueState = store!.pointee.bool(key: "\(self.title)_\(self.type.rawValue)_value", defaultValue: self.valueState)
            self.icon = network_icon_t(rawValue: store!.pointee.string(key: "\(self.title)_\(self.type.rawValue)_icon", defaultValue: self.icon.rawValue)) ?? self.icon
        }
        
        if self.valueState && self.icon != .none {
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
        case .dot:
            self.drawDots(dirtyRect)
        case .arrow:
            self.drawArrows(dirtyRect)
        case .char:
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
            
            var rect = CGRect(x: Constants.Widget.margin + x, y: 1, width: rowWidth - (Constants.Widget.margin*2), height: rowHeight)
            let download = NSAttributedString.init(string: Units(bytes: self.downloadValue).getReadableSpeed(), attributes: stringAttributes)
            download.draw(with: rect)
            
            rect = CGRect(x: Constants.Widget.margin + x, y: rect.height+1, width: rowWidth - (Constants.Widget.margin*2), height: rowHeight)
            let upload = NSAttributedString.init(string: Units(bytes: self.uploadValue).getReadableSpeed(), attributes: stringAttributes)
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
        downloadCircle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin, y: y-0.2, width: size, height: size))
        if self.downloadValue >= 1_024 {
            NSColor.systemBlue.set()
        } else {
            NSColor.textColor.setFill()
        }
        downloadCircle.fill()
        
        var uploadCircle = NSBezierPath()
        uploadCircle = NSBezierPath(ovalIn: CGRect(x: Constants.Widget.margin, y: 10.5, width: size, height: size))
        if self.uploadValue >= 1_024 {
            NSColor.red.setFill()
        } else {
            NSColor.textColor.setFill()
        }
        uploadCircle.fill()
    }
    
    private func drawArrows(_ dirtyRect: NSRect) {
        let arrowAngle = CGFloat(Double.pi / 5)
        let pointerLineLength: CGFloat = 3.5
        let workingHeight: CGFloat = (self.frame.size.height - (Constants.Widget.margin * 2))
        let height: CGFloat = ((workingHeight - Constants.Widget.margin) / 2)
        
        let downloadArrow = NSBezierPath()
        let downloadStart = CGPoint(x: Constants.Widget.margin + (pointerLineLength/2), y: height + Constants.Widget.margin)
        let downloadEnd = CGPoint(x: Constants.Widget.margin + (pointerLineLength/2), y: Constants.Widget.margin)
        downloadArrow.addArrow(start: downloadStart, end: downloadEnd, pointerLineLength: pointerLineLength, arrowAngle: arrowAngle)
        
        if self.downloadValue >= 1_024 {
            NSColor.systemBlue.set()
        } else {
            NSColor.textColor.set()
        }
        downloadArrow.lineWidth = 1
        downloadArrow.stroke()
        downloadArrow.close()
        
        let uploadArrow = NSBezierPath()
        let uploadStart = CGPoint(x: Constants.Widget.margin + (pointerLineLength/2), y: height + (Constants.Widget.margin * 2))
        let uploadEnd = CGPoint(x: Constants.Widget.margin + (pointerLineLength/2), y: (Constants.Widget.margin * 2) + (height * 2))
        uploadArrow.addArrow(start: uploadStart, end: uploadEnd, pointerLineLength: pointerLineLength, arrowAngle: arrowAngle)
        
        if self.uploadValue >= 1_024 {
            NSColor.red.set()
        } else {
            NSColor.textColor.set()
        }
        uploadArrow.lineWidth = 1
        uploadArrow.stroke()
        uploadArrow.close()
    }
    
    private func drawChars(_ dirtyRect: NSRect) {
        let rowHeight: CGFloat = self.frame.height / 2
        
        let downloadAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
            NSAttributedString.Key.foregroundColor: downloadValue >= 1_024 ? NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8) : NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
        ]
        var rect = CGRect(x: Constants.Widget.margin, y: 1, width: 8, height: rowHeight)
        var str = NSAttributedString.init(string: "D", attributes: downloadAttributes)
        str.draw(with: rect)
        
        let uploadAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .regular),
            NSAttributedString.Key.foregroundColor: uploadValue >= 1_024 ? NSColor.red : NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
        ]
        rect = CGRect(x: Constants.Widget.margin, y: rect.height+1, width: 8, height: rowHeight)
        str = NSAttributedString.init(string: "U", attributes: uploadAttributes)
        str.draw(with: rect)
    }
    
    public override func settings(superview: NSView) {
        let height: CGFloat = 60 + (Constants.Settings.margin*3)
        let rowHeight: CGFloat = 30
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(SelectTitleRow(
            frame: NSRect(x: 0, y: rowHeight + Constants.Settings.margin, width: view.frame.width, height: rowHeight),
            title: "Pictogram",
            action: #selector(toggleIcon),
            items: network_icon_t.allCases.map{ return $0.rawValue },
            selected: self.icon.rawValue
        ))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: rowHeight),
            title: "Value",
            action: #selector(toggleValue),
            state: self.valueState
        ))
        
        superview.addSubview(view)
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
        let newIcon: network_icon_t = network_icon_t(rawValue: sender.title) ?? .none
        self.icon = newIcon
        self.store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_icon", value: self.icon.rawValue)
        self.display()
        
        if !self.valueState && self.icon == .none {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.title, "state": false])
            self.state = false
        } else if !self.state {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.title, "state": true])
            self.state = true
        }
    }
    
    public func setValue(upload: Int64, download: Int64) {
        var updated: Bool = false
        
        if self.downloadValue != download {
            self.downloadValue = download
            updated = true
        }
        if self.uploadValue != upload {
            self.uploadValue = upload
            updated = true
        }
        
        if updated {
            DispatchQueue.main.async(execute: {
                self.display()
            })
        }
    }
}
