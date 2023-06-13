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

internal class Popup: PopupWrapper {
    private var readColorState: Color = .secondBlue
    private var readColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.readColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var writeColorState: Color = .secondRed
    private var writeColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.writeColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    private var disks: NSStackView = {
        let view = NSStackView()
        view.spacing = Constants.Popup.margins
        view.orientation = .vertical
        return view
    }()
    private var processes: IOProcessView = IOProcessView(
        countKey: "\(Disk.name)_processes",
        inputColorKey: "\(Disk.name)_readColor",
        outputColorKey: "\(Disk.name)_writeColor"
    )
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.readColorState = Color.fromString(Store.shared.string(key: "\(Disk.name)_readColor", defaultValue: self.readColorState.key))
        self.writeColorState = Color.fromString(Store.shared.string(key: "\(Disk.name)_writeColor", defaultValue: self.writeColorState.key))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        
        self.addArrangedSubview(self.disks)
        self.addArrangedSubview(self.processes)
        
        self.recalculateHeight()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func recalculateHeight() {
        let h = self.subviews.map({ $0.bounds.height }).reduce(0, +)
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    internal func capacityCallback(_ value: Disks) {
        defer {
            let h = self.disks.subviews.map({ $0.bounds.height + self.disks.spacing }).reduce(0, +) - self.disks.spacing
            if h > 0 && self.disks.frame.size.height != h {
                self.disks.setFrameSize(NSSize(width: self.frame.width, height: h))
                self.recalculateHeight()
            }
        }
        
        self.disks.subviews.filter{ $0 is DiskView }.map{ $0 as! DiskView }.forEach { (v: DiskView) in
            if !value.map({$0.BSDName}).contains(v.BSDName) {
                v.removeFromSuperview()
            }
        }
        
        value.forEach { (drive: drive) in
            if let view = self.disks.subviews.filter({ $0 is DiskView }).map({ $0 as! DiskView }).first(where: { $0.BSDName == drive.BSDName }) {
                view.update(free: drive.free, smart: drive.smart)
            } else {
                self.disks.addArrangedSubview(DiskView(
                    width: self.frame.width,
                    BSDName: drive.BSDName,
                    name: drive.mediaName,
                    size: drive.size,
                    free: drive.free,
                    path: drive.path,
                    smart: drive.smart
                ))
            }
        }
    }
    
    internal func activityCallback(_ value: Disks) {
        let views = self.disks.subviews.filter{ $0 is DiskView }.map{ $0 as! DiskView }
        value.reversed().forEach { (drive: drive) in
            if let view = views.first(where: { $0.name == drive.mediaName }) {
                view.updateReadWrite(read: drive.activity.read, write: drive.activity.write)
            }
        }
    }
    
    internal func processCallback(_ list: [Disk_process]) {
        self.processes.update(list)
    }
    
    internal func numberOfProcessesUpdated() {
        self.processes.reinit()
        self.recalculateHeight()
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Write color"),
            action: #selector(toggleWriteColor),
            items: Color.allColors,
            selected: self.writeColorState.key
        ))
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Read color"),
            action: #selector(toggleReadColor),
            items: Color.allColors,
            selected: self.readColorState.key
        ))
        
        return view
    }
    
    @objc private func toggleWriteColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.writeColorState = newValue
        Store.shared.set(key: "\(Disk.name)_writeColor", value: key)
        if let color = newValue.additional as? NSColor {
            for view in self.disks.subviews.filter({ $0 is DiskView }).map({ $0 as! DiskView }) {
                view.setChartColor(write: color)
            }
        }
        self.processes.updateColors()
    }
    @objc private func toggleReadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.readColorState = newValue
        Store.shared.set(key: "\(Disk.name)_readColor", value: key)
        if let color = newValue.additional as? NSColor {
            for view in self.disks.subviews.filter({ $0 is DiskView }).map({ $0 as! DiskView }) {
                view.setChartColor(read: color)
            }
        }
        self.processes.updateColors()
    }
}

