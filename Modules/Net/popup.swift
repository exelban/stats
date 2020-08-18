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
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90
    private let detailsHeight: CGFloat = 110
    private let processesHeight: CGFloat = 22*5
    
    private var dashboardView: NSView? = nil
    
    private var uploadView: NSView? = nil
    private var uploadValue: Int64 = 0
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    private var uploadStateView: ColorView? = nil
    
    private var downloadView: NSView? = nil
    private var downloadValue: Int64 = 0
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    private var downloadStateView: ColorView? = nil
    
    private var publicIPField: ValueField? = nil
    private var localIPField: ValueField? = nil
    private var interfaceField: ValueField? = nil
    private var ssidField: ValueField? = nil
    private var macAdressField: ValueField? = nil
    
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    
    private var chart: NetworkChartView? = nil
    private var processes: [NetworkProcessView] = []
    
    public init() {
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: dashboardHeight + chartHeight + (Constants.Popup.separatorHeight*3) + detailsHeight + processesHeight
        ))
        
        initDashboard()
        initChart()
        initDetails()
        initProcesses()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initDashboard() {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        
        let leftPart: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let uploadFields = self.topValueView(leftPart, title: "Upload", color: NSColor.systemRed)
        self.uploadView = uploadFields.0
        self.uploadValueField = uploadFields.1
        self.uploadUnitField = uploadFields.2
        self.uploadStateView = uploadFields.3
        
        let rightPart: NSView = NSView(frame: NSRect(x: view.frame.width / 2, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let downloadFields = self.topValueView(rightPart, title: "Download", color: NSColor.systemBlue)
        self.downloadView = downloadFields.0
        self.downloadValueField = downloadFields.1
        self.downloadUnitField = downloadFields.2
        self.downloadStateView = downloadFields.3
        
        view.addSubview(leftPart)
        view.addSubview(rightPart)
        self.addSubview(view)
        self.dashboardView = view
    }
    
    private func initChart() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - Constants.Popup.separatorHeight
        let separator = SeparatorView("Usage history", origin: NSPoint(x: 0, y: y), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: y -  self.chartHeight, width: self.frame.width, height: self.chartHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        view.layer?.cornerRadius = 3
        
        self.chart = NetworkChartView(frame: NSRect(x: 1, y: 0, width: view.frame.width, height: view.frame.height), num: 120)
        
        view.addSubview(self.chart!)
        
        self.addSubview(view)
    }
    
    private func initDetails() {
        let y: CGFloat = self.frame.height - self.dashboardHeight - self.chartHeight - (Constants.Popup.separatorHeight*2)
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
    
    private func initProcesses() {
        let separator = SeparatorView("Top processes", origin: NSPoint(x: 0, y: self.processesHeight), width: self.frame.width)
        self.addSubview(separator)
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        
        self.processes.append(NetworkProcessView(0))
        self.processes.append(NetworkProcessView(1))
        self.processes.append(NetworkProcessView(2))
        self.processes.append(NetworkProcessView(3))
        self.processes.append(NetworkProcessView(4))
        
        self.processes.forEach{ view.addSubview($0) }
        
        self.addSubview(view)
    }
    
    private func topValueView(_ view: NSView, title: String, color: NSColor) -> (NSView, NSTextField, NSTextField, ColorView) {
        let topHeight: CGFloat = 30
        let titleHeight: CGFloat = 15
        
        let valueWidth = "0".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        let unitWidth = "KB/s".widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        let topPartWidth = valueWidth + unitWidth
        
        let topView: NSView = NSView(frame: NSRect(x: (view.frame.width-topPartWidth)/2, y: (view.frame.height - topHeight - titleHeight)/2 + titleHeight, width: topPartWidth, height: topHeight))
        
        let valueField = LabelField(frame: NSRect(x: 0, y: 0, width: valueWidth, height: 30), "0")
        valueField.font = NSFont.systemFont(ofSize: 26, weight: .light)
        valueField.textColor = .textColor
        valueField.alignment = .right
        
        let unitField = LabelField(frame: NSRect(x: valueField.frame.width, y: 4, width: unitWidth, height: 15), "KB/s")
        unitField.font = NSFont.systemFont(ofSize: 13, weight: .light)
        unitField.textColor = .labelColor
        unitField.alignment = .left
        
        let titleWidth: CGFloat = title.widthOfString(usingFont: NSFont.systemFont(ofSize: 12, weight: .regular))+8
        let iconSize: CGFloat = 12
        let bottomWidth: CGFloat = titleWidth+iconSize
        let bottomView: NSView = NSView(frame: NSRect(x: (view.frame.width-bottomWidth)/2, y: topView.frame.origin.y - titleHeight, width: bottomWidth, height: titleHeight))
        
        let colorBlock: ColorView = ColorView(frame: NSRect(x: 0, y: 1, width: iconSize, height: iconSize), color: color, radius: 4)
        let titleField = LabelField(frame: NSRect(x: iconSize, y: 0, width: titleWidth, height: titleHeight), title)
        titleField.alignment = .center
        
        topView.addSubview(valueField)
        topView.addSubview(unitField)
        
        bottomView.addSubview(colorBlock)
        bottomView.addSubview(titleField)
        
        view.addSubview(topView)
        view.addSubview(bottomView)
        
        return (topView, valueField, unitField, colorBlock)
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
        
        self.uploadStateView?.setState(self.uploadValue != 0)
        self.downloadStateView?.setState(self.downloadValue != 0)
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.uploadValue = value.upload
                self.downloadValue = value.download
                self.setUploadDownloadFields()
                
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
            }
            
            self.chart?.addValue(upload: Double(value.upload), download: Double(value.download))
        })
    }
    
    public func processCallback(_ list: [Network_Process]) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) {
                for i in 0..<list.count {
                    let process = list[i]
                    let index = list.count-i-1
                    if self.processes.indices.contains(index) {
                        self.processes[index].label = process.name
                        self.processes[index].upload = Units(bytes: Int64(process.upload)).getReadableSpeed()
                        self.processes[index].download = Units(bytes: Int64(process.download)).getReadableSpeed()
                        self.processes[index].icon = process.icon
                    }
                }
            }
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

