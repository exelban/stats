//
//  CPU.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 01.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class ChartView: NSView {
    var valueLabel: NSTextField = NSTextField()
    
    var label: Bool = false
    var points: [Double] {
        didSet {
            setNeedsDisplay(self.frame)
        }
    }
    
    override init(frame: NSRect) {
        self.points = Array(repeating: 0.0, count: 50)
        super.init(frame: frame)
        
        self.wantsLayer = true
        
        if self.label {
            let valueLabel = NSTextField(frame: NSMakeRect(2, MODULE_HEIGHT - 11, self.frame.size.width, 10))
            valueLabel.textColor = NSColor.red
            valueLabel.isEditable = false
            valueLabel.isSelectable = false
            valueLabel.isBezeled = false
            valueLabel.wantsLayer = true
            valueLabel.textColor = .labelColor
            valueLabel.backgroundColor = .controlColor
            valueLabel.canDrawSubviewsIntoLayer = true
            valueLabel.alignment = .natural
            valueLabel.font = NSFont.systemFont(ofSize: 8, weight: .ultraLight)
            valueLabel.stringValue = ""
            valueLabel.addSubview(NSView())
            
            self.valueLabel = valueLabel
            self.addSubview(self.valueLabel)
        } else {
            self.addSubview(NSView())
        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if (self.points.count < 2) {
            return
        }
        
        let xOffset: CGFloat = 4.0
        let yOffset: CGFloat = 3.0
        var height: Double = Double(self.frame.size.height) - Double((yOffset * 2))
        if self.label {
            height = 7.0
        }
        let xRatio = Double(self.frame.size.width - (xOffset * 2)) / (Double(self.points.count) - 1)

        let chartLine = NSBezierPath()
        chartLine.lineWidth = 0.5
        
        for i in 0..<self.points.count {
            let x: CGFloat = CGFloat((Double(i) * xRatio)) + xOffset
            let y: CGFloat = CGFloat((Double(truncating: points[i] as NSNumber) * height)) + yOffset
            let point = CGPoint(x: x, y: y)
            
            if i == 0 {
                chartLine.move(to: point)
            } else {
                chartLine.line(to: point)
            }
        }
//        chartLine.close()

        NSColor.blue.setStroke()
        chartLine.stroke()
        
//        let gradient: NSGradient = NSGradient(starting: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), ending: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))!
//        gradient.draw(in: chartLine, angle: 0.0)
    }
    
    func addValue(value: Double) {
        if self.label {
            self.valueLabel.stringValue = "\(Int(Float(Float(value).roundTo(decimalPlaces: 2))! * 100))%"
            self.valueLabel.textColor = Float(value).usageColor()
        }
        
        if self.points.count < 50 {
            self.points.append(value)
            return
        }
        
        for (i, _) in self.points.enumerated() {
            if i+1 < self.points.count {
                self.points[i] = self.points[i+1]
            } else {
                self.points[i] = value
            }
        }
    }
}

class CPU: Module {
    let name: String = "CPU"
    var view: NSView = NSView()
    var chart: ChartView = ChartView()
    let defaults = UserDefaults.standard
    
    var active: Observable<Bool>
    var reader: Reader = CPUReader()
    
    @IBOutlet weak var value: NSTextField!
    
    init() {
        self.active = Observable(defaults.object(forKey: name) != nil ? defaults.bool(forKey: name) : true)
        self.chart = ChartView(frame: NSMakeRect(0, 0, MODULE_WIDTH + 7, MODULE_HEIGHT))
        self.view.wantsLayer = true
        self.view = self.chart
    }
    
    func start() {
        if !self.reader.usage.value.isNaN {
            self.chart.addValue(value: Double(self.reader.usage!.value))
//            self.value.stringValue = "\(Int(Float(self.reader.usage.value.roundTo(decimalPlaces: 2))! * 100))%"
//            self.value.textColor = self.reader.usage.value.usageColor()
        }
//
        self.reader.start()
        self.reader.usage.subscribe(observer: self) { (value, _) in
            if !value.isNaN {
                self.chart.addValue(value: Double(self.reader.usage!.value))
//                self.value.stringValue = "\(Int(Float(value.roundTo(decimalPlaces: 2))! * 100))%"
//                self.value.textColor = value.usageColor()
            }
        }
//
//        colors.subscribe(observer: self) { (value, _) in
//            self.value.textColor = self.reader.usage.value.usageColor()
//        }
    }
    
    func menu() -> NSMenuItem {
        let menu = NSMenuItem(title: name, action: #selector(toggle), keyEquivalent: "")
        if defaults.object(forKey: name) != nil {
            menu.state = defaults.bool(forKey: name) ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            menu.state = NSControl.StateValue.on
        }
        menu.target = self
        menu.isEnabled = true
        return menu
    }
    
    @objc func toggle(_ sender: NSMenuItem) {
        let state = sender.state != NSControl.StateValue.on
        
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(state, forKey: name)
        self.active << state
        
        if !state {
            self.stop()
        } else {
            self.start()
        }
    }
}
