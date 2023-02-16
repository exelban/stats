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
import Kit

internal class Popup: NSStackView, Popup_p {
    public var sizeCallback: ((NSSize) -> Void)? = nil
    
    private let emptyView: EmptyView = EmptyView(height: 30, isHidden: false, msg: localizedString("No disks are available"))
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 30))
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.margins
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func capacityCallback(_ value: Disks) {
        defer {
            if value.isEmpty && self.emptyView.superview == nil {
                self.addArrangedSubview(self.emptyView)
            } else if !value.isEmpty && self.emptyView.superview != nil {
                self.emptyView.removeFromSuperview()
            }
            
            let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
            if h > 0 && self.frame.size.height != h {
                self.setFrameSize(NSSize(width: self.frame.width, height: h))
                self.sizeCallback?(self.frame.size)
            }
        }
        
        self.subviews.filter{ $0 is DiskView }.map{ $0 as! DiskView }.forEach { (v: DiskView) in
            if !value.map({$0.BSDName}).contains(v.BSDName) {
                v.removeFromSuperview()
            }
        }
        
        value.forEach { (drive: drive) in
            if let view = self.subviews.filter({ $0 is DiskView }).map({ $0 as! DiskView }).first(where: { $0.BSDName == drive.BSDName }) {
                view.updateFree(free: drive.free)
            } else {
                self.addArrangedSubview(DiskView(
                    width: self.frame.width,
                    BSDName: drive.BSDName,
                    name: drive.mediaName,
                    size: drive.size,
                    free: drive.free,
                    path: drive.path
                ))
            }
        }
    }
    
    internal func activityCallback(_ value: Disks) {
        let views = self.subviews.filter{ $0 is DiskView }.map{ $0 as! DiskView }
        value.reversed().forEach { (drive: drive) in
            if let view = views.first(where: { $0.name == drive.mediaName }) {
                view.updateReadWrite(read: drive.activity.read, write: drive.activity.write)
            }
        }
    }
    
    // MARK: - Settings
    
    public func settings() -> NSView? {
        return nil
    }
}

internal class DiskView: NSStackView {
    public var name: String
    public var BSDName: String
    
    private var nameView: NameView
    private var chartView: ChartView
    private var barView: BarView
    private var legendView: LegendView
    
    init(width: CGFloat, BSDName: String, name: String, size: Int64, free: Int64, path: URL?) {
        self.BSDName = BSDName
        self.name = name
        let innerWidth: CGFloat = width - (Constants.Popup.margins * 2)
        self.nameView = NameView(width: innerWidth, name: name, size: size, free: free, path: path)
        self.chartView = ChartView(width: innerWidth)
        self.barView = BarView(width: innerWidth, size: size, free: free)
        self.legendView = LegendView(width: innerWidth, id: "\(name)_\(path?.absoluteString ?? "")", size: size, free: free)
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 82))
        
        self.orientation = .vertical
        self.distribution = .fillProportionally
        self.spacing = 5
        self.edgeInsets = NSEdgeInsets(
            top: 5,
            left: 0,
            bottom: 5,
            right: 0
        )
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.addArrangedSubview(self.nameView)
        self.addArrangedSubview(self.chartView)
        self.addArrangedSubview(self.barView)
        self.addArrangedSubview(self.legendView)
        
        let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - 5 + 10
        self.setFrameSize(NSSize(width: self.frame.width, height: h))
        self.widthAnchor.constraint(equalToConstant: width).isActive = true
        self.heightAnchor.constraint(equalToConstant: h).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = isDarkMode ? NSColor(hexString: "#111111", alpha: 0.25).cgColor : NSColor(hexString: "#f5f5f5", alpha: 1).cgColor
    }
    
    public func updateFree(free: Int64) {
        self.nameView.update(free: free, read: nil, write: nil)
        self.legendView.update(free: free)
        self.barView.update(free: free)
    }
    public func updateReadWrite(read: Int64, write: Int64) {
        self.nameView.update(free: nil, read: read, write: write)
        self.chartView.update(read: read, write: write)
    }
}

internal class NameView: NSStackView {
    private let size: Int64
    private let uri: URL?
    private var ready: Bool = false
    
    private var readState: NSView? = nil
    private var writeState: NSView? = nil
    
    public init(width: CGFloat, name: String, size: Int64, free: Int64, path: URL?) {
        self.size = size
        self.uri = path
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 16))
        
        self.orientation = .horizontal
        self.alignment = .centerY
        self.spacing = 0
        
        self.toolTip = localizedString("Open disk")
        
        let nameField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: self.frame.width - 64, height: self.frame.height))
        nameField.widthAnchor.constraint(equalToConstant: nameField.bounds.width).isActive = true
        nameField.stringValue = name
        nameField.cell?.truncatesLastVisibleLine = true
        
        let activity: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 64, height: self.frame.height))
        activity.distribution = .fillEqually
        activity.spacing = 0
        
        let readView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: activity.frame.height))
        let readField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameField.frame.width, height: readView.frame.height))
        readField.stringValue = "R"
        let readState: NSView = NSView(frame: NSRect(x: 13, y: (readView.frame.height-10)/2, width: 9, height: 9))
        readState.wantsLayer = true
        readState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        readState.layer?.cornerRadius = 2
        
        let writeView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: activity.frame.height))
        let writeField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameField.frame.width, height: readView.frame.height))
        writeField.stringValue = "W"
        let writeState: NSView = NSView(frame: NSRect(x: 17, y: (writeView.frame.height-10)/2, width: 9, height: 9))
        writeState.wantsLayer = true
        writeState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        writeState.layer?.cornerRadius = 2
        
        readView.addSubview(readField)
        readView.addSubview(readState)
        
        writeView.addSubview(writeField)
        writeView.addSubview(writeState)
        
        activity.addArrangedSubview(readView)
        activity.addArrangedSubview(writeView)
        
        self.addArrangedSubview(nameField)
        self.addArrangedSubview(activity)
        
        self.readState = readState
        self.writeState = writeState
        
        let trackingArea = NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(free: Int64?, read: Int64?, write: Int64?) {
        if (self.window?.isVisible ?? false) || !self.ready {
            if let read = read {
                self.readState?.toolTip = DiskSize(read).getReadableMemory()
                self.readState?.layer?.backgroundColor = read != 0 ? NSColor.systemBlue.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
            }
            if let write = write {
                self.writeState?.toolTip = DiskSize(write).getReadableMemory()
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
            NSWorkspace.shared.openFile(uri.path, withApplication: "Finder")
        }
    }
}

