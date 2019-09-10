//
//  BarChart.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 09.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class BarChart: NSView, Widget {
    var activeModule: Observable<Bool> = Observable(false)
    var size: CGFloat = widgetSize.width + 10
    let defaults = UserDefaults.standard
    
    var labelPadding: CGFloat = 12.0
    var label: Bool = false
    var name: String = ""
    var shortName: String = ""
    
    var menus: [NSMenuItem] = []
    
    var partitions: [Double] {
        didSet {
            self.redraw()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    override init(frame: NSRect) {
        self.label = defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : true
        self.partitions = Array(repeating: 0.0, count: 1)
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: widgetSize.height))
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func Init() {
        self.label = defaults.object(forKey: "\(name)_label") != nil ? defaults.bool(forKey: "\(name)_label") : true
        self.initPreferences()
    }
    
    func initPreferences() {
        let label = NSMenuItem(title: "Label", action: #selector(toggleLabel), keyEquivalent: "")
        label.state = self.label ? NSControl.StateValue.on : NSControl.StateValue.off
        label.target = self
        
        self.menus.append(label)
    }
    
    @objc func toggleLabel(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        self.defaults.set(sender.state == NSControl.StateValue.on, forKey: "\(self.name)_label")
        self.label = (sender.state == NSControl.StateValue.on)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8)
        let width = self.frame.size.width - (widgetSize.margin * 2)
        let height = self.frame.size.height - (widgetSize.margin * 2)
        
        var x = widgetSize.margin
        if label {
            x = x + labelPadding
        }
        
        let partitionMargin: CGFloat = 0.5
        let partitionsWidth: CGFloat = width - (partitionMargin * 2) - x
        var partitionWidth: CGFloat = partitionsWidth
        if partitions.count > 1 {
            partitionWidth = (partitionsWidth - (partitionMargin * (CGFloat(partitions.count) - 1))) / CGFloat(partitions.count)
        }
        
        for i in 0..<partitions.count {
            let partitionValue = partitions[i]
            var partitonHeight = ((height * CGFloat(partitionValue)) / 1)
            if partitonHeight < 1 {
                partitonHeight = 1
            }
            let partition = NSBezierPath(rect: NSRect(x: x, y: widgetSize.margin, width: partitionWidth - 0.5, height: partitonHeight))
            gradientColor.setFill()
            partition.fill()
            partition.close()
            
            x += partitionWidth + partitionMargin
        }
        
        if !self.label {
            return
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7.2, weight: .regular),
            NSAttributedString.Key.foregroundColor: NSColor.labelColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        let letterHeight = (self.frame.size.height - (widgetSize.margin*2)) / 3
        let letterWidth: CGFloat = 10.0
        
        var yMargin = widgetSize.margin
        for char in self.shortName.reversed() {
            let rect = CGRect(x: widgetSize.margin, y: yMargin, width: letterWidth, height: letterHeight)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)
            
            yMargin += letterHeight
        }
    }
    
    func setValue(data: [Double]) {
        self.partitions = data
    }
    
    func redraw() {
        var width: CGFloat = widgetSize.width + 10
        if self.partitions.count == 1 {
            width = 18
        }
        if self.partitions.count == 2 {
            width = 28
        }
        if self.label {
            width += labelPadding
        }
        
        if self.frame.size.width != width {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
            menuBar!.updateWidget(name: self.name)
        }
        
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
}
