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
import Kit

class Dashboard: NSStackView {
    private var processorValue: String {
        guard let cpu = SystemKit.shared.device.info.cpu, cpu.name != nil || cpu.physicalCores != nil || cpu.logicalCores != nil else {
            return localizedString("Unknown")
        }
        
        var value = ""
        
        if let name = cpu.name {
            value += name
        }
        
        if cpu.physicalCores != nil || cpu.logicalCores != nil {
            if !value.isEmpty {
                value += "\n"
            }
            
            var mini = ""
            if let cores = cpu.physicalCores {
                mini += localizedString("Number of cores", "\(cores)")
            }
            if let threads = cpu.logicalCores {
                if mini != "" {
                    mini += ", "
                }
                mini += localizedString("Number of threads", "\(threads)")
            }
            value += "\(mini)"
        }
        
        if cpu.eCores != nil || cpu.pCores != nil {
            if !value.isEmpty {
                value += "\n"
            }
            
            var mini = ""
            if let eCores = cpu.eCores {
                mini += localizedString("Number of e-cores", "\(eCores)")
            }
            if let pCores = cpu.pCores {
                if mini != "" {
                    mini += "\n"
                }
                mini += localizedString("Number of p-cores", "\(pCores)")
            }
            value += "\(mini)"
        }
        
        return value
    }
    private var memoryValue: String {
        guard let dimms = SystemKit.shared.device.info.ram?.dimms else {
            return localizedString("Unknown")
        }
        
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useGB]
        sizeFormatter.countStyle = .memory
        
        var value = ""
        for i in 0..<dimms.count {
            let dimm = dimms[i]
            var row = ""
            
            if let size = dimm.size {
                row += size
            }
            
            if let speed = dimm.speed {
                if !row.isEmpty && row.last != " " {
                    row += " "
                }
                row += speed
            }
            
            if let type = dimm.type {
                if !row.isEmpty && row.last != " " {
                    row += " "
                }
                row += type
            }
            
            if dimm.bank != nil || dimm.channel != nil {
                if !row.isEmpty && row.last != " " {
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
        return value
    }
    private var graphicsValue: String {
        guard let gpus = SystemKit.shared.device.info.gpu else {
            return localizedString("Unknown")
        }
        
        var value = ""
        for i in 0..<gpus.count {
            var row = gpus[i].name != nil ? gpus[i].name! : localizedString("Unknown")
            
            if gpus[i].vram != nil || gpus[i].cores != nil {
                row += " ("
                if let cores = gpus[i].cores {
                    row += localizedString("Number of cores", "\(cores)")
                }
                if let size = gpus[i].vram {
                    if gpus[i].cores != nil {
                        row += ", \(size)"
                    } else {
                        row += "\(size)"
                    }
                }
                row += ")"
            }
            
            value += "\(row)\(i == gpus.count-1 ? "" : "\n")"
        }
        return value
    }
    private var uptimeValue: String {
        let form = DateComponentsFormatter()
        form.maximumUnitCount = 2
        form.unitsStyle = .full
        form.allowedUnits = [.day, .hour, .minute]
        
        var value = localizedString("Unknown")
        if let bootDate = SystemKit.shared.device.bootDate {
            if let duration = form.string(from: bootDate, to: Date()) {
                value = duration
            }
        }
        
        return value
    }
    
    private var uptimeField: NSTextField?
    
    init() {
        super.init(frame: NSRect.zero)
        
        let scrollView = ScrollableStackView(orientation: .vertical)
        scrollView.stackView.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        scrollView.stackView.spacing = Constants.Settings.margin
        
        scrollView.stackView.addArrangedSubview(self.deviceView())
        
        scrollView.stackView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Processor"), "", component: textView(self.processorValue)),
            PreferencesRow(localizedString("Memory"), component: textView(self.memoryValue)),
            PreferencesRow(localizedString("Graphics"), component: textView(self.graphicsValue))
        ]))
        
        scrollView.stackView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Model id"), component: textView(SystemKit.shared.device.model.id)),
            PreferencesRow(localizedString("Production year"), component: textView("\(SystemKit.shared.device.model.year)")),
            PreferencesRow(localizedString("Serial number"), component: textView(SystemKit.shared.device.serialNumber ?? localizedString("Unknown")))
        ]))
        
        self.uptimeField = textView(self.uptimeValue)
        scrollView.stackView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Uptime"), component: self.uptimeField!)
        ]))
        
        self.addArrangedSubview(scrollView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowOpens), name: .openModuleSettings, object: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .openModuleSettings, object: nil)
    }
    
    private func deviceView() -> NSView {
        let container: NSGridView = NSGridView()
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let deviceImageView: NSImageView = NSImageView(image: SystemKit.shared.device.model.icon)
        deviceImageView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        deviceImageView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let deviceNameField: NSTextField = TextView()
        deviceNameField.alignment = .center
        deviceNameField.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        deviceNameField.stringValue = SystemKit.shared.device.model.name
        deviceNameField.isSelectable = true
        deviceNameField.toolTip = SystemKit.shared.device.model.id
        
        let osField: NSTextField = TextView()
        osField.alignment = .center
        osField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        osField.stringValue = "macOS \(SystemKit.shared.device.os?.name ?? localizedString("Unknown")) (\(SystemKit.shared.device.os?.version.getFullVersion() ?? ""))"
        osField.isSelectable = true
        
        container.addRow(with: [deviceImageView])
        container.addRow(with: [deviceNameField])
        container.addRow(with: [osField])
        
        container.row(at: 1).height = 22
        container.row(at: 2).height = 20
        
        return container
    }
    
    @objc private func windowOpens(_ notification: Notification) {
        guard notification.userInfo?["module"] as? String == "Dashboard" else { return }
        self.uptimeField?.stringValue = self.uptimeValue
    }
}
