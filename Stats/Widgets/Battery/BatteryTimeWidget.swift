//
//  BatteryTimeWidget.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 12/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class BatteryTimeWidget: BatteryWidget {
    private var timeValue: NSTextField = NSTextField()
    private let timeWidth: CGFloat = 62
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: widgetSize.width, height: widgetSize.height))
        self.drawTime()
        self.changeWidth(width: self.timeWidth)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func drawTime() {
        self.timeValue = NSTextField(frame: NSMakeRect(0, 0, timeWidth, self.frame.size.height - 4))
        timeValue.isEditable = false
        timeValue.isSelectable = false
        timeValue.isBezeled = false
        timeValue.wantsLayer = true
        timeValue.textColor = .labelColor
        timeValue.backgroundColor = .controlColor
        timeValue.canDrawSubviewsIntoLayer = true
        timeValue.alignment = .right
        timeValue.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timeValue.stringValue = (self.time*60).printSecondsToHoursMinutesSeconds()
        
        self.addSubview(timeValue)
    }
    
    override func update() {
        if self.time <= 0 && self.size == self.batterySize + timeWidth {
            self.changeWidth(width: 0)
        } else if self.time >= 0 || self.size != self.batterySize + timeWidth {
            self.changeWidth(width: timeWidth)
        }
        
        self.timeValue.stringValue = (self.time*60).printSecondsToHoursMinutesSeconds()
    }
}
