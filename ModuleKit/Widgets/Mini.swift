//
//  Mini.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class Mini: Widget {
    public var valueView: NSTextField = NSTextField()
    public var labelView: NSTextField = NSTextField()
    
    public let color: Bool = true
    public let label: Bool = true
    
    private let onlyValueWidth: CGFloat = 42
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: widgetConst.y, width: widgetConst.width, height: widgetConst.height - (2*widgetConst.y)))
        self.wantsLayer = true
        
        var xOffset: CGFloat = 2
        var width: CGFloat = self.frame.size.width - (xOffset * 3)
        var height: CGFloat = 10
        var y: CGFloat = 1
        var fontSize: CGFloat = 10
        var valueAligment: NSTextAlignment = .natural
        
        if self.label {
            let labelView = NSTextField(frame: NSMakeRect(xOffset, 11, width, 8))
            labelView.isEditable = false
            labelView.isSelectable = false
            labelView.isBezeled = false
            labelView.wantsLayer = true
            labelView.textColor = .labelColor
            labelView.backgroundColor = .controlColor
            labelView.canDrawSubviewsIntoLayer = true
            labelView.alignment = .natural
            labelView.font = NSFont.systemFont(ofSize: 8, weight: .light)
            labelView.stringValue = ""
            labelView.addSubview(NSView())

            self.labelView = labelView
            self.addSubview(self.labelView)
        } else {
            xOffset = 0
            width = onlyValueWidth
            height = self.frame.height - 2
            y = 1
            fontSize = 13
            valueAligment = .center
            self.setWidth(onlyValueWidth)
        }
        
        let valueView = NSTextField(frame: NSMakeRect(xOffset, y, width, height))
        valueView.isEditable = false
        valueView.isSelectable = false
        valueView.isBezeled = false
        valueView.wantsLayer = true
        valueView.textColor = .labelColor
        valueView.backgroundColor = .controlColor
        valueView.canDrawSubviewsIntoLayer = true
        valueView.alignment = valueAligment
        valueView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        valueView.stringValue = ""
        valueView.addSubview(NSView())
        
        self.valueView = valueView
        self.addSubview(self.valueView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func setTitle(_ title: String) {
        self.title = title
        self.labelView.stringValue = String(title.prefix(3)).uppercased()
    }
}
