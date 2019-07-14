//
//  NetworkArrowsText.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkArrowsTextView: NSView, Widget {
    var menus: [NSMenuItem] = []
    var activeModule: Observable<Bool> = Observable(false)
    var size: CGFloat = widgetSize.width + 24
    var name: String = ""
    var shortName: String = ""
    
    var color: Observable<Bool> = Observable(false)
    var download: Int64 {
        didSet {
            self.redraw()
        }
    }
    var upload: Int64 {
        didSet {
            self.redraw()
        }
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
    
    func Init() {}
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let arrowAngle = CGFloat(Double.pi / 5)
        let pointerLineLength: CGFloat = 3.5
        let workingHeight: CGFloat = (self.frame.size.height - (widgetSize.margin * 2))
        let height: CGFloat = ((workingHeight - widgetSize.margin) / 2)
        
        let downloadArrow = NSBezierPath()
        let downloadStart = CGPoint(x: widgetSize.margin + (pointerLineLength/2), y: height + widgetSize.margin)
        let downloadEnd = CGPoint(x: widgetSize.margin + (pointerLineLength/2), y: widgetSize.margin)
        
        downloadArrow.addArrow(start: downloadStart, end: downloadEnd, pointerLineLength: pointerLineLength, arrowAngle: arrowAngle)
        
        if self.download >= 1_024 {
            NSColor(red: (26/255.0), green: (126/255.0), blue: (252/255.0), alpha: 0.8).set()
        } else {
            NSColor.labelColor.set()
        }
        downloadArrow.lineWidth = 1
        downloadArrow.stroke()
        downloadArrow.close()
        
        let uploadArrow = NSBezierPath()
        let uploadStart = CGPoint(x: widgetSize.margin + (pointerLineLength/2), y: height + (widgetSize.margin * 2))
        let uploadEnd = CGPoint(x: widgetSize.margin + (pointerLineLength/2), y: (widgetSize.margin * 2) + (height * 2))
        
        uploadArrow.addArrow(start: uploadStart, end: uploadEnd, pointerLineLength: pointerLineLength, arrowAngle: arrowAngle)
        
        if self.upload >= 1_024 {
            NSColor.red.set()
        } else {
            NSColor.labelColor.set()
        }
        uploadArrow.lineWidth = 1
        uploadArrow.stroke()
        uploadArrow.close()
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
            downloadValue.stringValue = Units(bytes: self.download).getReadableUnit()
        }
        if self.upload != upload {
            self.upload = upload
            uploadValue.stringValue = Units(bytes: self.upload).getReadableUnit()
        }
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
