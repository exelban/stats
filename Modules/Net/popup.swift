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

internal class Popup: NSView, Popup_p {
    private var store: UnsafePointer<Store>
    private var title: String
    
    private var grid: NSGridView? = nil
    
    private let dashboardHeight: CGFloat = 90
    private let chartHeight: CGFloat = 90 + Constants.Popup.separatorHeight
    private let detailsHeight: CGFloat = (22*7) + Constants.Popup.separatorHeight
    private let processHeight: CGFloat = 22
    
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
    private var totalUploadField: ValueField? = nil
    private var totalDownloadField: ValueField? = nil
    
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    
    private var chart: NetworkChartView? = nil
    private var processes: [NetworkProcessView] = []
    
    private var base: String {
        get {
            return store.pointee.string(key: "\(self.title)_base", defaultValue: "byte")
        }
    }
    private var numberOfProcesses: Int {
        get {
            return self.store.pointee.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    private var processesHeight: CGFloat {
        get {
            return (self.processHeight*CGFloat(self.numberOfProcesses))+Constants.Popup.separatorHeight
        }
    }
    
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    public init(_ title: String, store: UnsafePointer<Store>) {
        self.store = store
        self.title = title
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: self.dashboardHeight + self.chartHeight + self.detailsHeight
        ))
        self.setFrameSize(NSSize(width: self.frame.width, height: self.frame.height+self.processesHeight))
        
        let gridView: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        gridView.rowSpacing = 0
        gridView.yPlacement = .fill
        
        gridView.addRow(with: [self.initDashboard()])
        gridView.addRow(with: [self.initChart()])
        gridView.addRow(with: [self.initDetails()])
        gridView.addRow(with: [self.initProcesses()])
        
        gridView.row(at: 0).height = self.dashboardHeight
        gridView.row(at: 1).height = self.chartHeight
        gridView.row(at: 2).height = self.detailsHeight
        
        self.addSubview(gridView)
        self.grid = gridView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func numberOfProcessesUpdated() {
        if self.processes.count == self.numberOfProcesses {
            return
        }
        
        DispatchQueue.main.async(execute: {
            self.processes = []
            
            let h: CGFloat = self.dashboardHeight + self.chartHeight + self.detailsHeight + self.processesHeight
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.setFrameSize(NSSize(width: self.frame.width, height: h))
            
            self.grid?.row(at: 3).cell(at: 0).contentView?.removeFromSuperview()
            self.grid?.removeRow(at: 3)
            self.grid?.addRow(with: [self.initProcesses()])
            self.processesInitialized = false
            
            self.sizeCallback?(self.frame.size)
        })
    }
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: self.frame.height - self.dashboardHeight, width: self.frame.width, height: self.dashboardHeight))
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: self.dashboardHeight))
        
        let leftPart: NSView = NSView(frame: NSRect(x: 0, y: 0, width: container.frame.width / 2, height: container.frame.height))
        let uploadFields = self.topValueView(leftPart, title: LocalizedString("Uploading"), color: NSColor.systemRed)
        self.uploadView = uploadFields.0
        self.uploadValueField = uploadFields.1
        self.uploadUnitField = uploadFields.2
        self.uploadStateView = uploadFields.3
        
        let rightPart: NSView = NSView(frame: NSRect(x: container.frame.width / 2, y: 0, width: container.frame.width / 2, height: container.frame.height))
        let downloadFields = self.topValueView(rightPart, title: LocalizedString("Downloading"), color: NSColor.systemBlue)
        self.downloadView = downloadFields.0
        self.downloadValueField = downloadFields.1
        self.downloadUnitField = downloadFields.2
        self.downloadStateView = downloadFields.3
        
        container.addSubview(leftPart)
        container.addSubview(rightPart)
        
        view.addSubview(container)
        self.dashboardView = container
        
        return view
    }
    
    private func initChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.chartHeight))
        let separator = SeparatorView(LocalizedString("Usage history"), origin: NSPoint(x: 0, y: self.chartHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = 3
        
        self.chart = NetworkChartView(frame: NSRect(x: 1, y: 0, width: container.frame.width, height: container.frame.height), num: 120)
        container.addSubview(self.chart!)
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.detailsHeight))
        let separator = SeparatorView(LocalizedString("Details"), origin: NSPoint(x: 0, y: self.detailsHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        self.totalUploadField = PopupWithColorRow(container, color: NSColor.systemRed, n: 6, title: "\(LocalizedString("Total upload")):", value: "")
        self.totalDownloadField = PopupWithColorRow(container, color: NSColor.systemBlue, n: 5, title: "\(LocalizedString("Total download")):", value: "")
        
        self.publicIPField = PopupRow(container, n: 4, title: "\(LocalizedString("Public IP")):", value: "")
        self.localIPField = PopupRow(container, n: 3, title: "\(LocalizedString("Local IP")):", value: "")
        self.interfaceField = PopupRow(container, n: 2, title: "\(LocalizedString("Interface")):", value: "")
        self.ssidField = PopupRow(container, n: 1, title: "\(LocalizedString("Network")):", value: "")
        self.macAdressField = PopupRow(container, n: 0, title: "\(LocalizedString("Physical address")):", value: "")
        
        self.publicIPField?.addTracking()
        self.localIPField?.addTracking()
        self.macAdressField?.addTracking()
        
        self.publicIPField?.toolTip = LocalizedString("Click to copy public IP address")
        self.localIPField?.toolTip = LocalizedString("Click to copy local IP address")
        self.macAdressField?.toolTip = LocalizedString("Click to copy mac address")
        
        self.publicIPField?.isSelectable = true
        self.localIPField?.isSelectable = true
        self.macAdressField?.isSelectable = true
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initProcesses() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = SeparatorView(LocalizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        
        for i in 0...self.numberOfProcesses {
            let processView = NetworkProcessView(CGFloat(i))
            self.processes.append(processView)
            container.addSubview(processView)
        }
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func topValueView(_ view: NSView, title: String, color: NSColor) -> (NSView, NSTextField, NSTextField, ColorView) {
        let topHeight: CGFloat = 30
        let titleHeight: CGFloat = 15
        
        let valueWidth = "0".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        let unitWidth = "KB/s".widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        let topPartWidth = valueWidth + unitWidth
        
        let topView: NSView = NSView(frame: NSRect(
            x: (view.frame.width-topPartWidth)/2,
            y: (view.frame.height - topHeight - titleHeight)/2 + titleHeight,
            width: topPartWidth,
            height: topHeight
        ))
        
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
        let bottomView: NSView = NSView(frame: NSRect(
            x: (view.frame.width-bottomWidth)/2,
            y: topView.frame.origin.y - titleHeight,
            width: bottomWidth,
            height: titleHeight
        ))
        
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
                
                self.totalUploadField?.stringValue = Units(bytes: value.totalUpload).getReadableMemory()
                self.totalDownloadField?.stringValue = Units(bytes: value.totalDownload).getReadableMemory()
                
                if let interface = value.interface {
                    self.interfaceField?.stringValue = "\(interface.displayName) (\(interface.BSDName))"
                    self.macAdressField?.stringValue = interface.address
                } else {
                    self.interfaceField?.stringValue = LocalizedString("Unknown")
                    self.macAdressField?.stringValue = LocalizedString("Unknown")
                }
                
                if value.connectionType == .wifi {
                    self.ssidField?.stringValue = value.ssid ?? "Unknown"
                } else {
                    self.ssidField?.stringValue = LocalizedString("Unavailable")
                }
                
                if self.publicIPField?.stringValue != value.raddr {
                    if value.raddr == nil {
                        self.publicIPField?.stringValue = LocalizedString("Unknown")
                    } else {
                        if value.countryCode == nil {
                            self.publicIPField?.stringValue = value.raddr!
                        } else {
                            self.publicIPField?.stringValue = "\(value.raddr!) (\(value.countryCode!))"
                        }
                    }
                }
                if self.localIPField?.stringValue != value.laddr {
                    self.localIPField?.stringValue = value.laddr ?? LocalizedString("Unknown")
                }
                
                self.initialized = true
            }
            
            self.chart?.addValue(upload: Double(value.upload), download: Double(value.download))
        })
    }
    
    public func processCallback(_ list: [Network_Process]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.processesInitialized {
                return;
            }
            
            if list.count != self.processes.count {
                self.processes.forEach { processView in
                    processView.clear();
                }
            }
            
            for i in 0..<list.count {
                let process = list[i]
                let index = list.count-i-1
                self.processes[index].attachProcess(process);
                self.processes[index].upload = Units(bytes: Int64(process.upload)).getReadableSpeed(base: DataSizeBase(rawValue: self.base) ?? .byte)
                self.processes[index].download = Units(bytes: Int64(process.download)).getReadableSpeed(base: DataSizeBase(rawValue: self.base) ?? .byte)
            }
            
            self.processesInitialized = true
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
        guard self.stringValue != LocalizedString("No connection") && self.stringValue != LocalizedString("Unknown") && self.stringValue != LocalizedString("Unavailable") else {
            return
        }
        
        NSCursor.pointingHand.set()
    }
    
    public override func mouseExited(with: NSEvent) {
        NSCursor.arrow.set()
    }
    
    public override func mouseDown(with: NSEvent) {
        guard self.stringValue != LocalizedString("No connection") && self.stringValue != LocalizedString("Unknown") && self.stringValue != LocalizedString("Unavailable") else {
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
    
    public func attachProcess(_ process: Network_Process) {
        self.label = process.name
        self.icon = process.icon
        self.toolTip = "pid: \(process.pid)"
    }
    
    public func clear() {
        self.label = ""
        self.download = ""
        self.upload = ""
        self.icon = nil
        self.toolTip = ""
    }
}
