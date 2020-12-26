//
//  Stats.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 24/12/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import StatsKit
import ModuleKit
import os.log

class Dashboard: NSScrollView {
    private var uptimeField: NSTextField? = nil
    
    init() {
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: 540,
            height: 480
        ))
        
        self.drawsBackground = false
        self.borderType = .noBorder
        self.hasVerticalScroller = true
        self.hasHorizontalScroller = false
        self.autohidesScrollers = true
        self.horizontalScrollElasticity = .none
        self.automaticallyAdjustsContentInsets = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowOpens), name: .openModuleSettings, object: nil)
        
        let versionsView = self.versions()
        let specsView = self.specs()
        
        let grid: NSGridView = NSGridView(frame: NSRect(
            x: 0,
            y: 0,
            width: self.frame.width,
            height: versionsView.frame.height + specsView.frame.height
        ))
        grid.rowSpacing = 0
        grid.yPlacement = .fill
        
        let separator = NSBox()
        separator.boxType = .separator
        
        grid.addRow(with: [versionsView])
        grid.addRow(with: [separator])
        grid.addRow(with: [specsView])
        
        grid.row(at: 0).height = versionsView.frame.height
        grid.row(at: 2).height = specsView.frame.height
        
        self.documentView = grid
        if let documentView = self.documentView {
            documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func versions() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 280))
        
        let h: CGFloat = 120+60+18
        let container: NSGridView = NSGridView(frame: NSRect(x: 0, y: (view.frame.height-h)/2, width: self.frame.width, height: h))
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let deviceImageView: NSImageView = NSImageView(image: SystemKit.shared.device.model.icon)
        deviceImageView.frame = NSRect(x: (view.frame.width - 160)/2, y: 0, width: 160, height: 120)
        
        let deviceNameField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 22))
        deviceNameField.alignment = .center
        deviceNameField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        deviceNameField.stringValue = SystemKit.shared.device.model.name
        deviceNameField.isSelectable = true
        deviceNameField.toolTip = SystemKit.shared.device.modelIdentifier
        
        let osField: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 18))
        osField.alignment = .center
        osField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        osField.stringValue = "macOS \(SystemKit.shared.device.os?.name ?? LocalizedString("Unknown")) (\(SystemKit.shared.device.os?.version.getFullVersion() ?? ""))"
        osField.isSelectable = true
        
        container.addRow(with: [deviceImageView])
        container.addRow(with: [deviceNameField])
        container.addRow(with: [osField])
        
        container.column(at: 0).width = self.frame.width
        container.row(at: 1).height = 22
        container.row(at: 2).height = 20
        
        view.addSubview(container)
        return view
    }
    
    private func specs() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        let grid: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        grid.rowSpacing = 10
        grid.columnSpacing = 20
        grid.xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        let separator = NSBox()
        separator.boxType = .separator
        
        grid.addRow(with: self.processor())
        grid.addRow(with: self.ram())
        grid.addRow(with: self.gpu())
        grid.addRow(with: self.disk())
        grid.addRow(with: self.serialNumber())
        
        grid.addRow(with: [separator])
        grid.row(at: 5).mergeCells(in: NSRange(location: 0, length: 2))
        grid.row(at: 5).topPadding = 5
        grid.row(at: 5).bottomPadding = 5
        
        grid.addRow(with: self.upTime())
        
        view.addSubview(grid)
        
        var height: CGFloat = (CGFloat(grid.numberOfRows)-2) * grid.rowSpacing
        for i in 0..<grid.numberOfRows {
            let row = grid.row(at: i)
            for a in 0..<row.numberOfCells {
                if let contentView = row.cell(at: a).contentView {
                    height += contentView.frame.height
                }
            }
        }
        view.setFrameSize(NSSize(width: view.frame.width, height: height))
        
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        return view
    }
    
    @objc private func windowOpens(_ notification: Notification) {
        guard notification.userInfo?["module"] as? String == "Stats" else {
            return
        }
        
        let form = DateComponentsFormatter()
        form.maximumUnitCount = 2
        form.unitsStyle = .full
        form.allowedUnits = [.day, .hour, .minute]
        if let bootDate = SystemKit.shared.device.bootDate {
            if let duration = form.string(from: bootDate, to: Date()) {
                self.uptimeField?.stringValue = duration
            }
        }
    }
    
    // MARK: - Views
    
    private func processor() -> [NSView] {
        var value = ""
        
        if let cpu = SystemKit.shared.device.info.cpu, cpu.name != nil || cpu.physicalCores != nil || cpu.logicalCores != nil {
            if let name = cpu.name {
                value += name
            }
            
            if cpu.physicalCores != nil || cpu.logicalCores != nil {
                if value.count != 0 {
                    value += "\n"
                }
                
                var mini = ""
                if let cores = cpu.physicalCores {
                    mini += "\(cores) cores"
                }
                if let threads = cpu.logicalCores {
                    if mini != "" {
                        mini += ", "
                    }
                    mini += "\(threads) threads"
                }
                value += "\(mini)"
            }
        } else {
            value = LocalizedString("Unknown")
        }
        
        return [
            self.titleView("\(LocalizedString("Processor")):"),
            self.valueView(value),
        ]
    }
    
    private func ram() -> [NSView] {
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useGB]
        sizeFormatter.countStyle = .memory
        
        var value = ""
        if let dimms = SystemKit.shared.device.info.ram?.dimms {
            for i in 0..<dimms.count {
                let dimm = dimms[i]
                var row = ""
                
                if let size = dimm.size {
                    row += size
                }
                
                if let speed = dimm.speed {
                    if row.count != 0 && row.last != " " {
                        row += " "
                    }
                    row += speed
                }
                
                if let type = dimm.type {
                    if row.count != 0 && row.last != " " {
                        row += " "
                    }
                    row += type
                }
                
                if dimm.bank != nil || dimm.channel != nil {
                    if row.count != 0 && row.last != " " {
                        row += " "
                    }
                    
                    var mini = "("
                    if let bank = dimm.bank {
                        mini += "slot \(bank)"
                    }
                    if let ch = dimm.channel {
                        mini += "\(mini == "(" ? "" : "/")ch \(ch)"
                    }
                    row += "\(mini))"
                }
                
                value += "\(row)\(i == dimms.count-1 ? "" : "\n")"
            }
        } else {
            value = LocalizedString("Unknown")
        }
        
        return [
            self.titleView("\(LocalizedString("Memory")):"),
            self.valueView("\(value)"),
        ]
    }
    
    private func gpu() -> [NSView] {
        var value = ""
        if let gpus = SystemKit.shared.device.info.gpu {
            for i in 0..<gpus.count {
                value += "\(gpus[i].name)\(i == gpus.count-1 ? "" : "\n")"
            }
        } else {
            value = LocalizedString("Unknown")
        }
        
        return [
            self.titleView("\(LocalizedString("Graphics")):"),
            self.valueView(value),
        ]
    }
    
    private func disk() -> [NSView] {
        return [
            self.titleView("\(LocalizedString("Disk")):"),
            self.valueView("\(SystemKit.shared.device.info.disk?.model ?? SystemKit.shared.device.info.disk?.name ?? LocalizedString("Unknown"))"),
        ]
    }
    
    private func serialNumber() -> [NSView] {
        return [
            self.titleView("\(LocalizedString("Serial number")):"),
            self.valueView("\(SystemKit.shared.device.serialNumber ?? LocalizedString("Unknown"))"),
        ]
    }
    
    private func upTime() -> [NSView] {
        let form = DateComponentsFormatter()
        form.maximumUnitCount = 2
        form.unitsStyle = .full
        form.allowedUnits = [.day, .hour, .minute]
        
        var value = LocalizedString("Unknown")
        if let bootDate = SystemKit.shared.device.bootDate {
            if let duration = form.string(from: bootDate, to: Date()) {
                value = duration
            }
        }
        
        let valueView = self.valueView(value)
        self.uptimeField = valueView
        
        return [
            self.titleView("\(LocalizedString("Uptime")):"),
            valueView,
        ]
    }
    
    // MARK: - Helpers
    
    private func titleView(_ value: String) -> NSTextField {
        let field: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 120, height: 17))
        field.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        field.textColor = .labelColor
        field.stringValue = value
        
        return field
    }
    
    private func valueView(_ value: String) -> NSTextField {
        let field: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: 0, height: 17))
        field.font = NSFont.systemFont(ofSize: 13, weight: .light)
        field.alignment = .right
        field.stringValue = value
        field.isSelectable = true
        
        return field
    }
}
