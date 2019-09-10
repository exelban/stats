//
//  NetworkText.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 14.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class NetworkTextView: NSView, Widget {
    var menus: [NSMenuItem] = []
    var activeModule: Observable<Bool> = Observable(false)
    var size: CGFloat = widgetSize.width + 20
    var name: String = ""
    var shortName: String = ""
    
    var color: Observable<Bool> = Observable(false)
    var downloadValue: NSTextField = NSTextField()
    var uploadValue: NSTextField = NSTextField()
    
    override init(frame: NSRect) {
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
    }
    
    func redraw() {
        self.needsDisplay = true
        setNeedsDisplay(self.frame)
    }
    
    func setValue(data: [Double]) {
        let download: Int64 = Int64(data[0])
        let upload: Int64 = Int64(data[1])
        
        downloadValue.stringValue = Units(bytes: download).getReadableSpeed()
        uploadValue.stringValue = Units(bytes: upload).getReadableSpeed()
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
