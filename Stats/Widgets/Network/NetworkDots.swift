//
//  NetworkDots.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkDotsView: NSView, Widget {
    public var size: CGFloat = 12
    public var name: String = "NetworkDots"
    public var menus: [NSMenuItem] = []
    
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
