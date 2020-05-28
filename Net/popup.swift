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
    let overviewHeight: CGFloat = 88
    
    private var dashboardView: NSView? = nil
    
    private var uploadView: NSView? = nil
    private var uploadValue: Int64 = 0
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    
    private var downloadView: NSView? = nil
    private var downloadValue: Int64 = 0
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    
    private var publicIPField: NSTextField? = nil
    private var localIPField: NSTextField? = nil
    private var networkTypeField: NSTextField? = nil
    private var macAdressField: NSTextField? = nil
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: dashboardHeight + Constants.Popup.separatorHeight + overviewHeight))
        
        initDashboard()
        initOverview()
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
        valueField.textColor = .labelColor
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
    
    private func initOverview() {
        let y: CGFloat = self.dashboardView!.frame.origin.y - Constants.Popup.separatorHeight
        let separator = SeparatorView("Overview", origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: separator.frame.origin.y - self.overviewHeight, width: self.frame.width, height: self.overviewHeight))
        
        self.publicIPField = PopupRow(view, n: 3, title: "Public IP:", value: "")
        self.localIPField = PopupRow(view, n: 2, title: "Local IP:", value: "")
        self.networkTypeField = PopupRow(view, n: 1, title: "Network:", value: "")
        self.macAdressField = PopupRow(view, n: 0, title: "Physical address:", value: "")
        
        self.addSubview(view)
    }
    
    public func usageCallback(_ value: NetworkUsage) {
        DispatchQueue.main.async(execute: {
            if !self.window!.isVisible {
                return
            }
            
            self.uploadValue = value.upload
            self.downloadValue = value.download
            self.setUploadDownloadFields()
            
            if !value.active {
                self.publicIPField?.stringValue = "No connection"
                self.localIPField?.stringValue = "No connection"
                self.networkTypeField?.stringValue = "No connection"
                self.macAdressField?.stringValue = "No connection"
                return
            }
            
            if var publicIP = value.paddr, self.publicIPField?.stringValue != publicIP {
                if value.countryCode != nil {
                    publicIP = "\(publicIP) (\(value.countryCode!))"
                }
                self.publicIPField?.stringValue = publicIP
            }
            if value.laddr != nil && self.localIPField?.stringValue != value.laddr {
                self.localIPField?.stringValue = value.laddr!
            }
            if value.iaddr != nil && self.macAdressField?.stringValue != value.iaddr {
                self.macAdressField?.stringValue = value.iaddr!
            }
            
            if value.connectionType != nil {
                var networkType = ""
                if value.connectionType == .wifi {
                    networkType = "\(value.networkName!) (WiFi)"
                } else if value.connectionType == .ethernet {
                    networkType = "Ethernet"
                }
                
                if self.networkTypeField?.stringValue != networkType {
                    self.networkTypeField?.stringValue = networkType
                }
            }
        })
    }
}
