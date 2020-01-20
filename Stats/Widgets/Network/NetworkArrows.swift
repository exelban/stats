//
//  NetworkArrows.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkArrowsView: NSView, Widget {
    public var menus: [NSMenuItem] = []
    public var size: CGFloat = 8
    public var name: String = ""
    
    private var download: Int64 = 0
    private var upload: Int64 = 0
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width, height: self.frame.size.height)
    }
    
    override init(frame: NSRect) {
        self.download = 0
        self.upload = 0
        super.init(frame: CGRect(x: 0, y: 0, width: self.size, height: widgetSize.height))
        self.wantsLayer = true
        self.addSubview(NSView())
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func start() {}
    
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
        self.display()
    }
    
    func setValue(data: [Double]) {
        let download: Int64 = Int64(data[0])
        let upload: Int64 = Int64(data[1])
        
        if self.download != download {
            self.download = download
        }
        if self.upload != upload {
            self.upload = upload
        }
        
        self.redraw()
    }
}