internal class ChartView: NSStackView {
    private var chart: NetworkChartView? = nil
    private var ready: Bool = false
    
    public init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 36))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        
        let chart = NetworkChartView(frame: NSRect(
            x: 0,
            y: 1,
            width: self.frame.width,
            height: self.frame.height - 2
        ), num: 120)
        self.chart = chart
        
        self.addArrangedSubview(chart)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(read: Int64, write: Int64) {
        self.chart?.addValue(upload: Double(write), download: Double(read))
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = self.isDarkMode ? NSColor.lightGray.withAlphaComponent(0.1).cgColor : NSColor.white.cgColor
    }
}

internal class BarView: NSView {
    private let size: Int64
    private var usedBarSpace: NSView? = nil
    private var ready: Bool = false
    
    private var background: NSView? = nil
    
    public init(width: CGFloat, size: Int64, free: Int64) {
        self.size = size
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        
        let view: NSView = NSView(frame: NSRect(x: 1, y: 0, width: self.frame.width - 2, height: self.frame.height))
        view.wantsLayer = true
        view.layer?.borderColor = NSColor.secondaryLabelColor.cgColor
        view.layer?.borderWidth = 0.25
        view.layer?.cornerRadius = 3
        self.background = view
        
        let percentage = CGFloat(size - free) / CGFloat(size)
        let width: CGFloat = (view.frame.width * (percentage < 0 ? 0 : percentage)) / 1
        self.usedBarSpace = NSView(frame: NSRect(x: 0, y: 0, width: width, height: view.frame.height))
        self.usedBarSpace?.wantsLayer = true
        self.usedBarSpace?.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        
        view.addSubview(self.usedBarSpace!)
        self.addSubview(view)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.background?.layer?.backgroundColor = self.isDarkMode ? NSColor.lightGray.withAlphaComponent(0.1).cgColor : NSColor.white.cgColor
    }
    
    public func update(free: Int64?) {
        if (self.window?.isVisible ?? false) || !self.ready {
            if let free = free, self.usedBarSpace != nil {
                let percentage = CGFloat(self.size - free) / CGFloat(self.size)
                let width: CGFloat = ((self.frame.width - 2) * (percentage < 0 ? 0 : percentage)) / 1
                self.usedBarSpace?.setFrameSize(NSSize(width: width, height: self.usedBarSpace!.frame.height))
            }
            
            self.ready = true
        }
    }
}

internal class LegendView: NSView {
    private let size: Int64
    private var free: Int64
    private let id: String
    private var ready: Bool = false
    
    private var showUsedSpace: Bool {
        get {
            return Store.shared.bool(key: "\(self.id)_usedSpace", defaultValue: false)
        }
        set {
            Store.shared.set(key: "\(self.id)_usedSpace", value: newValue)
        }
    }
    
    private var legendField: NSTextField? = nil
    private var percentageField: NSTextField? = nil
    
    public init(width: CGFloat, id: String, size: Int64, free: Int64) {
        self.id = id
        self.size = size
        self.free = free
        
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 16))
        self.toolTip = localizedString("Switch view")
        
        let height: CGFloat = 14
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        
        let legendField = TextView(frame: NSRect(x: 0, y: (view.frame.height-height)/2, width: view.frame.width - 40, height: height))
        legendField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        legendField.stringValue = self.legend(free: free)
        legendField.cell?.truncatesLastVisibleLine = true
        
        let percentageField = TextView(frame: NSRect(x: view.frame.width - 40, y: (view.frame.height-height)/2, width: 40, height: height))
        percentageField.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        percentageField.alignment = .right
        var percentage = Int(Double(size - free) / Double(size == 0 ? 1 : size)) * 100
        if percentage < 0 {
            percentage = 0
        }
        percentageField.stringValue = "\(percentage)%"
        
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
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
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
            var usedSpace = self.size - free
            if usedSpace < 0 {
                usedSpace = 0
            }
            value = localizedString("Used disk memory", DiskSize(usedSpace).getReadableMemory(), DiskSize(self.size).getReadableMemory())
        } else {
            value = localizedString("Free disk memory", DiskSize(free).getReadableMemory(), DiskSize(self.size).getReadableMemory())
        }
        
        return value
    }
    
    private func percentage(free: Int64) -> String {
        guard self.size != 0 else {
            return "0%"
        }
        var percentage: Int
        
        if self.showUsedSpace {
            percentage = Int((Double(self.size - free) / Double(self.size)) * 100)
        } else {
            percentage = Int((Double(free) / Double(self.size)) * 100)
        }
        
        return "\(percentage < 0 ? 0 : percentage)%"
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
