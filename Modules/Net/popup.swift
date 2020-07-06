//
//  popup.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ModuleKit
import StatsKit

internal class Popup: NSView {
    let dashboardHeight: CGFloat = 90
    let detailsHeight: CGFloat = 110
    
    private var dashboardView: NSView? = nil
    
    private var uploadView: NSView? = nil
    private var uploadValue: Int64 = 0
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    
    private var downloadView: NSView? = nil
    private var downloadValue: Int64 = 0
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    
    private var publicIPField: ValueField? = nil
    private var localIPField: ValueField? = nil
    private var interfaceField: ValueField? = nil
    private var ssidField: ValueField? = nil
    private var macAdressField: ValueField? = nil
    
    private var initialized: Bool = false
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: dashboardHeight + Constants.Popup.separatorHeight + detailsHeight))
        
        initDashboard()
        initDetails()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initDashboard() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        
        let leftPart: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let uploadFields = self.topValueView(leftPart, title: "Upload")
        self.uploadView = uploadFields.0
        self.uploadValueField = uploadFields.1
        self.uploadUnitField = uploadFields.2
        
        let rightPart: NSView = NSView(frame: NSRect(x: view.frame.width / 2, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let downloadFields = self.topValueView(rightPart, title: "Download")
        self.downloadView = downloadFields.0
        self.downloadValueField = downloadFields.1
        self.downloadUnitField = downloadFields.2
        
        view.addSubview(leftPart)
        view.addSubview(rightPart)
        self.addSubview(view)
        self.dashboardView = view
    }
    
    private func topValueView(_ view: NSView, title: String) -> (NSView, NSTextField, NSTextField) {
        let topHeight: CGFloat = 30
        let titleHeight: CGFloat = 15
        
        let valueWidth = "0".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        let unitWidth = "KB/s".widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        let topPartWidth = valueWidth + unitWidth
        
        let topPart: NSView = NSView(frame: NSRect(x: (view.frame.width-topPartWidth)/2, y: (view.frame.height - topHeight - titleHeight)/2 + titleHeight, width: topPartWidth, height: topHeight))
        
        let valueField = LabelField(frame: NSRect(x: 0, y: 0, width: valueWidth, height: 30), "0")
        valueField.font = NSFont.systemFont(ofSize: 26, weight: .light)
        valueField.textColor = .textColor
        valueField.alignment = .right
        
        let unitField = LabelField(frame: NSRect(x: valueField.frame.width, y: 4, width: unitWidth, height: 15), "KB/s")
        unitField.font = NSFont.systemFont(ofSize: 13, weight: .light)
        unitField.textColor = .labelColor
        unitField.alignment = .left
        
        let titleField = LabelField(frame: NSRect(x: 0, y: topPart.frame.origin.y - titleHeight, width: view.frame.width, height: titleHeight), title)
        titleField.alignment = .center
        
        topPart.addSubview(valueField)
        topPart.addSubview(unitField)
        view.addSubview(topPart)
        view.addSubview(titleField)
        
        return (topPart, valueField, unitField)
    }
    
    private func setUploadDownloadFields() {
        let upload = Units(bytes: self.uploadValue).getReadableTuple()
        let download = Units(bytes: self.downloadValue).getReadableTuple()
        
        var valueWidth = "\(upload.0)".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        var unitWidth = upload.1.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        var topPartWidth = valueWidth + unitWidth
        
        self.uploadView?.setFrameSize(NSSize(width: topPartWidth, height: self.uploadView!.frame.height))
        self.uploadView?.setFrameOrigin(NSPoint(x: ((self.frame.width/2)-topPartWidth)/2, y: self.uploadView!.frame.origin.y))
        
        self.uploadValueField?.setFrameSize(NSSize(width: valueWidth, height: self.uploadValueField!.frame.height))
        self.uploadValueField?.stringValue = "\(upload.0)"
        self.uploadUnitField?.setFrameSize(NSSize(width: unitWidth, height: self.uploadUnitField!.frame.height))
        self.uploadUnitField?.setFrameOrigin(NSPoint(x: self.uploadValueField!.frame.width, y: self.uploadUnitField!.frame.origin.y))
        self.uploadUnitField?.stringValue = upload.1
        
        valueWidth = "\(download.0)".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        unitWidth = download.1.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        topPartWidth = valueWidth + unitWidth
        
        self.downloadView?.setFrameSize(NSSize(width: topPartWidth, height: self.downloadView!.frame.height))
        self.downloadView?.setFrameOrigin(NSPoint(x: ((self.frame.width/2)-topPartWidth)/2, y: self.downloadView!.frame.origin.y))
        
        self.downloadValueField?.setFrameSize(NSSize(width: valueWidth, height: self.downloadValueField!.frame.height))
        self.downloadValueField?.stringValue = "\(download.0)"
        self.downloadUnitField?.setFrameSize(NSSize(width: unitWidth, height: self.downloadUnitField!.frame.height))
        self.downloadUnitField?.setFrameOrigin(NSPoint(x: self.downloadValueField!.frame.width, y: self.downloadUnitField!.frame.origin.y))
        self.downloadUnitField?.stringValue = download.1
    }
    
    private func initDetails() {
        let y: CGFloat = self.dashboardView!.frame.origin.y - Constants.Popup.separatorHeight
        let separator = SeparatorView("Details", origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.detailsHeight, width: self.frame.width, height: self.detailsHeight))
        
        self.publicIPField = PopupRow(view, n: 4, title: "Public IP:", value: "")
        self.localIPField = PopupRow(view, n: 3, title: "Local IP:", value: "")
        self.interfaceField = PopupRow(view, n: 2, title: "Interface:", value: "")
        self.ssidField = PopupRow(view, n: 1, title: "Network:", value: "")
        self.macAdressField = PopupRow(view, n: 0, title: "Physical address:", value: "")
        
        self.publicIPField?.addTracking()
        self.localIPField?.addTracking()
        self.ssidField?.addTracking()
        self.macAdressField?.addTracking()
        
        self.publicIPField?.isSelectable = true
        self.localIPField?.isSelectable = true
        self.ssidField?.isSelectable = true
        self.macAdressField?.isSelectable = true
        
        self.addSubview(view)
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initialized {
                return
            }
            
            if let interface = value.interface {
                self.interfaceField?.stringValue = "\(interface.displayName) (\(interface.BSDName))"
                self.macAdressField?.stringValue = interface.address
            } else {
                self.interfaceField?.stringValue = "Unknown"
                self.macAdressField?.stringValue = "Unknown"
            }
            
            if value.connectionType == .wifi {
                self.ssidField?.stringValue = value.ssid ?? "Unknown"
            } else {
                self.ssidField?.stringValue = "Unavailable"
            }
            
            if self.publicIPField?.stringValue != value.raddr {
                if value.raddr == nil {
                    self.publicIPField?.stringValue = "Unknown"
                } else {
                    if value.countryCode == nil {
                        self.publicIPField?.stringValue = value.raddr!
                    } else {
                        self.publicIPField?.stringValue = "\(value.raddr!) (\(value.countryCode!))"
                    }
                }
            }
            if self.localIPField?.stringValue != value.laddr {
                self.localIPField?.stringValue = value.laddr ?? "Unknown"
            }
            
            self.initialized = true
        })
    }
}

extension ValueField {
    func addTracking() {
        let rect = NSRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
        let trackingArea = NSTrackingArea(rect: rect, options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp], owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    public override func mouseEntered(with: NSEvent) {
        guard self.stringValue != "No connection" && self.stringValue != "Unknown" && self.stringValue != "Unavailable" else {
            return
        }
        
        NSCursor.pointingHand.set()
    }
    
    public override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
    }
    
    public override func mouseDown(with: NSEvent) {
        guard self.stringValue != "No connection" && self.stringValue != "Unknown" && self.stringValue != "Unavailable" else {
            return
        }
        
        let arr = self.stringValue.split(separator: " ")
        let value: String = arr.count > 0 ? String(arr[0]) : self.stringValue
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(value, forType: .string)
    }
}