public class NetworkProcessView: NSView {
    public var width: CGFloat {
        get { return 0 }
        set {
            self.setFrameSize(NSSize(width: newValue, height: self.frame.height))
        }
    }
    
    public var icon: NSImage? {
        get { return NSImage() }
        set {
            self.imageView?.image = newValue
        }
    }
    public var label: String {
        get { return "" }
        set {
            self.labelView?.stringValue = newValue
        }
    }
    public var upload: String {
        get { return "" }
        set {
            self.uploadView?.stringValue = newValue
        }
    }
    public var download: String {
        get { return "" }
        set {
            self.downloadView?.stringValue = newValue
        }
    }
    
    private var imageView: NSImageView? = nil
    private var labelView: LabelField? = nil
    private var uploadView: ValueField? = nil
    private var downloadView: ValueField? = nil
    
    public init(_ n: CGFloat) {
        super.init(frame: NSRect(x: 0, y: n*22, width: Constants.Popup.width, height: 16))
        
        let rowView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 16))
        
        let imageView: NSImageView = NSImageView(frame: NSRect(x: 2, y: 2, width: 12, height: 12))
        let labelView: LabelField = LabelField(frame: NSRect(x: 18, y: 0.5, width: rowView.frame.width - 138, height: 15), "")
        let uploadView: ValueField = ValueField(frame: NSRect(x: rowView.frame.width - 120, y: 1.75, width: 60, height: 12), "")
        let downloadView: ValueField = ValueField(frame: NSRect(x: rowView.frame.width - 60, y: 1.75, width: 60, height: 12), "")
        uploadView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        downloadView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        
        rowView.addSubview(imageView)
        rowView.addSubview(labelView)
        rowView.addSubview(uploadView)
        rowView.addSubview(downloadView)
        
        self.imageView = imageView
        self.labelView = labelView
        self.uploadView = uploadView
        self.downloadView = downloadView
        
        self.addSubview(rowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
