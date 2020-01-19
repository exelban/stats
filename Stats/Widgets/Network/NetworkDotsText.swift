//
//  NetworkDotsText.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkDotsTextView: NSView, Widget {
    public var menus: [NSMenuItem] = []
    public var size: CGFloat = widgetSize.width + 26
    public var name: String = ""
    
    private var download: Int64 = 0
    private var upload: Int64 = 0
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    var downloadValue: NSTextField = NSTextField()
    var uploadValue: NSTextField = NSTextField()
    
    override init(frame: NSRect) {
        self.download = 0
        self.upload = 0
        super.init(frame: CGRect(x: 0, y: 0, width: self.size, height: widgetSize.height))
        self.wantsLayer = true
        self.valueView()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func start() {}
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let workingHeight: CGFloat = (self.frame.size.height - (widgetSize.margin * 2))
        let height: CGFloat = ((workingHeight - widgetSize.margin) / 2) - 1
        
        var uploadCircle = NSBezierPath()
        uploadCircle = NSBezierPath(ovalIn: CGRect(x: widgetSize.margin, y: height + (widgetSize.margin * 2) + 1, width: height, height: height))
        if self.upload >= 1_024 {
            NSColor.red.setFill()
        } else {
            NSColor.labelColor.setFill()
        }
        uploadCircle.fill()
        
        var downloadCircle = NSBezierPath()
        downloadCircle = NSBezierPath(ovalIn: CGRect(x: widgetSize.margin, y: widgetSize.margin, width: height, height: height))
        if self.download >= 1_024 {
            NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8).setFill()
        } else {
            NSColor.labelColor.setFill()
        }
        downloadCircle.fill()
    }
    
    func redraw() {
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
    
    func setValue(data: [Double]) {
        let download: Int64 = Int64(data[0])
        let upload: Int64 = Int64(data[1])
        
        if self.download != download {
            self.download = download
            downloadValue.stringValue = Units(bytes: self.download).getReadableSpeed()
        }
        if self.upload != upload {
            self.upload = upload
            uploadValue.stringValue = Units(bytes: self.upload).getReadableSpeed()
        }
        
        self.redraw()
    }
    
    func valueView() {
        downloadValue = NSTextField(frame: NSMakeRect(widgetSize.margin, widgetSize.margin, self.frame.size.width - widgetSize.margin, 9))
        downloadValue.isEditable = false
        downloadValue.isSelectable = false
        downloadValue.isBezeled = false
        downloadValue.wantsLayer = true
        downloadValue.textColor = .labelColor
        downloadValue.backgroundColor = .controlColor
        downloadValue.canDrawSubviewsIntoLayer = true
        downloadValue.alignment = .right
        downloadValue.font = NSFont.systemFont(ofSize: 9, weight: .light)
        downloadValue.stringValue = "0 KB/s"
        
        uploadValue = NSTextField(frame: NSMakeRect(widgetSize.margin, self.frame.size.height - 10, self.frame.size.width - widgetSize.margin, 9))
        uploadValue.isEditable = false
        uploadValue.isSelectable = false
        uploadValue.isBezeled = false
        uploadValue.wantsLayer = true
        uploadValue.textColor = .labelColor
        uploadValue.backgroundColor = .controlColor
        uploadValue.canDrawSubviewsIntoLayer = true
        uploadValue.alignment = .right
        uploadValue.font = NSFont.systemFont(ofSize: 9, weight: .light)
        uploadValue.stringValue = "0 KB/s"
        
        self.addSubview(downloadValue)
        self.addSubview(uploadValue)
    }
}
