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

internal enum RemoteItem {
    case machine(RemoteMachine)
    case host(RemoteHost)
    
    var id: String {
        switch self {
        case .machine(let m): return "machine-\(m.id)"
        case .host(let h): return "host-\(h.id)"
        }
    }
    
    var name: String {
        switch self {
        case .machine(let m): return m.displayName
        case .host(let h): return h.displayName
        }
    }
    
    var url: URL? {
        switch self {
        case .machine(let m): return m.uri
        case .host(let h): return h.uri
        }
    }
    
    var status: Bool {
        switch self {
        case .machine(let m): return m.online
        case .host(let h): return h.lastStatus?.lowercased() == "up"
        }
    }
}

internal class Popup: PopupWrapper {
    internal var loadCallback: (() -> Void)?
    private var checkedAt: [String: String] = [:]
    private var metrics: [String: RemotePreview] = [:]
    private var hostHistory: [String: GridChartData] = [:]
    private var loginPrompt: EmptyView? = nil
    
    private var groups: NSStackView = {
        let view = NSStackView()
        view.spacing = Constants.Popup.spacing*2
        view.orientation = .vertical
        return view
    }()
    
    private var authorized: Bool = SystemStats.shared.isAuthorized
    private var snapshot: RemoteSnapshot?
    private var visible: Bool = false
    private var streams: [[String]: RemoteMachineStream] = [:]
    private var currentMachineIDs: [String] = []
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        self.setClippingResistancePriority(.defaultLow, for: .vertical)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func recalculateHeight() {
        let h = self.fittingSize.height
        if h > 0 && self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    public override func loadContent() {
        self.loginPrompt = EmptyView(height: 60, msg: localizedString("Login to System Stats to see your devices"))
        self.authorizationStatus(self.authorized)
        if let snapshot = self.snapshot {
            self.render(snapshot)
        }
    }
    
    public override func unloadContent() {
        self.loginPrompt = nil
        self.groups.subviews.forEach { $0.removeFromSuperview() }
    }
    
    public func authorizationStatus(_ status: Bool) {
        self.authorized = status
        if !status {
            self.stopStreams()
            self.snapshot = nil
            self.currentMachineIDs = []
            self.metrics.removeAll()
            self.hostHistory.removeAll()
            self.checkedAt.removeAll()
            self.groups.subviews.forEach { $0.removeFromSuperview() }
        }
        guard self.contentLoaded else { return }
        if !status {
            if let loginPrompt = self.loginPrompt {
                self.addArrangedSubview(loginPrompt)
            }
            self.groups.removeFromSuperview()
        } else {
            self.loginPrompt?.removeFromSuperview()
            self.addArrangedSubview(self.groups)
            if self.visible { self.loadCallback?() }
            self.syncStreams()
        }
        self.recalculateHeight()
    }
    
    public override func appear() {
        super.appear()
        guard !self.visible else { return }
        self.visible = true
        self.loadCallback?()
        self.syncStreams()
    }
    
    public override func disappear() {
        super.disappear()
        self.visible = false
        self.stopStreams()
    }
    
    private func syncStreams() {
        guard self.visible, self.authorized else { return }
        let ids = self.currentMachineIDs
        let limit = RemoteMachineStream.maxMachines
        let batches = stride(from: 0, to: ids.count, by: limit).map { start in
            Array(ids[start..<min(start + limit, ids.count)])
        }
        for (batch, stream) in self.streams where !batches.contains(batch) {
            stream.stop()
            self.streams.removeValue(forKey: batch)
        }
        
        for batch in batches where self.streams[batch] == nil {
            let stream = RemoteMachineStream(machineIDs: batch) { [weak self] id, preview, snapshot in
                self?.apply(preview, for: id, snapshot: snapshot)
            }
            self.streams[batch] = stream
            stream.start()
        }
    }
    
    private func stopStreams() {
        self.streams.values.forEach { $0.stop() }
        self.streams.removeAll()
    }
    
    private func apply(_ preview: RemotePreview, for id: String, snapshot: Bool) {
        let previous = snapshot ? nil : self.metrics[id]
        let merged = RemotePreview(cpu: preview.cpu ?? previous?.cpu, ram: preview.ram ?? previous?.ram)
        self.metrics[id] = merged
        for group in self.groups.arrangedSubviews.compactMap({ $0 as? GroupView }) {
            if let row = group.machineRow(id) {
                row.updateMetrics(merged)
                break
            }
        }
    }
    
    internal func callback(_ snapshot: RemoteSnapshot) {
        self.snapshot = snapshot
        let machineIDs = Set(snapshot.machines.map { $0.id })
        self.metrics = self.metrics.filter { machineIDs.contains($0.key) }
        let ids = Set(snapshot.hosts.map { $0.id })
        self.hostHistory = self.hostHistory.filter { ids.contains($0.key) }
        self.checkedAt = self.checkedAt.filter { ids.contains($0.key) }
        snapshot.hosts.forEach { host in
            let history = self.hostHistory[host.id] ?? GridChartData(capacity: 24)
            self.hostHistory[host.id] = history
            guard let ts = host.checkTimestamp, self.checkedAt[host.id] != ts else { return }
            self.checkedAt[host.id] = ts
            history.append(host.lastStatus?.lowercased() == "up")
        }
        guard self.contentLoaded else { return }
        self.render(snapshot)
    }
    
    private func render(_ snapshot: RemoteSnapshot) {
        let enabledMachines = snapshot.machines.filter { $0.state }
        let enabledHosts = snapshot.hosts.filter { $0.state }
        
        let groupById = Dictionary(snapshot.groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sortedMachines = enabledMachines.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        let sortedHosts = enabledHosts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        
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
            if let gid = h.displayGroupID, !gid.isEmpty, groupById[gid] != nil {
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
                view.update(title: sector.title, machines: sector.machines, hosts: sector.hosts, history: self.hostHistory, metrics: self.metrics)
            } else {
                let view = GroupView(id: sector.id, title: sector.title)
                view.sizeCallback = { [weak self] in self?.recalculateHeight() }
                view.update(title: sector.title, machines: sector.machines, hosts: sector.hosts, history: self.hostHistory, metrics: self.metrics)
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
        
        self.currentMachineIDs = enabledMachines.map { $0.id }.sorted()
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
            header.edgeInsets = NSEdgeInsets(top: 12, left: Constants.Popup.margins, bottom: 12, right: Constants.Popup.margins)
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
        }
        
        self.addArrangedSubview(self.body)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (self.isDarkMode ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25) : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)).cgColor
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
    
    public func update(title: String?, machines: [RemoteMachine], hosts: [RemoteHost], history: [String: GridChartData], metrics: [String: RemotePreview]) {
        if let titleLabel, let title { titleLabel.stringValue = title }
        self.statusDot.setColor(self.aggregateColor(machines: machines, hosts: hosts))
        
        let items: [RemoteItem] = machines.map { .machine($0) } + hosts.map { .host($0) }
        let ids = Set(items.map { $0.id })
        
        self.body.subviews.compactMap { $0 as? RemoteItemView }.filter { !ids.contains($0.id) }.forEach { $0.removeFromSuperview() }
        
        items.enumerated().forEach { (index, item) in
            let view: RemoteItemView
            if let existing = self.body.subviews.compactMap({ $0 as? RemoteItemView }).first(where: { $0.id == item.id }) {
                view = existing
            } else {
                if case .host(let host) = item {
                    view = RemoteItemView(item, history: history[host.id])
                } else {
                    view = RemoteItemView(item)
                }
                self.body.addArrangedSubview(view)
            }
            view.update(item, metrics: metrics)
            self.body.removeArrangedSubview(view)
            self.body.insertArrangedSubview(view, at: index)
            view.setLast(index == items.count - 1)
        }
    }
    
    fileprivate func machineRow(_ id: String) -> RemoteItemView? {
        self.body.arrangedSubviews.compactMap { $0 as? RemoteItemView }.first { $0.id == "machine-" + id }
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

private class RemoteItemView: NSStackView {
    public let id: String
    
    private let dot = DotView(color: .tertiaryLabelColor)
    private var labelField: LabelField = LabelField()
    
    private let cpuLabel = TextView()
    private let cpuBar = BarChartView(horizontal: true)
    private let ramLabel = TextView()
    private let ramBar = BarChartView(horizontal: true)
    
    private let grid: GridChartView
    
    private let separator = RemoteSeparator()
    private var heightConstraint: NSLayoutConstraint?
    
    public init(_ item: RemoteItem, history: GridChartData? = nil) {
        self.grid = GridChartView(grid: (24, 1), history: history)
        self.id = item.id
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 53))
        let height = self.heightAnchor.constraint(equalToConstant: 53)
        height.priority = NSLayoutConstraint.Priority(999)
        height.isActive = true
        self.heightConstraint = height
        self.setContentHuggingPriority(.required, for: .vertical)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        self.edgeInsets = NSEdgeInsets(top: Constants.Popup.margins, left: Constants.Popup.margins, bottom: 0, right: Constants.Popup.margins)
        
        let header: NSStackView = {
            let view: NSStackView = NSStackView()
            view.orientation = .horizontal
            view.spacing = 4
            
            self.dot.setColor(item.status ? .systemGreen : .systemRed)
            self.labelField.stringValue = item.name
            
            view.addArrangedSubview(self.dot)
            view.addArrangedSubview(self.labelField)
            view.addArrangedSubview(NSView())
            
            if let url = item.url {
                view.addArrangedSubview(LinkButton(url, size: 10))
            }
            
            return view
        }()
        
        let stats: NSView
        switch item {
        case .machine: stats = self.machineStats()
        case .host:    stats = self.hostStats()
        }
        
        self.addArrangedSubview(header)
        self.addArrangedSubview(stats)
        self.addArrangedSubview(self.separator)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func machineStats() -> NSView {
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
    }
    
    private func hostStats() -> NSView {
        let view: NSStackView = NSStackView()
        view.spacing = Constants.Popup.margins
        view.orientation = .horizontal
        view.alignment = .centerY
        view.distribution = .fillEqually
        view.translatesAutoresizingMaskIntoConstraints = false
        view.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        
        self.grid.heightAnchor.constraint(equalToConstant: 9).isActive = true
        
        view.addArrangedSubview(self.grid)
        
        return view
    }
    
    public func update(_ item: RemoteItem, metrics: [String: RemotePreview]) {
        self.grid.historyUpdated()
        self.labelField.stringValue = item.name
        
        switch item {
        case .machine(let machine):
            self.dot.setColor(machine.online ? .systemGreen : .systemRed)
            if let preview = metrics[machine.id] {
                self.updateMetrics(preview)
                return
            }
            
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
        case .host(let host):
            self.dot.setColor(host.color)
        }
    }
    
    fileprivate func updateMetrics(_ preview: RemotePreview) {
        self.cpuLabel.stringValue = preview.cpu ?? "—"
        self.ramLabel.stringValue = preview.ram ?? "—"
        self.cpuBar.setValue(ColorValue((Double(preview.cpu?.dropLast() ?? "") ?? 0) / 100))
        self.ramBar.setValue(ColorValue((Double(preview.ram?.dropLast() ?? "") ?? 0) / 100))
    }
    
    public func setLast(_ isLast: Bool) {
        self.separator.isHidden = isLast
        self.heightConstraint?.constant = 53 + (isLast ? 0 : 1)
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
