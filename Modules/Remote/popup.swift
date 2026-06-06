//
//  popup.swift
//  Remote
//
//  Created by Serhiy Mytrovtsiy on 20/05/2026.
//  Using Swift 6.0.
//  Running on macOS 26.5.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private let loginPrompt = EmptyView(height: 60, msg: localizedString("Login to System Stats to see your devices"))
    
    private var groups: NSStackView = {
        let view = NSStackView()
        view.spacing = Constants.Popup.spacing*2
        view.orientation = .vertical
        return view
    }()
    
    private var visible: Bool = false
    private var streams: [String: RemoteMachineStream] = [:]
    private var currentMachineIDs: [String] = []
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func recalculateHeight() {
        let h = self.loginPrompt.window != nil ? self.loginPrompt.fittingSize.height : self.groups.fittingSize.height
        if h > 0 && self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    public func authorizationStatus(_ status: Bool) {
        if !status {
            self.addArrangedSubview(self.loginPrompt)
            self.groups.removeFromSuperview()
        } else {
            self.loginPrompt.removeFromSuperview()
            self.addArrangedSubview(self.groups)
        }
        self.recalculateHeight()
    }
    
    public override func appear() {
        super.appear()
        self.visible = true
        self.syncStreams()
    }
    
    public override func disappear() {
        super.disappear()
        self.visible = false
        self.stopStreams()
    }
    
    private func syncStreams() {
        guard self.visible else { return }
        let ids = Set(self.currentMachineIDs)
        
        for (id, stream) in self.streams where !ids.contains(id) {
            stream.stop()
            self.streams.removeValue(forKey: id)
        }
        
        for id in ids where self.streams[id] == nil {
            let stream = RemoteMachineStream(machineID: id) { [weak self] update in
                self?.apply(update, for: id)
            }
            self.streams[id] = stream
            stream.start()
        }
    }
    
    private func stopStreams() {
        self.streams.values.forEach { $0.stop() }
        self.streams.removeAll()
    }
    
    private func apply(_ update: RemoteUpdate, for id: String) {
        _ = self.groups.arrangedSubviews.compactMap { $0 as? GroupView }.first { $0.apply(update, for: id) }
    }
    
    internal func callback(_ snapshot: RemoteSnapshot) {
        let enabledMachines = snapshot.machines.filter { $0.state }
        let enabledHosts = snapshot.hosts.filter { $0.state }
        
        let mi = Dictionary(snapshot.order.machines.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let hi = Dictionary(snapshot.order.hosts.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let groupById = Dictionary(uniqueKeysWithValues: snapshot.groups.map { ($0.id, $0) })
        
        let sortedMachines = enabledMachines.sorted { a, b in
            let ia = mi[a.id] ?? Int.max
            let ib = mi[b.id] ?? Int.max
            if ia != ib { return ia < ib }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        let sortedHosts = enabledHosts.sorted { a, b in
            let ia = hi[a.id] ?? Int.max
            let ib = hi[b.id] ?? Int.max
            if ia != ib { return ia < ib }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        
        var machinesByGroup: [String: [RemoteMachine]] = [:]
        var ungroupedMachines: [RemoteMachine] = []
        for m in sortedMachines {
            if let gid = m.groupID, !gid.isEmpty, groupById[gid] != nil {
                machinesByGroup[gid, default: []].append(m)
            } else {
                ungroupedMachines.append(m)
            }
        }
        var hostsByGroup: [String: [RemoteHost]] = [:]
        var ungroupedHosts: [RemoteHost] = []
        for h in sortedHosts {
            if let gid = h.group, !gid.isEmpty, groupById[gid] != nil {
                hostsByGroup[gid, default: []].append(h)
            } else {
                ungroupedHosts.append(h)
            }
        }
        
        // Desired groups, in order: ungrouped first, then groups (in snapshot order).
        // Each group holds its machines first, then its hosts.
        var groups: [(id: String, title: String?, machines: [RemoteMachine], hosts: [RemoteHost])] = []
        if !ungroupedMachines.isEmpty || !ungroupedHosts.isEmpty {
            groups.append((id: "", title: nil, machines: ungroupedMachines, hosts: ungroupedHosts))
        }
        for group in snapshot.groups {
            let machines = machinesByGroup[group.id] ?? []
            let hosts = hostsByGroup[group.id] ?? []
            if !machines.isEmpty || !hosts.isEmpty {
                groups.append((id: group.id, title: group.name, machines: machines, hosts: hosts))
            }
        }
        
        let sectorIDs = Set(groups.map { $0.id })
        
        // 1. Remove groups that no longer exist
        self.groups.subviews.compactMap { $0 as? GroupView }.filter { !sectorIDs.contains($0.id) }.forEach { $0.removeFromSuperview() }
        
        // 2. Add new / update existing
        groups.forEach { sector in
            if let view = self.groups.subviews.compactMap({ $0 as? GroupView }).first(where: { $0.id == sector.id }) {
                view.update(title: sector.title, machines: sector.machines, hosts: sector.hosts)
            } else {
                let view = GroupView(id: sector.id, title: sector.title)
                view.sizeCallback = { [weak self] in self?.recalculateHeight() }
                view.update(title: sector.title, machines: sector.machines, hosts: sector.hosts)
                self.groups.addArrangedSubview(view)
            }
        }
        
        // 3. Reorder to match `groups`
        groups.enumerated().forEach { (index, sector) in
            if let view = self.groups.arrangedSubviews.compactMap({ $0 as? GroupView }).first(where: { $0.id == sector.id }) {
                self.groups.removeArrangedSubview(view)
                self.groups.insertArrangedSubview(view, at: index)
            }
        }
        
        self.currentMachineIDs = sortedMachines.map { $0.id }
        self.syncStreams()
        
        self.recalculateHeight()
    }
}

private class GroupView: NSStackView {
    public let id: String
    public var sizeCallback: (() -> Void)?
    
    private var titleLabel: LabelField?
    private var header: NSStackView?
    private let statusDot = DotView(color: .tertiaryLabelColor)
    private let chevron = NSImageView()
    private var collapsed: Bool = true
    
    private var currentMachines: [RemoteMachine] = []
    private var currentHosts: [RemoteHost] = []
    
    private let body: NSStackView = {
        let v = NSStackView()
        v.orientation = .vertical
        v.distribution = .fill
        v.spacing = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    public init(id: String, title: String?) {
        self.id = id
        super.init(frame: .zero)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.wantsLayer = true
        self.layer?.cornerRadius = Constants.Popup.radius
        
        if let title, !title.isEmpty {
            self.body.edgeInsets = NSEdgeInsets(top: 0, left: 2, bottom: 4, right: 2)
            
            let header = NSStackView()
            header.orientation = .horizontal
            header.alignment = .centerY
            header.spacing = 4
            header.edgeInsets = NSEdgeInsets(top: 12, left: 6, bottom: 12, right: 6)
            header.translatesAutoresizingMaskIntoConstraints = false
            header.setHuggingPriority(NSLayoutConstraint.Priority(500), for: .vertical)
            
            let label = LabelField(title)
            label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.alignment = .left
            self.titleLabel = label
            
            self.chevron.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
            self.chevron.contentTintColor = .secondaryLabelColor
            self.updateChevron()
            
            header.addArrangedSubview(self.statusDot)
            header.addArrangedSubview(label)
            header.addArrangedSubview(NSView())
            header.addArrangedSubview(self.chevron)
            self.addArrangedSubview(header)
            self.header = header
            
            header.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
            
            let click = NSClickGestureRecognizer(target: self, action: #selector(self.toggleCollapse))
            header.addGestureRecognizer(click)
            
            self.body.isHidden = self.collapsed
        } else {
            self.collapsed = false
            self.body.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)
        }
        
        self.addArrangedSubview(self.body)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (isDarkMode ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25) : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)).cgColor
    }
    
    @objc private func toggleCollapse() {
        self.collapsed.toggle()
        self.body.isHidden = self.collapsed
        self.updateChevron()
        self.sizeCallback?()
    }
    
    private func updateChevron() {
        let name = self.collapsed ? "chevron.forward" : "chevron.down"
        self.chevron.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
    
    public func update(title: String?, machines: [RemoteMachine], hosts: [RemoteHost]) {
        if let titleLabel, let title { titleLabel.stringValue = title }
        self.currentMachines = machines
        self.currentHosts = hosts
        self.statusDot.setColor(self.aggregateColor(machines: machines, hosts: hosts))
        
        // Same add / update / reorder dance you already use, but scoped to this sector's body.
        let machineIDs = Set(machines.map { $0.id })
        self.body.subviews.compactMap { $0 as? MachineView }.filter { !machineIDs.contains($0.id) }.forEach { $0.removeFromSuperview() }
        machines.forEach { machine in
            if let view = self.body.subviews.compactMap({ $0 as? MachineView }).first(where: { $0.id == machine.id }) {
                view.update(machine)
            } else {
                self.body.addArrangedSubview(MachineView(machine))
            }
        }
        
        let hostIDs = Set(hosts.map { $0.id })
        self.body.subviews.compactMap { $0 as? HostRow }.filter { !hostIDs.contains($0.id) }.forEach { $0.removeFromSuperview() }
        hosts.forEach { host in
            if let view = self.body.subviews.compactMap({ $0 as? HostRow }).first(where: { $0.id == host.id }) {
                view.update(host)
            } else {
                self.body.addArrangedSubview(HostRow(host: host))
            }
        }
        
        // Reorder: machines first, then hosts. Hide the separator on the final row.
        let total = machines.count + hosts.count
        machines.enumerated().forEach { (index, machine) in
            if let view = self.body.arrangedSubviews.compactMap({ $0 as? MachineView }).first(where: { $0.id == machine.id }) {
                self.body.removeArrangedSubview(view)
                self.body.insertArrangedSubview(view, at: index)
                view.setLast(index == total - 1)
            }
        }
        hosts.enumerated().forEach { (index, host) in
            if let view = self.body.arrangedSubviews.compactMap({ $0 as? HostRow }).first(where: { $0.id == host.id }) {
                self.body.removeArrangedSubview(view)
                self.body.insertArrangedSubview(view, at: machines.count + index)
                view.setLast(machines.count + index == total - 1)
            }
        }
    }
    
    @discardableResult
    public func apply(_ update: RemoteUpdate, for id: String) -> Bool {
        guard let index = self.currentMachines.firstIndex(where: { $0.id == id }) else { return false }
        let merged = self.currentMachines[index].applying(update)
        self.currentMachines[index] = merged
        self.body.arrangedSubviews.compactMap { $0 as? MachineView }.first { $0.id == id }?.update(merged)
        self.statusDot.setColor(self.aggregateColor(machines: self.currentMachines, hosts: self.currentHosts))
        return true
    }
    
    private func aggregateColor(machines: [RemoteMachine], hosts: [RemoteHost]) -> NSColor {
        var up = 0, total = 0
        for m in machines {
            total += 1
            if m.online { up += 1 }
        }
        for h in hosts {
            total += 1
            if h.lastStatus?.lowercased() == "up" { up += 1 }
        }
        if total == 0 { return .tertiaryLabelColor }
        if up == total { return .systemGreen }
        if up == 0 { return .systemRed }
        return .systemYellow
    }
}

private class MachineView: NSStackView {
    public let id: String
    
    private let dot = DotView(color: .tertiaryLabelColor)
    
    private let cpuLabel = TextView()
    private let cpuBar = BarChartView(horizontal: true)
    private let ramLabel = TextView()
    private let ramBar = BarChartView(horizontal: true)
    
    private let separator = RemoteSeparator()
    private var heightConstraint: NSLayoutConstraint?
    
    public init(_ machine: RemoteMachine) {
        self.id = machine.id
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 43))
        let height = self.heightAnchor.constraint(equalToConstant: 43)
        height.priority = NSLayoutConstraint.Priority(999)
        height.isActive = true
        self.heightConstraint = height
        self.setContentHuggingPriority(.required, for: .vertical)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        self.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 0, right: 6)
        
        let header: NSStackView = {
            let view: NSStackView = NSStackView()
            view.orientation = .horizontal
            view.spacing = 4
            
            self.dot.setColor(machine.online ? .systemGreen : .systemRed)
            let label = LabelField(machine.displayName)
            
            view.addArrangedSubview(self.dot)
            view.addArrangedSubview(label)
            view.addArrangedSubview(NSView())
            
            if let url = machine.uri {
                view.addArrangedSubview(LinkButton(url, size: 10))
            }
            
            return view
        }()
        
        let stats: NSStackView = {
            let view: NSStackView = NSStackView()
            view.spacing = Constants.Popup.margins
            view.orientation = .horizontal
            view.alignment = .centerY
            view.distribution = .fillEqually
            view.translatesAutoresizingMaskIntoConstraints = false
            view.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
            
            let cpuIcon = NSImageView()
            cpuIcon.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: localizedString("CPU"))
            cpuIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            cpuIcon.contentTintColor = .secondaryLabelColor
            cpuIcon.toolTip = localizedString("CPU")
            
            self.cpuLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            self.cpuLabel.textColor = .secondaryLabelColor
            self.cpuLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            let ramIcon = NSImageView()
            ramIcon.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: localizedString("RAM"))
            ramIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            ramIcon.contentTintColor = .secondaryLabelColor
            ramIcon.toolTip = localizedString("RAM")
            
            self.ramLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            self.ramLabel.textColor = .secondaryLabelColor
            self.ramLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            [self.cpuBar, self.ramBar].forEach {
                let height = $0.heightAnchor.constraint(equalToConstant: 4)
                height.priority = .defaultHigh
                height.isActive = true
                $0.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
            }
            
            let cpuGroup = NSStackView(views: [cpuIcon, self.cpuLabel, self.cpuBar])
            cpuGroup.orientation = .horizontal
            cpuGroup.alignment = .centerY
            cpuGroup.spacing = 0
            
            let ramGroup = NSStackView(views: [ramIcon, self.ramLabel, self.ramBar])
            ramGroup.orientation = .horizontal
            ramGroup.alignment = .centerY
            ramGroup.spacing = 0
            
            view.addArrangedSubview(cpuGroup)
            view.addArrangedSubview(ramGroup)
            
            return view
        }()
        
        self.addArrangedSubview(header)
        self.addArrangedSubview(stats)
        self.addArrangedSubview(self.separator)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ machine: RemoteMachine) {
        self.dot.setColor(machine.online ? .systemGreen : .systemRed)
        
        if let cpu = machine.modules?.cpuUsage {
            self.cpuLabel.stringValue = "\(Int(cpu.rounded(toPlaces: 2) * 100))%"
            self.cpuBar.setValue(ColorValue(cpu))
        } else {
            self.cpuLabel.stringValue = "—"
            self.cpuBar.setValue(ColorValue(0))
        }
        if let ram = machine.modules?.ramUsage {
            self.ramLabel.stringValue = "\(Int(ram.rounded(toPlaces: 2) * 100))%"
            self.ramBar.setValue(ColorValue(ram))
        } else {
            self.ramLabel.stringValue = "—"
            self.ramBar.setValue(ColorValue(0))
        }
    }
    
    public func setLast(_ isLast: Bool) {
        self.separator.isHidden = isLast
        self.heightConstraint?.constant = 43 + (isLast ? 0 : 1)
    }
}