internal class DiskView: NSStackView {
    public var name: String
    public var BSDName: String
    
    private var nameView: NameView
    private var chartView: ChartView
    private var barView: BarView
    private var legendView: LegendView
    private var temperatureView: TemperatureView?
    private var lifeView: LifeView?
    
    init(width: CGFloat, BSDName: String, name: String, size: Int64, free: Int64, path: URL?, smart: smart_t?) {
        self.BSDName = BSDName
        self.name = name
        let innerWidth: CGFloat = width - (Constants.Popup.margins * 2)
        self.nameView = NameView(width: innerWidth, name: name, size: size, free: free, path: path)
        self.chartView = ChartView(width: innerWidth)
        self.barView = BarView(width: innerWidth, size: size, free: free)
        self.legendView = LegendView(width: innerWidth, id: "\(name)_\(path?.absoluteString ?? "")", size: size, free: free)
        if let smart {
            self.temperatureView = TemperatureView(width: innerWidth, smart: smart)
            self.lifeView = LifeView(width: innerWidth, smart: smart)
        }
        
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
        if smart != nil, let temperatureView = self.temperatureView, let lifeView = self.lifeView {
            self.addArrangedSubview(temperatureView)
            self.addArrangedSubview(lifeView)
        }
        
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
    
    public func update(free: Int64, smart: smart_t?) {
        self.nameView.update(free: free, read: nil, write: nil)
        self.legendView.update(free: free)
        self.barView.update(free: free)
        self.temperatureView?.update(smart)
        self.lifeView?.update(smart)
    }
    
    public func updateReadWrite(read: Int64, write: Int64) {
        self.nameView.update(free: nil, read: read, write: write)
        self.chartView.update(read: read, write: write)
    }
    public func setChartColor(read: NSColor? = nil, write: NSColor? = nil) {
        self.chartView.setColors(read: read, write: write)
    }
}

internal class NameView: NSStackView {
    private let size: Int64
    private let uri: URL?
    private var ready: Bool = false
    
    private var readState: NSView? = nil
    private var writeState: NSView? = nil
    
    private var readColor: NSColor {
        Color.fromString(Store.shared.string(key: "\(Disk.name)_readColor", defaultValue: Color.secondBlue.key)).additional as! NSColor
    }
    private var writeColor: NSColor {
        Color.fromString(Store.shared.string(key: "\(Disk.name)_writeColor", defaultValue: Color.secondRed.key)).additional as! NSColor
    }
    
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
        let readState: NSView = NSView(frame: NSRect(x: 13, y: (readView.frame.height-9)/2, width: 10, height: 10))
        readState.wantsLayer = true
        readState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
        readState.layer?.cornerRadius = 2
        
