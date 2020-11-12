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

public class SensorsWidget: Widget {
    private var modeState: String = "automatic"
    private let store: UnsafePointer<Store>?
    
    private var body: CALayer = CALayer()
    private var values: [KeyValue_t] = []
    
    public init(preview: Bool, title: String, config: NSDictionary?, store: UnsafePointer<Store>?) {
        self.store = store
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
        super.init(frame: CGRect(
            x: 0,
            y: Constants.Widget.margin,
            width: Constants.Widget.width,
            height: Constants.Widget.height - (2*Constants.Widget.margin)
        ))
        self.title = title
        self.type = .sensors
        self.preview = preview
        
        self.modeState = store?.pointee.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState) ?? self.modeState
        
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        self.body.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        self.layer?.addSublayer(self.body)
        
        self.draw(self.values)
        self.setFrameSize(NSSize(width: self.body.frame.width, height: self.frame.size.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func draw(_ list: [KeyValue_t]) {
        self.body.sublayers?.forEach{ $0.removeFromSuperlayer() }
        
        let num: Int = Int(round(Double(list.count) / 2))
        var totalWidth: CGFloat = Constants.Widget.margin  // opening space
        var x: CGFloat = Constants.Widget.margin
        
        var i = 0
        while i < list.count {
            switch self.modeState {
            case "automatic", "twoRows":
                let firstSensor: KeyValue_t = list[i]
                let secondSensor: KeyValue_t? = list.indices.contains(i+1) ? list[i+1] : nil
                
                var width: CGFloat = 0
                if self.modeState == "automatic" && secondSensor == nil {
                    width += self.drawOneRow(firstSensor, x: x)
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
                if list.count != 1 && i != list.count {
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
        var frame = self.body.frame
        frame.size = CGSize(width: totalWidth, height: frame.height)
        self.body.frame = frame
    }
    
    private func drawOneRow(_ sensor: KeyValue_t, x: CGFloat) -> CGFloat {
        var font: NSFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        if #available(OSX 10.15, *) {
            font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        }
        let width = sensor.value.widthOfString(usingFont: font).rounded(.up) + 2
        
        let value = CAText(fontSize: 14)
        value.name = sensor.key
        value.frame = CGRect(x: x, y: (Constants.Widget.height-14)/2, width: width, height: 14)
        value.font = font
        value.string = sensor.value
        value.alignmentMode = .right
        
        self.body.addSublayer(value)
        
        return width
    }
    
    private func drawTwoRows(topSensor: KeyValue_t, bottomSensor: KeyValue_t?, x: CGFloat) -> CGFloat {
        var font: NSFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        if #available(OSX 10.15, *) {
            font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        }
        
        let firstRowWidth = topSensor.value.widthOfString(usingFont: font)
        let secondRowWidth = bottomSensor?.value.widthOfString(usingFont: font)
        
        let width = max(20, max(firstRowWidth, secondRowWidth ?? 0)).rounded(.up) + 2
        let height: CGFloat = self.frame.height / 2
        
        let topValue = CAText(fontSize: 10)
        topValue.name = topSensor.key
        topValue.frame = CGRect(x: x, y: height+1, width: width, height: height+1)
        topValue.font = font
        topValue.string = topSensor.value
        topValue.alignmentMode = .right
        
        let bottomValue = CAText(fontSize: 10)
        bottomValue.name = bottomSensor?.key
        bottomValue.frame = CGRect(x: x, y: 1, width: width, height: height+1)
        bottomValue.font = font
        bottomValue.string = bottomSensor?.value ?? ""
        bottomValue.alignmentMode = .right
        
        self.body.addSublayer(topValue)
        self.body.addSublayer(bottomValue)
        
        return width
    }
    
    public func setValues(_ values: [KeyValue_t]) {
        self.values = values
        
        DispatchQueue.main.async(execute: {
            if self.body.sublayers?.count != values.count {
                self.redraw(values)
            } else {
                values.forEach { (new: KeyValue_t) in
                    guard let caLayer = self.body.sublayers!.first(where: { $0.name == new.key }) else {
                        self.redraw(values)
                        return
                    }
                    
                    if let layer = caLayer as? CAText, layer.string as! String != new.value {
                        CATransaction.disableAnimations {
                            layer.string = new.value
                            if abs(layer.frame.width - layer.getWidth(add: 2)) > 2 {
                                self.redraw(values)
                                return
                            }
                        }
                    }
                }
            }
        })
    }
    
    private func redraw(_ values: [KeyValue_t]) {
        self.draw(values)
        self.setWidth(self.body.frame.width)
    }
    
    // MARK: - Settings
    
    public override func settings(superview: NSView) {
        let rowHeight: CGFloat = 30
        let height: CGFloat = ((rowHeight + Constants.Settings.margin) * 1) + Constants.Settings.margin
        superview.setFrameSize(NSSize(width: superview.frame.width, height: height))
        
        let view: NSView = NSView(frame: NSRect(
            x: Constants.Settings.margin,
            y: Constants.Settings.margin,
            width: superview.frame.width - (Constants.Settings.margin*2),
            height: superview.frame.height - (Constants.Settings.margin*2)
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
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.modeState = key
        store?.pointee.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
        self.redraw(self.values)
    }
}
