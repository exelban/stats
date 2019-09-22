//
//  BatteryPercentageWidget.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 12/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class BatteryPercentageWidget: BatteryWidget {
    private var percentageValue: NSTextField = NSTextField()
    
    private let percentageLowWidth: CGFloat = 23
    private let percentageWidth: CGFloat = 30
    private let percentageFullWidth: CGFloat = 36
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: widgetSize.width, height: widgetSize.height))
        self.drawPercentage()
        self.update()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func drawPercentage() {
        self.percentageValue = NSTextField(frame: NSMakeRect(0, 0, percentageWidth, self.frame.size.height - 2))
        percentageValue.isEditable = false
        percentageValue.isSelectable = false
        percentageValue.isBezeled = false
        percentageValue.wantsLayer = true
        percentageValue.textColor = .labelColor
        percentageValue.backgroundColor = .controlColor
        percentageValue.canDrawSubviewsIntoLayer = true
        percentageValue.alignment = .right
        percentageValue.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        percentageValue.stringValue = "\(Int(self.value * 100))%"
        
        self.addSubview(percentageValue)
    }
    
    override func update() {
        if self.value == 0 { return }
        self.percentageValue.stringValue = "\(Int(self.value * 100))%"
        
        if self.value == 1 && self.size != self.batterySize + percentageFullWidth {
            self.changeWidth(width: 0)
            self.percentageValue.frame.size.width = 0
        } else if self.value < 0.1 && self.size != self.batterySize + percentageLowWidth {
            self.changeWidth(width: percentageLowWidth)
            self.percentageValue.frame.size.width = percentageLowWidth
        } else if self.value >= 0.1 && self.value != 1 && self.size != self.batterySize + percentageWidth {
            self.changeWidth(width: percentageWidth)
            self.percentageValue.frame.size.width = percentageWidth
        }
    }
}
