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
    private let timeWidth: CGFloat = 60
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: widgetSize.width, height: widgetSize.height))
        self.drawTime()
        self.changeWidth(width: self.timeWidth)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func drawTime() {
        self.timeValue = NSTextField(frame: NSMakeRect(0, 0, timeWidth, self.frame.size.height - 2))
        timeValue.isEditable = false
        timeValue.isSelectable = false
        timeValue.isBezeled = false
        timeValue.wantsLayer = true
        timeValue.textColor = .labelColor
        timeValue.backgroundColor = .controlColor
        timeValue.canDrawSubviewsIntoLayer = true
        timeValue.alignment = .right
        timeValue.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        timeValue.stringValue = "\(Int(self.value * 100))%"
        
        self.addSubview(timeValue)
    }
    
    override func update() {
        if self.value == 0 { return }
        self.timeValue.stringValue = "\(Int(self.value * 100))%"
        
        
    }
}
