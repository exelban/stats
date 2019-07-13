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
    var active: Observable<Bool> = Observable(false)
    var size: CGFloat = widgetSize.width + 10
    
    var labelPadding: CGFloat = 12.0
    var labelEnabled: Bool = false
    var labelText: String = ""
    
    var partitions: [Double] {
        didSet {
            self.redraw()
        }
    }
    
    override init(frame: NSRect) {
        self.partitions = Array(repeating: 0.0, count: 1)
        super.init(frame: CGRect(x: 0, y: 0, width: self.size, height: widgetSize.height))
        self.wantsLayer = true
        self.addSubview(NSView())
        
        if self.labelEnabled {
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width + labelPadding, height: self.frame.size.height)
        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let gradientColor: NSColor = NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8)
        let width = self.frame.size.width - (widgetSize.margin * 2)
        let height = self.frame.size.height - (widgetSize.margin * 2)
        
        var x = widgetSize.margin
        if labelEnabled {
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
        
        if !self.labelEnabled {
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
        for char in self.labelText.reversed() {
            let rect = CGRect(x: widgetSize.margin, y: yMargin, width: letterWidth, height: letterHeight)
            let str = NSAttributedString.init(string: "\(char)", attributes: stringAttributes)
            str.draw(with: rect)
            
            yMargin += letterHeight
        }
    }
    
    func setValue(data: [Double]) {
        self.partitions = data
    }
    
    func toggleLabel(state: Bool) {
        labelEnabled = state
        var width = self.frame.size.width
        if width == widgetSize.width + 10 && state {
            width = width + labelPadding
        } else {
            width = widgetSize.width + 10
        }
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
    }
    
    func redraw() {
        var width: CGFloat = widgetSize.width + 10
        if self.partitions.count == 1 {
            width = 18
        }
        if self.partitions.count == 2 {
            width = 28
        }
        if self.labelEnabled {
            width += labelPadding
        }
        
        if self.frame.size.width != width {
            self.activeModule << false
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: width, height: self.frame.size.height)
            self.activeModule << true
        }
        
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
}