        let writeView: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: activity.frame.height))
        let writeField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: nameField.frame.width, height: readView.frame.height))
        writeField.stringValue = "W"
        let writeState: NSView = NSView(frame: NSRect(x: 17, y: (writeView.frame.height-10)/2, width: 10, height: 10))
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
                self.readState?.layer?.backgroundColor = read != 0 ? self.readColor.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
            }
            if let write = write {
                self.writeState?.toolTip = DiskSize(write).getReadableMemory()
                self.writeState?.layer?.backgroundColor = write != 0 ? self.writeColor.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
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
    
    private var readColor: NSColor {
        Color.fromString(Store.shared.string(key: "\(Disk.name)_readColor", defaultValue: Color.secondBlue.key)).additional as! NSColor
    }
    private var writeColor: NSColor {
        Color.fromString(Store.shared.string(key: "\(Disk.name)_writeColor", defaultValue: Color.secondRed.key)).additional as! NSColor
    }
    
    public init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 36))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        
        let chart = NetworkChartView(frame: NSRect(
            x: 0,
            y: 1,
            width: self.frame.width,
            height: self.frame.height - 2
        ), num: 120, outColor: self.writeColor, inColor: self.readColor)
        self.chart = chart
        
        self.addArrangedSubview(chart)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = self.isDarkMode ? NSColor.lightGray.withAlphaComponent(0.1).cgColor : NSColor.white.cgColor
    }
    
    public func update(read: Int64, write: Int64) {
        self.chart?.addValue(upload: Double(write), download: Double(read))
    }
    
    public func setColors(read: NSColor? = nil, write: NSColor? = nil) {
        self.chart?.setColors(in: read, out: write)
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
            Store.shared.bool(key: "\(self.id)_usedSpace", defaultValue: false)
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
        percentageField.stringValue = self.percentage(free: free)
        
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

internal class TemperatureView: NSStackView {
    private var initialized: Bool = false
    private let field: NSTextField = TextView()
    
    init(width: CGFloat, smart: smart_t) {
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 16))
        
        self.orientation = .horizontal
        self.spacing = 0
        
        let title = TextView()
        title.font = NSFont.systemFont(ofSize: 11, weight: .light)
        title.stringValue = "\(localizedString("Temperature")):"
        title.cell?.truncatesLastVisibleLine = true
        
        self.field.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        self.field.alignment = .right
        self.field.stringValue = "\(temperature(Double(smart.temperature)))"
        
        self.addArrangedSubview(title)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(self.field)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ newValue: smart_t?) {
        if (self.window?.isVisible ?? false) || !self.initialized {
            if let newValue {
                self.field.stringValue = "\(temperature(Double(newValue.temperature)))"
            } else {
                self.field.stringValue = "-"
            }
            self.initialized = true
        }
    }
}

internal class LifeView: NSStackView {
    private var initialized: Bool = false
    private let field: NSTextField = TextView()
    
    init(width: CGFloat, smart: smart_t) {
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 16))
        
        self.orientation = .horizontal
        self.spacing = 0
        
        let title = TextView()
        title.font = NSFont.systemFont(ofSize: 11, weight: .light)
        title.stringValue = "\(localizedString("Health")):"
        title.cell?.truncatesLastVisibleLine = true
        
        self.field.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        self.field.alignment = .right
        self.field.stringValue = "\(smart.life)%"
        
        self.addArrangedSubview(title)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(self.field)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ newValue: smart_t?) {
        if (self.window?.isVisible ?? false) || !self.initialized {
            if let newValue {
                self.field.stringValue = "\(newValue.life)%"
            } else {
                self.field.stringValue = "-"
            }
            self.initialized = true
        }
    }
}

public protocol IOProcess_p {
    var pid: Int32 { get }
    var name: String { get }
    var icon: NSImage { get }
    
    var input: String { get }
    var output: String { get }
}

public class IOProcessView: NSStackView {
    private let countKey: String
    private let inputColorKey: String
    private let outputColorKey: String
    
    private var initialized: Bool = false
    
    private var numberOfProcesses: Int {
        Store.shared.int(key: countKey, defaultValue: 5)
    }
    private var readColor: NSColor {
        Color.fromString(Store.shared.string(key: inputColorKey, defaultValue: Color.secondBlue.key)).additional as! NSColor
    }
    private var writeColor: NSColor {
        Color.fromString(Store.shared.string(key: outputColorKey, defaultValue: Color.secondRed.key)).additional as! NSColor
    }
    
    private var inputBoxView: NSView?
    private var outputBoxView: NSView?
    
    public var height: CGFloat {
        CGFloat((self.numberOfProcesses+1) * 22) + Constants.Popup.separatorHeight
    }
    