internal final class HostRow: NSStackView {
    public let id: String
    
    private let dot = DotView(color: .tertiaryLabelColor)
    private let nameLink: LabelField
    private let latency = TextView()
    private let grid = GridChartView(grid: (24, 1))
    
    private let separator = RemoteSeparator()
    private var heightConstraint: NSLayoutConstraint?
    
    init(host: RemoteHost) {
        self.id = host.id
        self.nameLink = LabelField(host.displayName)
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 36))
        let height = self.heightAnchor.constraint(equalToConstant: 36)
        height.priority = NSLayoutConstraint.Priority(999)
        height.isActive = true
        self.heightConstraint = height
        self.setContentHuggingPriority(.required, for: .vertical)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = Constants.Popup.spacing
        self.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        
        self.nameLink.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        self.nameLink.lineBreakMode = .byTruncatingTail
        
        self.latency.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        self.latency.textColor = .secondaryLabelColor
        
        self.dot.setColor(host.color)
        self.latency.stringValue = host.lastLatencyMs.map { "\($0) ms" } ?? ""
        self.grid.addValue(host.lastStatus?.lowercased() == "up")
        
        let header = NSStackView(views: [self.dot, self.nameLink, NSView(), self.latency])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 4
        header.heightAnchor.constraint(equalToConstant: 22).isActive = true
        
        if let url = host.uri {
            header.addArrangedSubview(LinkButton(url, size: 10))
        }
        
        self.grid.heightAnchor.constraint(equalToConstant: 9).isActive = true
        
        self.addArrangedSubview(header)
        self.addArrangedSubview(self.grid)
        self.addArrangedSubview(self.separator)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(_ host: RemoteHost) {
        self.nameLink.stringValue = host.displayName
        self.dot.setColor(host.color)
        self.latency.stringValue = host.lastLatencyMs.map { "\($0) ms" } ?? ""
        self.grid.addValue(host.lastStatus?.lowercased() == "up")
    }
    
    public func setLast(_ isLast: Bool) {
        self.separator.isHidden = isLast
        self.heightConstraint?.constant = 36 - (isLast ? 1 : 0)
    }
}

private class RemoteSeparator: NSView {
    public init() {
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.05).cgColor
        
        let height = self.heightAnchor.constraint(equalToConstant: 1)
        height.priority = .defaultHigh
        height.isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateLayer() {
        self.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.05).cgColor
    }
}
