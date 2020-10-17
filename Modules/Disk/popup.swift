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

internal class Popup: NSView {
    let diskFullHeight: CGFloat = 60
    var list: [String: DiskView] = [:]
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: DiskList) {
        if self.list.count != value.list.count {
            DispatchQueue.main.async(execute: {
                self.subviews.forEach{ $0.removeFromSuperview() }
            })
            self.list = [:]
        }
        
        value.list.reversed().forEach { (d: drive) in
            if self.list[d.mediaName] == nil {
                DispatchQueue.main.async(execute: {
                    self.list[d.mediaName] = DiskView(
                        NSRect(x: 0, y: (self.diskFullHeight + Constants.Popup.margins) * CGFloat(self.list.count), width: self.frame.width, height: self.diskFullHeight),
                        name: d.mediaName,
                        size: d.size,
                        free: d.free,
                        path: d.path
                    )
                    self.addSubview(self.list[d.mediaName]!)
                })
            } else {
                self.list[d.mediaName]?.update(free: d.free, read: d.stats?.read, write: d.stats?.write)
            }
        }

        DispatchQueue.main.async(execute: {
            let h: CGFloat = ((self.diskFullHeight + Constants.Popup.margins) * CGFloat(self.list.count)) - Constants.Popup.margins
            if self.frame.size.height != h {
                self.setFrameSize(NSSize(width: self.frame.width, height: h))
                NotificationCenter.default.post(name: .updatePopupSize, object: nil, userInfo: ["module": "Disk"])
            }
        })
    }
}

internal class DiskView: NSView {
    public let name: String
    public let size: Int64
    private let uri: URL?
    private var ready: Bool = false
    
    private let nameHeight: CGFloat = 20
    private let legendHeight: CGFloat = 12
    private let barHeight: CGFloat = 10
    
    private var legendField: NSTextField? = nil
    private var percentageField: NSTextField? = nil
    private var usedBarSpace: NSView? = nil
    
    private var readState: NSView? = nil
    private var writeState: NSView? = nil
    
    private var mainView: NSView
    
    public init(_ frame: NSRect, name: String, size: Int64, free: Int64, path: URL?) {
        self.mainView = NSView(frame: NSRect(x: 5, y: 5, width: frame.width - 10, height: frame.height - 10))
        self.name = name
        self.size = size
        self.uri = path
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.addName()
        self.addHorizontalBar(free: free)
        self.addLegend(free: free)
        
        self.addSubview(self.mainView)
        
        let rect: CGRect = CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    private func addName() {
        let nameWidth = self.name.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 4
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.mainView.frame.height - nameHeight, width: self.mainView.frame.width, height: nameHeight))
        
        let nameField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width - 66, height: view.frame.height))
        nameField.stringValue = self.name
        nameField.cell?.truncatesLastVisibleLine = true
        
        let activityView: NSView = NSView(frame: NSRect(x: view.frame.width-66, y: 0, width: 66, height: view.frame.height-2))
        
        let readView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: activityView.frame.width/2, height: activityView.frame.height))
        
        let readField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameWidth, height: readView.frame.height))
        readField.stringValue = "R"
        readView.addSubview(readField)
        
        let readState: NSView = NSView(frame: NSRect(x: 15, y: 6, width: 9, height: 9))
        readState.wantsLayer = true
        readState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        readState.layer?.cornerRadius = 2
        readView.addSubview(readState)
        
        let writeView: NSView = NSView(frame: NSRect(x: activityView.frame.width/2, y: 0, width: activityView.frame.width/2, height: activityView.frame.height))
        
        let writeField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameWidth, height: readView.frame.height))
        writeField.stringValue = "W"
        writeView.addSubview(writeField)
        
        let writeState: NSView = NSView(frame: NSRect(x: 17, y: 6, width: 9, height: 9))
        writeState.wantsLayer = true
        writeState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        writeState.layer?.cornerRadius = 2
        writeView.addSubview(writeState)
        
        activityView.addSubview(readView)
        activityView.addSubview(writeView)
        
        view.addSubview(nameField)
        view.addSubview(activityView)
        self.mainView.addSubview(view)
        
        self.readState = readState
        self.writeState = writeState
    }
    
    private func addLegend(free: Int64) {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 2, width: self.mainView.frame.width, height: self.legendHeight))
        
        self.legendField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width - 40, height: view.frame.height))
        self.legendField?.font = NSFont.systemFont(ofSize: 11, weight: .light)
        self.legendField?.stringValue = LocalizedString("Used disk memory", Units(bytes: (self.size - free)).getReadableMemory(), Units(bytes: self.size).getReadableMemory())
        
        self.percentageField = TextView(frame: NSRect(x: view.frame.width - 40, y: 0, width: 40, height: view.frame.height))
        self.percentageField?.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        self.percentageField?.alignment = .right
        self.percentageField?.stringValue = "\(Int8((Double(self.size - free) / Double(self.size)) * 100))%"
        
        view.addSubview(self.legendField!)
        view.addSubview(self.percentageField!)
        self.mainView.addSubview(view)
    }
    
    private func addHorizontalBar(free: Int64) {
        let view: NSView = NSView(frame: NSRect(x: 1, y: self.mainView.frame.height - self.nameHeight - 11, width: self.mainView.frame.width - 2, height: self.barHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        view.layer?.borderColor = NSColor.secondaryLabelColor.cgColor
        view.layer?.borderWidth = 0.25
        view.layer?.cornerRadius = 3
        
        let percentage = CGFloat(self.size - free) / CGFloat(self.size)
        let width: CGFloat = (view.frame.width * percentage) / 1
        self.usedBarSpace = NSView(frame: NSRect(x: 0, y: 0, width: width, height: view.frame.height))
        self.usedBarSpace?.wantsLayer = true
        self.usedBarSpace?.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        
        view.addSubview(self.usedBarSpace!)
        self.mainView.addSubview(view)
    }
    
    private func setReadState(_ state: Bool) {
        self.readState?.layer?.backgroundColor = state ? NSColor.systemBlue.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
    }
    
    private func setWriteState(_ state: Bool) {
        self.writeState?.layer?.backgroundColor = state ? NSColor.systemRed.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
    }
    
    public func update(free: Int64, read: Int64?, write: Int64?) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.ready {
                if self.legendField != nil {
                    self.legendField?.stringValue = LocalizedString("Used disk memory", Units(bytes: (self.size - free)).getReadableMemory(), Units(bytes: self.size).getReadableMemory())
                    self.percentageField?.stringValue = "\(Int8((Double(self.size - free) / Double(self.size)) * 100))%"
                }
                
                if self.usedBarSpace != nil {
                    let percentage = CGFloat(self.size - free) / CGFloat(self.size)
                    let width: CGFloat = ((self.mainView.frame.width - 2) * percentage) / 1
                    self.usedBarSpace?.setFrameSize(NSSize(width: width, height: self.usedBarSpace!.frame.height))
                }
                
                if read != nil {
                    self.setReadState(read != 0)
                }
                if write != nil {
                    self.setWriteState(write != 0)
                }
                
                self.ready = true
            }
        })
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