    init(countKey: String, inputColorKey: String, outputColorKey: String) {
        self.countKey = countKey
        self.inputColorKey = inputColorKey
        self.outputColorKey = outputColorKey
        
        super.init(frame: NSRect.zero)
        
        self.orientation = .vertical
        self.spacing = 1
        
        self.reinit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func reinit() {
        self.subviews.forEach({ $0.removeFromSuperview() })
        
        if self.numberOfProcesses == 0 {
            self.setFrameSize(NSSize(width: self.frame.width, height: 0))
            return
        }
        
        self.addArrangedSubview(separatorView(localizedString("Top processes"), width: Constants.Popup.width))
        self.addArrangedSubview(self.legendRow())
        for _ in 0..<self.numberOfProcesses {
            self.addArrangedSubview(TopProcess())
        }
        
        self.setFrameSize(NSSize(width: self.frame.width, height: self.height))
    }
    
    private func legendRow() -> NSView {
        let view: NSStackView = NSStackView()
        view.spacing = 50
        view.orientation = .horizontal
        view.heightAnchor.constraint(equalToConstant: 21).isActive = true
        
        let inputView: NSView = NSView()
        inputView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        inputView.heightAnchor.constraint(equalToConstant: 10).isActive = true
        inputView.wantsLayer = true
        inputView.layer?.backgroundColor = self.readColor.cgColor
        inputView.layer?.cornerRadius = 2
        self.inputBoxView = inputView
        
        let outputView: NSView = NSView()
        outputView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        outputView.heightAnchor.constraint(equalToConstant: 10).isActive = true
        outputView.wantsLayer = true
        outputView.layer?.backgroundColor = self.writeColor.cgColor
        outputView.layer?.cornerRadius = 2
        self.outputBoxView = outputView
        
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(inputView)
        view.addArrangedSubview(outputView)
        
        return view
    }
    
    public func update(_ list: [IOProcess_p]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.initialized {
                return
            }
            
            for (i, p) in self.subviews.compactMap({ $0 as? TopProcess }).enumerated() {
                if list.count != self.numberOfProcesses && self.initialized {
                    p.clear()
                }
                if list.indices.contains(i) {
                    p.set(list[i])
                }
            }
            
            self.initialized = true
        })
    }
    
    public func updateColors() {
        self.inputBoxView?.layer?.backgroundColor = self.readColor.cgColor
        self.outputBoxView?.layer?.backgroundColor = self.writeColor.cgColor
    }
}

public class TopProcess: NSStackView {
    private var imageView: NSImageView = NSImageView()
    private var labelView: NSTextField = LabelField()
    private var inputView: NSTextField = ValueField()
    private var outputView: NSTextField = ValueField()
    
    init() {
        super.init(frame: NSRect.zero)
        
        self.orientation = .horizontal
        self.spacing = 0
        self.alignment = .centerY
        self.layer?.cornerRadius = 3
        
        self.labelView.cell?.truncatesLastVisibleLine = true
        self.inputView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        self.outputView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        
        self.addArrangedSubview(self.imageView)
        self.addArrangedSubview(self.labelView)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(self.inputView)
        self.addArrangedSubview(self.outputView)
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: 264, height: 21),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            self.imageView.widthAnchor.constraint(equalToConstant: 12),
            self.labelView.heightAnchor.constraint(equalToConstant: 16),
            self.inputView.widthAnchor.constraint(equalToConstant: 60),
            self.outputView.widthAnchor.constraint(equalToConstant: 60),
            self.heightAnchor.constraint(equalToConstant: 21)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func mouseEntered(with: NSEvent) {
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.05)
    }
    public override func mouseExited(with: NSEvent) {
        self.layer?.backgroundColor = .none
    }
    
    public func set(_ process: IOProcess_p) {
        self.imageView.image = process.icon
        self.labelView.stringValue = process.name
        self.inputView.stringValue = process.input
        self.outputView.stringValue = process.output
        self.toolTip = "pid: \(process.pid)"
    }
    
    public func clear() {
        self.inputView.stringValue = "-"
        self.outputView.stringValue = "-"
        self.toolTip = ""
    }
}
