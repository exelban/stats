//
//  popup.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 11/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSView, Popup_p {
    private let diskFullHeight: CGFloat = 62
    private var list: [String: DiskView] = [:]
    
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: DiskList) {
        if self.list.count != value.list.count && self.list.count != 0 {
            self.subviews.forEach{ $0.removeFromSuperview() }
            self.list = [:]
        }
        
        value.list.reversed().forEach { (drive: drive) in
            if let disk = self.list[drive.mediaName] {
                disk.update(free: drive.free, read: drive.stats?.read, write: drive.stats?.write)
            } else {
                let disk = DiskView(
                    NSRect(
                        x: 0,
                        y: (self.diskFullHeight + Constants.Popup.margins) * CGFloat(self.list.count),
                        width: self.frame.width,
                        height: self.diskFullHeight
                    ),
                    name: drive.mediaName,
                    size: drive.size,
                    free: drive.free,
                    path: drive.path
                )
                self.list[drive.mediaName] = disk
                self.addSubview(disk)
            }
        }
        
        let h: CGFloat = ((self.diskFullHeight + Constants.Popup.margins) * CGFloat(self.list.count)) - Constants.Popup.margins
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
}

internal class DiskView: NSView {
    private var ready: Bool = false
    
    private let nameAndBarHeight: CGFloat = 36
    private let legendHeight: CGFloat = 16
    
    private var nameAndBarView: DiskNameAndBarView
    private var legendView: DiskLegendView
    
    public init(_ frame: NSRect, name: String, size: Int64, free: Int64, path: URL?) {
        self.nameAndBarView = DiskNameAndBarView(
            NSRect(x: 5, y: self.legendHeight + 5, width: frame.width - 10, height: self.nameAndBarHeight),
            name: name,
            size: size,
            free: free,
            path: path
        )
        self.legendView = DiskLegendView(
            NSRect(x: 5, y: 5, width: frame.width - 10, height: self.legendHeight),
            size: size,
            free: free
        )
        
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.addSubview(self.nameAndBarView)
        self.addSubview(self.legendView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
//        self.layer?.backgroundColor = NSColor.red.cgColor
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    public func update(free: Int64, read: Int64?, write: Int64?) {
        self.nameAndBarView.update(free: free, read: read, write: write)
        self.legendView.update(free: free)
    }
}

internal class DiskNameAndBarView: NSView {
    private let size: Int64
    private let uri: URL?
    private var ready: Bool = false
    
    private var readState: NSView? = nil
    private var writeState: NSView? = nil
    
    private var usedBarSpace: NSView? = nil
    
    private let topHeight: CGFloat = 15
    private let barHeight: CGFloat = 10
    
    public init(_ frame: NSRect, name: String, size: Int64, free: Int64, path: URL?) {
        self.size = size
        self.uri = path
        
        super.init(frame: frame)
        self.toolTip = LocalizedString("Open disk")
        
        self.addName(name: name)
        self.addHorizontalBar(size: size, free: free)
        
        let trackingArea = NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addName(name: String) {
        let topView: NSView = NSView(frame: NSRect(
            x: 0,
            y: self.frame.height - topHeight,
            width: self.frame.width,
            height: topHeight
        ))
        
        let nameField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: topView.frame.width - 66, height: topView.frame.height))
        nameField.stringValue = name
        nameField.cell?.truncatesLastVisibleLine = true
        
        let activityView: NSView = NSView(frame: NSRect(x: topView.frame.width-66, y: 0, width: 66, height: topView.frame.height))
        
        let readView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: activityView.frame.width/2, height: activityView.frame.height))
        let readField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameField.frame.width, height: readView.frame.height))
        readField.stringValue = "R"
        readView.addSubview(readField)
        let readState: NSView = NSView(frame: NSRect(x: 15, y: (readView.frame.height-9)/2, width: 9, height: 9))
        readState.wantsLayer = true
        readState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        readState.layer?.cornerRadius = 2
        readView.addSubview(readState)
        
        let writeView: NSView = NSView(frame: NSRect(x: activityView.frame.width/2, y: 0, width: activityView.frame.width/2, height: activityView.frame.height))
        let writeField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameField.frame.width, height: readView.frame.height))
        writeField.stringValue = "W"
        writeView.addSubview(writeField)
        let writeState: NSView = NSView(frame: NSRect(x: 17, y: (writeView.frame.height-9)/2, width: 9, height: 9))
        writeState.wantsLayer = true
        writeState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        writeState.layer?.cornerRadius = 2
        writeView.addSubview(writeState)
        
        activityView.addSubview(readView)
        activityView.addSubview(writeView)
        
        topView.addSubview(nameField)
        topView.addSubview(activityView)
        
        self.addSubview(topView)
        
        self.readState = readState
        self.writeState = writeState
    }
    
    private func addHorizontalBar(size: Int64, free: Int64) {
        let view: NSView = NSView(frame: NSRect(
            x: 1,
            y: ((self.frame.height - self.topHeight) - self.barHeight)/2,
            width: self.frame.width - 2,
            height: self.barHeight
        ))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        view.layer?.borderColor = NSColor.secondaryLabelColor.cgColor
        view.layer?.borderWidth = 0.25
        view.layer?.cornerRadius = 3
        
        let percentage = CGFloat(size - free) / CGFloat(size)
        let width: CGFloat = (view.frame.width * percentage) / 1
        self.usedBarSpace = NSView(frame: NSRect(x: 0, y: 0, width: width, height: view.frame.height))
        self.usedBarSpace?.wantsLayer = true
        self.usedBarSpace?.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        
        view.addSubview(self.usedBarSpace!)
        self.addSubview(view)
    }
    
    public func update(free: Int64, read: Int64?, write: Int64?) {
        if (self.window?.isVisible ?? false) || !self.ready {
            if self.usedBarSpace != nil {
                let percentage = CGFloat(self.size - free) / CGFloat(self.size)
                let width: CGFloat = ((self.frame.width - 2) * percentage) / 1
                self.usedBarSpace?.setFrameSize(NSSize(width: width, height: self.usedBarSpace!.frame.height))
            }
            
            if read != nil {
                self.readState?.layer?.backgroundColor = read != 0 ? NSColor.systemBlue.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
            }
            if write != nil {
                self.writeState?.layer?.backgroundColor = write != 0 ? NSColor.systemRed.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
            }
            
            self.ready = true
        }
    }
    
    override func mouseEntered(with: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        if let uri = self.uri {
            NSWorkspace.shared.openFile(uri.absoluteString, withApplication: "Finder")
        }
    }
}

