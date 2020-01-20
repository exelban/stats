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
    private let timeHourWidth: CGFloat = 42
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: widgetSize.width, height: widgetSize.height))
        self.drawTime()
        self.changeWidth(width: self.timeWidth)
        self.update()
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
        if self.time <= 0 {
            timeValue.isHidden = true
        }
        
        self.addSubview(timeValue)
    }
    
    override func update() {
        if self.value == 0 { return }
        
        if self.time > 0 {
            if self.timeValue.isHidden {
                self.timeValue.isHidden = false
            }
            self.timeValue.stringValue = (self.time*60).printSecondsToHoursMinutesSeconds()
        }

        if self.time <= 0 {
            self.changeWidth(width: 0)
            self.timeValue.frame.size.width = 0
            self.timeValue.isHidden = true
        } else if self.time <= 59 {
            self.changeWidth(width: timeHourWidth)
            self.timeValue.frame.size.width = timeHourWidth
        } else if self.time > 59 {
            self.changeWidth(width: timeWidth)
            self.timeValue.frame.size.width = timeWidth
        }
    }
}
