//
//  preview.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 22/04/2026
//  Using Swift 6.0
//  Running on macOS 26.4
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Preview: PreviewWrapper {
    private var main: disk_s? = nil
    
    private var circle: PieChartView? = nil
    private var bar: BarChartView? = nil
    private var chart: NetworkChartView? = nil
    
    private var usedField: NSTextField? = nil
    private var freeField: NSTextField? = nil
    
    private var readState: NSView? = nil
    private var writeState: NSView? = nil
    
    private var allDisks: PreferencesSection? = nil
    private var disks: NSGridView = {
        let grid = NSGridView(frame: .zero)
        grid.rowSpacing = Constants.Settings.margin
        grid.rowAlignment = .none
        grid.yPlacement = .center
        return grid
    }()
    private var diskRows: [String: DiskRow] = [:]
    
    private var initialized: Bool = false
    
    private var readColorState: SColor = .secondBlue
    private var readColor: NSColor { self.readColorState.additional as? NSColor ?? NSColor.systemRed }
    private var writeColorState: SColor = .secondRed
    private var writeColor: NSColor { self.writeColorState.additional as? NSColor ?? NSColor.systemBlue }
    private var reverseOrderState: Bool = false
    
    private var uri: URL? = nil
    private let finder: URL?
    
    private var readSpeedValueField: ValueField?
    private var writeSpeedValueField: ValueField?
    
    private var totalReadValueField: ValueField?
    private var totalWrittenValueField: ValueField?
    
    private var smartTotalReadValueField: ValueField?
    private var smartTotalWrittenValueField: ValueField?
    private var temperatureValueField: ValueField?
    private var healthValueField: ValueField?
    private var powerCyclesValueField: ValueField?
    private var powerOnHoursValueField: ValueField?
    
    public init(_ module: ModuleType) {
        self.finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Finder")
        
        super.init(type: module)
        
        self.loadColors()
        
        self.addArrangedSubview(PreferencesSection([self.usageView()]))
        
        let allDisks = PreferencesSection(title: localizedString("All disks"), subtitle: "", [self.disks])
        allDisks.isHidden = true
        self.addArrangedSubview(allDisks)
        self.allDisks = allDisks
        
        self.addArrangedSubview(PreferencesSection(title: localizedString("Read / Write history"), [self.historyView()]))
        
        let splitView = NSStackView()
        splitView.orientation = .horizontal
        splitView.distribution = .fillEqually
        splitView.alignment = .top
        splitView.addArrangedSubview(PreferencesSection(title: localizedString("Details"), [self.detailsView()]))
        splitView.addArrangedSubview(PreferencesSection(title: localizedString("SMART"), [self.smartView()]))
        
        self.addArrangedSubview(splitView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadColors() {
        self.readColorState = SColor.fromString(Store.shared.string(key: "\(self.module.stringValue)_readColor", defaultValue: self.readColorState.key))
        self.writeColorState = SColor.fromString(Store.shared.string(key: "\(self.module.stringValue)_writeColor", defaultValue: self.writeColorState.key))
        self.reverseOrderState = Store.shared.bool(key: "\(self.module.stringValue)_reverseOrder", defaultValue: self.reverseOrderState)
    }
    
    private func usageView() -> NSView {
        let view = NSStackView()
        view.distribution = .fill
        view.orientation = .horizontal
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 90).isActive = true
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = Constants.Settings.margin
        
        let circle = PieChartView(drawValue: true)
        circle.widthAnchor.constraint(equalToConstant: 90).isActive = true
        circle.toolTip = localizedString("Disk usage")
        self.circle = circle
        
        let details: NSView = {
            let view = NSStackView()
            view.orientation = .vertical
            view.distribution = .fillEqually
            view.spacing = 2
            
            var nameValue = localizedString("Unknown")
            var fileSystemValue = localizedString("Unknown")
            var sizeValue = localizedString("Unknown")
            if let disk = SystemKit.shared.device.info.disk?.first {
                if let name = disk.name {
                    nameValue = name
                }
                if let fileSystem = disk.fileSystem {
                    fileSystemValue = fileSystem.uppercased()
                }
                if let size = disk.size {
                    sizeValue = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                }
                self.main = disk
            }
            
            let title: NSView = {
                let view = NSStackView()
                view.orientation = .horizontal
                view.spacing = 2
                
                let nameField = NSButton()
                nameField.bezelStyle = .inline
                nameField.isBordered = false
                nameField.contentTintColor = .labelColor
                nameField.action = #selector(self.openDisk)
                nameField.target = self
                nameField.toolTip = nameValue
                nameField.title = nameValue
                nameField.cell?.truncatesLastVisibleLine = true
                
                let fileSystemField = LabelField(fileSystemValue)
                fileSystemField.textColor = .tertiaryLabelColor
                
                let activity: NSStackView = NSStackView()
                activity.distribution = .fill
                activity.spacing = 2
                
                let readState: NSView = NSView()
                readState.widthAnchor.constraint(equalToConstant: 8).isActive = true
                readState.heightAnchor.constraint(equalToConstant: 8).isActive = true
                readState.wantsLayer = true
                readState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
                readState.layer?.cornerRadius = 4
                readState.toolTip = localizedString("Read")
                let writeState: NSView = NSView()
                writeState.widthAnchor.constraint(equalToConstant: 8).isActive = true
                writeState.heightAnchor.constraint(equalToConstant: 8).isActive = true
                writeState.wantsLayer = true
                writeState.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.75).cgColor
                writeState.layer?.cornerRadius = 4
                writeState.toolTip = localizedString("Write")
                self.readState = readState
                self.writeState = writeState
                
                activity.addArrangedSubview(readState)
                activity.addArrangedSubview(writeState)
                
                view.addArrangedSubview(nameField)
                view.addArrangedSubview(activity)
                view.addArrangedSubview(NSView())
                view.addArrangedSubview(fileSystemField)
                
                return view
            }()
            
            let bar = BarChartView(size: 11, horizontal: true)
            self.bar = bar
            
            let levels = NSStackView()
            levels.orientation = .horizontal
            levels.distribution = .fill
            
            self.usedField = previewRow(levels, space: false, color: NSColor.systemBlue, title: "\(localizedString("Used")):", value: "")
            self.freeField = previewRow(levels, space: false, color: NSColor.lightGray, title: "\(localizedString("Free")):", value: "")
            
            let fileSystemField = LabelField(sizeValue)
            fileSystemField.textColor = .tertiaryLabelColor
            
            levels.addArrangedSubview(NSView())
            levels.addArrangedSubview(fileSystemField)
            
            view.addArrangedSubview(title)
            view.addArrangedSubview(bar)
            view.addArrangedSubview(levels)
            
            return view
        }()
        
        view.addArrangedSubview(circle)
        view.addArrangedSubview(details)
        
        return view
    }
    
    private func historyView() -> NSView {
        let view: NSStackView = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = Constants.Settings.margin*2
        view.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let chart = NetworkChartView(frame: .zero, num: 600)
        self.chart = chart
        chart.setColors(in: self.readColor, out: self.writeColor)
        chart.setReverseOrder(self.reverseOrderState)
        chart.setLegend(x: true, y: false)
        view.addArrangedSubview(chart)
        
        return view
    }
    
    private func detailsView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.readSpeedValueField = previewRow(view, color: self.readColor, title: "\(localizedString("Read")):", value: "0 KB/s")
        self.writeSpeedValueField = previewRow(view, color: self.writeColor, title: "\(localizedString("Write")):", value: "0 KB/s")
        self.totalReadValueField = previewRow(view, title: "\(localizedString("Total read")):", value: "0 KB")
        self.totalWrittenValueField = previewRow(view, title: "\(localizedString("Total written")):", value: "0 KB")
        
        return view
    }
    
    private func smartView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.distribution = .fillEqually
        view.spacing = 2
        
        self.smartTotalReadValueField = previewRow(view, title: "\(localizedString("Total read")):", value: "0 KB")
        self.smartTotalWrittenValueField = previewRow(view, title: "\(localizedString("Total written")):", value: "0 KB")
        self.temperatureValueField = previewRow(view, title: "\(localizedString("Temperature")):", value: "\(temperature(0))")
        self.healthValueField = previewRow(view, title: "\(localizedString("Health")):", value: "0%")
        self.powerCyclesValueField = previewRow(view, title: "\(localizedString("Power cycles")):", value: "0")
        self.powerOnHoursValueField = previewRow(view, title: "\(localizedString("Power on hours")):", value: "0")
        
        return view
    }
    
    internal func capacityCallback(_ value: Disks) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                if let main = self.main, let update = value.first(where: { $0.uuid == main.id }) {
                    let free = update.free
                    let used = update.size - free
                    self.usedField?.stringValue = DiskSize(used).getReadableMemory()
                    self.freeField?.stringValue = DiskSize(free).getReadableMemory()
                    
                    self.circle?.setValue(update.percentage)
                    self.bar?.setValue(ColorValue(update.percentage, color: update.percentage.usageColor()))
                    
                    self.uri = update.path
                    
                    if let smart = update.smart {
                        self.smartTotalReadValueField?.toolTip = "\(smart.totalRead / (512 * 1000))"
                        self.smartTotalWrittenValueField?.toolTip = "\(smart.totalWritten / (512 * 1000))"
                        self.smartTotalReadValueField?.stringValue = Units(bytes: smart.totalRead).getReadableMemory()
                        self.smartTotalWrittenValueField?.stringValue = Units(bytes: smart.totalWritten).getReadableMemory()
                        
                        self.temperatureValueField?.stringValue = "\(temperature(Double(smart.temperature)))"
                        self.healthValueField?.stringValue = "\(smart.life)%"
                        
                        self.powerCyclesValueField?.stringValue = "\(smart.powerCycles)"
                        self.powerOnHoursValueField?.stringValue = "\(smart.powerOnHours)"
                    }
                }
                
                let drives = value.filter(where: { $0.uuid != self.main?.id })
                
                if drives.isEmpty {
                    self.allDisks?.isHidden = true
                } else if !drives.isEmpty {
                    self.allDisks?.isHidden = false
                }
                
                let mounted = value.count
                let external = value.filter(where: { $0.removable }).count
                self.allDisks?.setSubtitle("\(mounted) \(localizedString("mounted")) · \(external) \(localizedString("removable"))")
                
                let driveUUIDs = Set(drives.map { $0.uuid })
                for uuid in Array(self.diskRows.keys) where !driveUUIDs.contains(uuid) {
                    if let row = self.diskRows[uuid] {
                        row.cells.forEach { $0.removeFromSuperview() }
                        if let gridRow = row.gridRow {
                            let index = self.disks.index(of: gridRow)
                            if index != NSNotFound {
                                self.disks.removeRow(at: index)
                            }
                        }
                        if let sepRow = row.separatorRow {
                            let index = self.disks.index(of: sepRow)
                            if index != NSNotFound {
                                self.disks.removeRow(at: index)
                            }
                        }
                        self.diskRows.removeValue(forKey: uuid)
                    }
                }
                let firstRow = self.diskRows.values
                    .compactMap { row -> (row: DiskRow, index: Int)? in
                        guard let gr = row.gridRow else { return nil }
                        let idx = self.disks.index(of: gr)
                        return idx == NSNotFound ? nil : (row, idx)
                    }
                    .min(by: { $0.index < $1.index })?.row
                if let firstRow = firstRow, let sepRow = firstRow.separatorRow {
                    let index = self.disks.index(of: sepRow)
                    if index != NSNotFound {
                        self.disks.removeRow(at: index)
                    }
                    firstRow.separatorRow = nil
                }
                
                drives.forEach { drive in
                    if let row = self.diskRows[drive.uuid] {
                        row.update(drive)
                    } else {
                        let row = DiskRow(drive)
                        let isFirst = self.disks.numberOfRows == 0
                        if !self.diskRows.isEmpty {
                            let sep = NSView()
                            sep.wantsLayer = true
                            sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.05).cgColor
                            sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                            let sepCells = (0..<max(1, self.disks.numberOfColumns)).map { _ -> NSView in NSView() }
                            var cells: [NSView] = sepCells
                            cells[0] = sep
                            let sepRow = self.disks.addRow(with: cells)
                            if self.disks.numberOfColumns > 1 {
                                sepRow.mergeCells(in: NSRange(location: 0, length: self.disks.numberOfColumns))
                            }
                            row.separatorRow = sepRow
                        }
                        row.gridRow = self.disks.addRow(with: row.cells)
                        if isFirst {
                            self.disks.column(at: 0).xPlacement = .leading
                            self.disks.column(at: 1).xPlacement = .center
                            self.disks.column(at: 2).xPlacement = .trailing
                        }
                        self.diskRows[drive.uuid] = row
                    }
                }
                
                self.initialized = true
            }
        })
    }
    
    internal func activityCallback(_ value: Disks) {
        guard let main = self.main, let update = value.first(where: { $0.uuid == main.id }) else {
            return
        }
        let read = update.activity.read
        let write = update.activity.write
        
        self.chart?.addValue(upload: Double(write), download: Double(read))
        
        self.readState?.toolTip = "Read: \(Units(bytes: read).getReadableSpeed())"
        self.readState?.layer?.backgroundColor = read != 0 ? self.readColor.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
        
        self.writeState?.toolTip = "Write: \(Units(bytes: write).getReadableSpeed())"
        self.writeState?.layer?.backgroundColor = write != 0 ? self.writeColor.cgColor : NSColor.lightGray.withAlphaComponent(0.75).cgColor
        
        self.readSpeedValueField?.stringValue = Units(bytes: read).getReadableSpeed()
        self.writeSpeedValueField?.stringValue = Units(bytes: write).getReadableSpeed()
        
        let stats = update.activity
        self.totalReadValueField?.stringValue = Units(bytes: stats.readBytes).getReadableMemory()
        self.totalReadValueField?.toolTip = "\(stats.readBytes / (512 * 1000))"
        self.totalWrittenValueField?.stringValue = Units(bytes: stats.writeBytes).getReadableMemory()
        self.totalWrittenValueField?.toolTip = "\(stats.writeBytes / (512 * 1000))"
    }
    
    @objc private func openDisk() {
        if let uri = self.uri, let finder = self.finder {
            NSWorkspace.shared.open([uri], withApplicationAt: finder, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

internal class DiskRow {
    public let uuid: String
    public var gridRow: NSGridRow?
    public var separatorRow: NSGridRow?
    
    private let nameField: NSButton
    private let capacityField: LegendView
    private let bar: BarChartView = BarChartView(size: 6, horizontal: true)
    private let capacityView: NSStackView = NSStackView()
    private let fileSystemField: NSTextField
    private let ejectButton: NSButton = NSButton()

    private let uri: URL?
    private let finder: URL?

    public var cells: [NSView] { [self.nameField, self.capacityView, self.fileSystemField, self.ejectButton] }
    
    init(_ drive: drive) {
        self.uuid = drive.uuid
        self.uri = drive.path
        self.finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Finder")
        
        self.nameField = NSButton()
        self.nameField.bezelStyle = .inline
        self.nameField.isBordered = false
        self.nameField.contentTintColor = .labelColor
        self.nameField.action = #selector(self.openDisk)
        self.nameField.toolTip = drive.mediaName
        self.nameField.title = drive.mediaName
        self.nameField.cell?.truncatesLastVisibleLine = true
        self.nameField.font = .systemFont(ofSize: 11, weight: .semibold)
        
        self.fileSystemField = LabelField(drive.fileSystem.uppercased())
        self.fileSystemField.font = .systemFont(ofSize: 10, weight: .regular)
        self.fileSystemField.textColor = .tertiaryLabelColor
        
        self.ejectButton.bezelStyle = .inline
        self.ejectButton.isBordered = false
        self.ejectButton.imagePosition = .imageOnly
        self.ejectButton.image = NSImage(systemSymbolName: "eject", accessibilityDescription: localizedString("Eject"))
        self.ejectButton.contentTintColor = .secondaryLabelColor
        self.ejectButton.toolTip = localizedString("Eject")
        self.ejectButton.isEnabled = drive.removable && drive.path != nil
        self.ejectButton.action = #selector(self.ejectDisk)
        
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        self.capacityField = LegendView(id: drive.uuid, size: drive.size, free: drive.free)
        topRow.addArrangedSubview(self.capacityField)
        topRow.addArrangedSubview(NSView())
        
        self.capacityView.orientation = .vertical
        self.capacityView.translatesAutoresizingMaskIntoConstraints = false
        self.capacityView.edgeInsets = NSEdgeInsets(top: 0, left: Constants.Settings.margin, bottom: 0, right: 0)
        
        self.capacityView.addArrangedSubview(topRow)
        self.capacityView.addArrangedSubview(self.bar)
        
        self.update(drive)
        
        self.nameField.target = self
        self.ejectButton.target = self
    }
    
    public func update(_ drive: drive) {
        if self.nameField.title != drive.mediaName {
            self.nameField.title = drive.mediaName
            self.nameField.toolTip = drive.mediaName
        }
        let fs = drive.fileSystem.uppercased()
        if self.fileSystemField.stringValue != fs {
            self.fileSystemField.stringValue = fs
        }
        self.ejectButton.isEnabled = drive.removable && drive.path != nil
        self.capacityField.update(free: drive.free)
        self.bar.setValue(ColorValue(drive.percentage, color: drive.percentage.usageColor()))
    }
    
    @objc private func openDisk() {
        if let uri = self.uri, let finder = self.finder {
            NSWorkspace.shared.open([uri], withApplicationAt: finder, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @objc private func ejectDisk() {
        guard let uri = self.uri else { return }
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: uri)
        } catch let err {
            error("failed to eject \(uri.path): \(err.localizedDescription)")
        }
    }
}

private class LegendView: NSStackView {
    private let size: Int64
    private var free: Int64
    private let id: String
    private var ready: Bool = false
    
    private var showUsedSpace: Bool {
        get { Store.shared.bool(key: "\(self.id)_preview_usedSpace", defaultValue: false) }
        set { Store.shared.set(key: "\(self.id)_preview_usedSpace", value: newValue) }
    }
    
    private var legendField: NSTextField? = nil
    
    public init(id: String, size: Int64, free: Int64) {
        self.id = id
        self.size = size
        self.free = free
        
        super.init(frame: .zero)
        self.toolTip = localizedString("Switch view")
        
        let legendField = TextView()
        legendField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        legendField.stringValue = self.legend(free: free)
        legendField.cell?.truncatesLastVisibleLine = true
        
        self.addArrangedSubview(legendField)
        
        self.legendField = legendField
        
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
            self.ready = true
        }
    }
    
    private func legend(free: Int64) -> String {
        var value: String
        var percentage: Int
        
        if self.showUsedSpace {
            var usedSpace = self.size - free
            if usedSpace < 0 {
                usedSpace = 0
            }
            percentage = Int((Double(self.size - free) / Double(self.size)) * 100)
            value = localizedString("Used disk memory", DiskSize(usedSpace).getReadableMemory(), DiskSize(self.size).getReadableMemory())
        } else {
            percentage = Int((Double(free) / Double(self.size)).rounded(toPlaces: 2) * 100)
            value = localizedString("Free disk memory", DiskSize(free).getReadableMemory(), DiskSize(self.size).getReadableMemory())
        }
        
        value += " (\(percentage)%)"
        
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
    }
}