internal class DiskLegendView: NSView {
    private let size: Int64
    private var free: Int64
    private var ready: Bool = false
    
    private var showUsedSpace: Bool = true
    
    private var legendField: NSTextField? = nil
    private var percentageField: NSTextField? = nil
    
    public init(_ frame: NSRect, size: Int64, free: Int64) {
        self.size = size
        self.free = free
        
        super.init(frame: frame)
        self.toolTip = LocalizedString("Switch view")
        
        let height: CGFloat = 14
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        
        let legendField = TextView(frame: NSRect(x: 0, y: (view.frame.height-height)/2, width: view.frame.width - 40, height: height))
        legendField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        legendField.stringValue = self.legend(free: free)
        legendField.cell?.truncatesLastVisibleLine = true
        
        let percentageField = TextView(frame: NSRect(x: view.frame.width - 40, y: (view.frame.height-height)/2, width: 40, height: height))
        percentageField.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        percentageField.alignment = .right
        percentageField.stringValue = "\(Int8((Double(size - free) / Double(size)) * 100))%"
        
        view.addSubview(legendField)
        view.addSubview(percentageField)
        self.addSubview(view)
        
        self.legendField = legendField
        self.percentageField = percentageField
        
        let trackingArea = NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(free: Int64) {
        self.free = free
        
        if (self.window?.isVisible ?? false) || !self.ready {
            if let view = self.legendField {
                view.stringValue = self.legend(free: free)
            }
            if let view = self.percentageField {
                view.stringValue = self.percentage(free: free)
            }
            
            self.ready = true
        }
    }
    
    private func legend(free: Int64) -> String {
        var value: String
        
        if self.showUsedSpace {
            value = LocalizedString("Used disk memory", Units(bytes: (self.size - free)).getReadableMemory(), Units(bytes: self.size).getReadableMemory())
        } else {
            value = LocalizedString("Free disk memory", Units(bytes: free).getReadableMemory(), Units(bytes: self.size).getReadableMemory())
        }
        
        return value
    }
    
    private func percentage(free: Int64) -> String {
        var value: String
        
        if self.showUsedSpace {
            value = "\(Int8((Double(self.size - free) / Double(self.size)) * 100))%"
        } else {
            value = "\(Int8((Double(free) / Double(self.size)) * 100))%"
        }
        
        return value
    }
    
    override func mouseEntered(with: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with: NSEvent) {
        self.showUsedSpace = !self.showUsedSpace
        
        if let view = self.legendField {
            view.stringValue = self.legend(free: self.free)
        }
        if let view = self.percentageField {
            view.stringValue = self.percentage(free: self.free)
        }
    }
}
