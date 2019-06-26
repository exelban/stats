//
//  NetworkView.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 24.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkDotsView: NSView, Widget {
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
    
    override init(frame: NSRect) {
        self.download = 0
        self.upload = 0
        super.init(frame: CGRect(x: 0, y: 0, width: 12, height: frame.size.height))
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let workingHeight: CGFloat = (self.frame.size.height - (MODULE_MARGIN * 2))
        let height: CGFloat = ((workingHeight - MODULE_MARGIN) / 2) - 1
        
        var uploadCircle = NSBezierPath()
        uploadCircle = NSBezierPath(ovalIn: CGRect(x: MODULE_MARGIN, y: height + (MODULE_MARGIN * 2) + 1, width: height, height: height))
        if self.upload >= 1_024 {
            NSColor.red.setFill()
        } else {
            NSColor.labelColor.setFill()
        }
        uploadCircle.fill()
        
        var downloadCircle = NSBezierPath()
        downloadCircle = NSBezierPath(ovalIn: CGRect(x: MODULE_MARGIN, y: MODULE_MARGIN, width: height, height: height))
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
    
    func value(value: Double) {
        let values = value.splitAtDecimal()
        if self.download != values[0] {
            self.download = values[0]
        }
        if self.upload != values[1] {
            self.upload = values[1]
        }
    }
}

class NetworkTextView: NSView, Widget {
    var downloadValue: NSTextField = NSTextField()
    var uploadValue: NSTextField = NSTextField()
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: MODULE_WIDTH + 20, height: frame.size.height))
        self.wantsLayer = true
        self.valueView()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    func redraw() {
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
    
    func value(value: Double) {
        let values = value.splitAtDecimal()
        downloadValue.stringValue = Units(bytes: values[0]).getReadableUnit()
        uploadValue.stringValue = Units(bytes: values[1]).getReadableUnit()
    }
    
    func valueView() {
        downloadValue = NSTextField(frame: NSMakeRect(MODULE_MARGIN, MODULE_MARGIN, self.frame.size.width - MODULE_MARGIN, 9))
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
        
        uploadValue = NSTextField(frame: NSMakeRect(MODULE_MARGIN, self.frame.size.height - 10, self.frame.size.width - MODULE_MARGIN, 9))
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

class NetworkArrowsView: NSView, Widget {
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
    
    override init(frame: NSRect) {
        self.download = 0
        self.upload = 0
        super.init(frame: CGRect(x: 0, y: 0, width: 8, height: frame.size.height))
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let arrowAngle = CGFloat(Double.pi / 5)
        let pointerLineLength: CGFloat = 3.5
        let workingHeight: CGFloat = (self.frame.size.height - (MODULE_MARGIN * 2))
        let height: CGFloat = ((workingHeight - MODULE_MARGIN) / 2)
        
        let downloadArrow = NSBezierPath()
        let downloadStart = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: height + MODULE_MARGIN)
        let downloadEnd = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: MODULE_MARGIN)
        
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
        let uploadStart = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: height + (MODULE_MARGIN * 2))
        let uploadEnd = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: (MODULE_MARGIN * 2) + (height * 2))
        
        uploadArrow.addArrow(start: uploadStart, end: uploadEnd, pointerLineLength: pointerLineLength, arrowAngle: arrowAngle)
        
        if self.upload != 0 {
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
    
    func value(value: Double) {
        let values = value.splitAtDecimal()
        if self.download != values[0] {
            self.download = values[0]
        }
        if self.upload != values[1] {
            self.upload = values[1]
        }
    }
}

class NetworkDotsTextView: NSView, Widget {
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
        super.init(frame: CGRect(x: 0, y: 0, width: MODULE_WIDTH + 26, height: frame.size.height))
        self.wantsLayer = true
        self.valueView()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let workingHeight: CGFloat = (self.frame.size.height - (MODULE_MARGIN * 2))
        let height: CGFloat = ((workingHeight - MODULE_MARGIN) / 2) - 1
        
        var uploadCircle = NSBezierPath()
        uploadCircle = NSBezierPath(ovalIn: CGRect(x: MODULE_MARGIN, y: height + (MODULE_MARGIN * 2) + 1, width: height, height: height))
        if self.upload >= 1_024 {
            NSColor.red.setFill()
        } else {
            NSColor.labelColor.setFill()
        }
        uploadCircle.fill()
        
        var downloadCircle = NSBezierPath()
        downloadCircle = NSBezierPath(ovalIn: CGRect(x: MODULE_MARGIN, y: MODULE_MARGIN, width: height, height: height))
        if self.download != 0 {
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
    
    func value(value: Double) {
        let values = value.splitAtDecimal()
        if self.download != values[0] {
            self.download = values[0]
            downloadValue.stringValue = Units(bytes: self.download).getReadableUnit()
        }
        if self.upload != values[1] {
            self.upload = values[1]
            uploadValue.stringValue = Units(bytes: self.upload).getReadableUnit()
        }
    }
    
    func valueView() {
        downloadValue = NSTextField(frame: NSMakeRect(MODULE_MARGIN, MODULE_MARGIN, self.frame.size.width - MODULE_MARGIN, 9))
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
        
        uploadValue = NSTextField(frame: NSMakeRect(MODULE_MARGIN, self.frame.size.height - 10, self.frame.size.width - MODULE_MARGIN, 9))
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

class NetworkArrowsTextView: NSView, Widget {
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
        super.init(frame: CGRect(x: 0, y: 0, width: MODULE_WIDTH + 24, height: frame.size.height))
        self.wantsLayer = true
        self.valueView()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let arrowAngle = CGFloat(Double.pi / 5)
        let pointerLineLength: CGFloat = 3.5
        let workingHeight: CGFloat = (self.frame.size.height - (MODULE_MARGIN * 2))
        let height: CGFloat = ((workingHeight - MODULE_MARGIN) / 2)
        
        let downloadArrow = NSBezierPath()
        let downloadStart = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: height + MODULE_MARGIN)
        let downloadEnd = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: MODULE_MARGIN)
        
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
        let uploadStart = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: height + (MODULE_MARGIN * 2))
        let uploadEnd = CGPoint(x: MODULE_MARGIN + (pointerLineLength/2), y: (MODULE_MARGIN * 2) + (height * 2))
        
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
    
    func value(value: Double) {
        let values = value.splitAtDecimal()
        if self.download != values[0] {
            self.download = values[0]
            downloadValue.stringValue = Units(bytes: self.download).getReadableUnit()
        }
        if self.upload != values[1] {
            self.upload = values[1]
            uploadValue.stringValue = Units(bytes: self.upload).getReadableUnit()
        }
    }
    
    func valueView() {
        downloadValue = NSTextField(frame: NSMakeRect(MODULE_MARGIN, MODULE_MARGIN, self.frame.size.width - MODULE_MARGIN, 9))
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
        
        uploadValue = NSTextField(frame: NSMakeRect(MODULE_MARGIN, self.frame.size.height - 10, self.frame.size.width - MODULE_MARGIN, 9))
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
