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
        let rowHeight: CGFloat = self.frame.height / 2
        var totalWidth: CGFloat = Constants.Widget.margin  // opening space
        var x: CGFloat = Constants.Widget.margin
        
        for i in 0..<num {
            if !self.values.indices.contains(i*2) {
                continue
            }
            var width: CGFloat = 0
            var paddingLeft: CGFloat = 0
            
            if self.values.indices.contains((i*2)+1) {
                var font: NSFont = NSFont.systemFont(ofSize: 9, weight: .light)
                if #available(OSX 10.15, *) {
                    font = NSFont.monospacedSystemFont(ofSize: 9, weight: .light)
                }
                let style = NSMutableParagraphStyle()
                style.alignment = .right
                
                let firstRowWidth = self.values[i*2].value.widthOfString(usingFont: font)
                let secondRowWidth = self.values[(i*2)+1].value.widthOfString(usingFont: font)
                width = max(20, max(firstRowWidth, secondRowWidth)).rounded(.up)
                
                if self.iconState && (self.values[i*2].icon != nil || self.values[(i*2)+1].icon != nil) {
                    let iconSize: CGFloat = 8
                    if let icon = self.values[i*2].icon {
                        icon.draw(in: NSRect(x: x, y: rowHeight+((rowHeight-iconSize)/2), width: iconSize, height: iconSize))
                    }
                    if let icon = self.values[(i*2)+1].icon {
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
                
                var rect = CGRect(x: x+paddingLeft, y: rowHeight+1, width: width-paddingLeft, height: rowHeight)
                var str = NSAttributedString.init(string: self.values[i*2].value, attributes: attributes)
                str.draw(with: rect)
                
                rect = CGRect(x: x+paddingLeft, y: 1, width: width-paddingLeft, height: rowHeight)
                str = NSAttributedString.init(string: self.values[(i*2)+1].value, attributes: attributes)
                str.draw(with: rect)
            } else {
                let font: NSFont = NSFont.systemFont(ofSize: 13, weight: .light)
                width = self.values[i*2].value.widthOfString(usingFont: font).rounded(.up)
                
                if let icon = self.values[i*2].icon, self.iconState {
                    let iconSize: CGFloat = 11
                    icon.draw(in: NSRect(x: x, y: ((Constants.Widget.height-iconSize)/2)-2, width: iconSize, height: iconSize))
                    paddingLeft = iconSize + (Constants.Widget.margin*3)
                    width += paddingLeft
                }
                
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                let rect = CGRect(x: x+paddingLeft, y: (Constants.Widget.height-13)/2, width: width-paddingLeft, height: 13)
                let str = NSAttributedString.init(string: self.values[i*2].value, attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: NSColor.textColor,
                    NSAttributedString.Key.paragraphStyle: style
                ])
                str.draw(with: rect)
            }
            
            x += width
            totalWidth += width
            
            // add margins between columns
            if num != 1 && (i/2) != num {
                x += Constants.Widget.margin
                totalWidth += Constants.Widget.margin
            }
        }
        totalWidth += Constants.Widget.margin // closing space
        
        if abs(self.frame.width - totalWidth) < 2 {
            return
        }
        self.setWidth(totalWidth)
    }
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 1) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(x: Constants.Settings.margin, y: Constants.Settings.margin, width: superview.frame.width - (Constants.Settings.margin*2), height: superview.frame.height - (Constants.Settings.margin*2)))
        
        view.addSubview(ToggleTitleRow(
            frame: NSRect(x: 0, y: 0, width: view.frame.width, height: rowHeight),
            title: LocalizedString("Pictogram"),
            action: #selector(toggleIcom),
            state: self.iconState
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
}
