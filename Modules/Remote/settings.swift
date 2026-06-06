//
//  settings.swift
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

internal class Settings: NSStackView, Settings_v {
    private let title: String
    
    public var toggleCallback: (() -> Void) = {}
    
    private let heroView: HeroView = HeroView()
    private var settingsView: NSStackView? = nil
    private var tabView: NSTabView?
    private var segmentedControl: NSSegmentedControl?
    
    private let machinesList: RemoteList = RemoteList()
    private let hostsList: RemoteList = RemoteList()
    
    private var machines: [RemoteMachine]?
    private var hosts: [RemoteHost]?
    private var groups: [RemoteGroup]?
    private var order: RemoteAccountOrder?
    
    public init(_ module: ModuleType) {
        self.title = module.stringValue
        
        super.init(frame: .zero)
        
        self.orientation = .vertical
        self.spacing = Constants.Settings.margin
        
        self.machinesList.toggleCallback = { [weak self] in self?.toggleCallback() }
        self.hostsList.toggleCallback = { [weak self] in self?.toggleCallback() }
        
        let settingsView = self.settings()
        self.settingsView = settingsView
        
        self.addArrangedSubview(self.heroView)
        self.addArrangedSubview(settingsView)
        
        self.heroView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        self.segmentedControl?.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        self.tabView?.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        
        self.render(authorized: SystemStats.shared.isAuthorized)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleRemoteState), name: .remoteState, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .remoteState, object: nil)
    }
    
    @objc private func handleRemoteState(_ notification: Notification) {
        guard let auth = notification.userInfo?["auth"] as? Bool else { return }
        DispatchQueue.main.async { [weak self] in
            self?.render(authorized: auth)
            if auth { self?.load() }
        }
    }
    
    private func render(authorized: Bool) {
        self.heroView.isHidden = authorized
        self.settingsView?.isHidden = !authorized
    }
    
    public func load(widgets: [widget_t]) {
        if SystemStats.shared.isAuthorized {
            self.load()
        }
    }
    
    private func load() {
        self.machines = nil
        self.hosts = nil
        self.groups = nil
        self.order = nil
        
        SystemStats.shared.fetchMachines { [weak self] list in
            self?.machines = list
            self?.tryRender()
        }
        SystemStats.shared.fetchHosts { [weak self] list in
            self?.hosts = list
            self?.tryRender()
        }
        SystemStats.shared.fetchGroups { [weak self] list in
            self?.groups = list
            self?.tryRender()
        }
        SystemStats.shared.fetchAccountOrder { [weak self] order in
            self?.order = order
            self?.tryRender()
        }
    }
    
    private func tryRender() {
        guard let machines = self.machines,
              let hosts = self.hosts,
              let groups = self.groups,
              let order = self.order else { return }
        
        let machineIndex = Dictionary(uniqueKeysWithValues: order.machines.enumerated().map { ($1, $0) })
        let hostIndex = Dictionary(uniqueKeysWithValues: order.hosts.enumerated().map { ($1, $0) })
        
        let sortedMachines = machines.sorted { a, b in
            let ia = machineIndex[a.id] ?? Int.max
            let ib = machineIndex[b.id] ?? Int.max
            if ia != ib { return ia < ib }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        let sortedHosts = hosts.sorted { a, b in
            let ia = hostIndex[a.id] ?? Int.max
            let ib = hostIndex[b.id] ?? Int.max
            if ia != ib { return ia < ib }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        
        let groupById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let orderedGroups = self.depthFirstGroups(groups: groups, groupById: groupById)
        
        self.machinesList.update(machines: sortedMachines, orderedGroups: orderedGroups, groupById: groupById)
        self.hostsList.update(hosts: sortedHosts, orderedGroups: orderedGroups, groupById: groupById)
    }
    
    private func depthFirstGroups(groups: [RemoteGroup], groupById: [String: RemoteGroup]) -> [RemoteGroup] {
        var childrenByParent: [String: [RemoteGroup]] = [:]
        var roots: [RemoteGroup] = []
        for g in groups {
            if let pid = g.parentID, !pid.isEmpty, groupById[pid] != nil {
                childrenByParent[pid, default: []].append(g)
            } else {
                roots.append(g)
            }
        }
        for k in childrenByParent.keys {
            childrenByParent[k]?.sort { ($0.order ?? 0) < ($1.order ?? 0) }
        }
        roots.sort { ($0.order ?? 0) < ($1.order ?? 0) }
        
        var ordered: [RemoteGroup] = []
        var visited: Set<String> = []
        func walk(_ g: RemoteGroup) {
            if visited.contains(g.id) { return }
            visited.insert(g.id)
            ordered.append(g)
            for c in childrenByParent[g.id] ?? [] { walk(c) }
        }
        for r in roots { walk(r) }
        return ordered
    }
    
    private func settings() -> NSStackView {
        let view = NSStackView()
        
        view.orientation = .vertical
        view.spacing = Constants.Settings.margin
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let segmentedControl = NSSegmentedControl(
            labels: [localizedString("Machines"), localizedString("Hosts")],
            trackingMode: .selectOne,
            target: self,
            action: #selector(self.switchTabs)
        )
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.selectSegment(withTag: 0)
        self.segmentedControl = segmentedControl
        
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .noTabsNoBorder
        tabView.tabViewBorderType = .none
        tabView.drawsBackground = false
        self.tabView = tabView
        
        let machinesTab: NSTabViewItem = NSTabViewItem()
        machinesTab.label = localizedString("Machines")
        machinesTab.view = self.machinesList
        tabView.addTabViewItem(machinesTab)
        
        let hostsTab: NSTabViewItem = NSTabViewItem()
        hostsTab.label = localizedString("Hosts")
        hostsTab.view = self.hostsList
        tabView.addTabViewItem(hostsTab)
        
        view.addArrangedSubview(segmentedControl)
        view.addArrangedSubview(tabView)
        
        return view
    }
    
    @objc func switchTabs(sender: NSSegmentedControl) {
        self.tabView?.selectTabViewItem(at: sender.selectedSegment)
    }
}

private class HeroView: NSView {
    private let view: NSStackView = NSStackView()
    
    public init() {
        super.init(frame: .zero)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.orientation = .vertical
        self.view.alignment = .centerX
        self.view.spacing = 14
        self.view.edgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        self.view.translatesAutoresizingMaskIntoConstraints = false
        
        let title = NSTextField(labelWithString: "System Stats")
        title.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        title.alignment = .center
        
        let subtitleText = localizedString("Monitor and control your Macs from anywhere. Sign in to your System Stats account to see all your devices and hosts in one place.")
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let subtitle = NSTextField(wrappingLabelWithString: subtitleText)
        subtitle.attributedStringValue = NSAttributedString(string: subtitleText, attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ])
        subtitle.alignment = .center
        subtitle.maximumNumberOfLines = 0
        subtitle.preferredMaxLayoutWidth = 420
        subtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 460).isActive = true
        
        let bullets = NSStackView()
        bullets.orientation = .vertical
        bullets.alignment = .leading
        bullets.spacing = 8
        let bulletItems: [String] = [
            localizedString("Live CPU, RAM, disk and network metrics"),
            localizedString("Get notified when a device goes offline or hits a threshold"),
            localizedString("Monitor HTTP, ICMP and custom endpoints")
        ]
        for line in bulletItems {
            bullets.addArrangedSubview(self.bulletRow(line))
        }
        
        let loginButton = NSButton(title: localizedString("Login"), target: self, action: #selector(self.loginAction))
        loginButton.bezelStyle = .rounded
        loginButton.keyEquivalent = "\r"
        loginButton.controlSize = .large
        
        self.view.addArrangedSubview(title)
        self.view.addArrangedSubview(subtitle)
        self.view.addArrangedSubview(bullets)
        self.view.addArrangedSubview(loginButton)
        
        self.addSubview(self.view)
        
        NSLayoutConstraint.activate([
            self.view.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.view.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.view.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor),
            self.view.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
            self.view.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor),
            self.view.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bulletRow(_ text: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8

        let check = NSImageView()
        check.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        check.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        check.contentTintColor = .systemGreen

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor

        row.addArrangedSubview(check)
        row.addArrangedSubview(label)

        return row
    }
    
    @objc private func loginAction() {
        SystemStats.shared.login()
    }
}

internal class RemoteList: ScrollableStackView {
    public var toggleCallback: (() -> Void) = {}
    
    private var sections: [PreferencesSection] = []
    
    public init() {
        super.init(frame: .zero)
        
        self.autoresizingMask = [.width, .height]
        
        self.stackView.orientation = .vertical
        self.stackView.alignment = .width
        self.stackView.spacing = Constants.Settings.margin
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func reset() {
        for s in self.sections {
            self.stackView.removeArrangedSubview(s)
            s.removeFromSuperview()
        }
        self.sections.removeAll()
    }
    
    fileprivate func append(_ section: PreferencesSection) {
        self.stackView.addArrangedSubview(section)
        self.sections.append(section)
    }
    
    fileprivate func groupPath(for group: RemoteGroup, in groupById: [String: RemoteGroup]) -> String {
        var parts: [String] = [group.name]
        var current = group
        var seen: Set<String> = [group.id]
        while let pid = current.parentID, !pid.isEmpty, let parent = groupById[pid], !seen.contains(parent.id) {
            parts.insert(parent.name, at: 0)
            seen.insert(parent.id)
            current = parent
        }
        return parts.joined(separator: " › ")
    }
    
    // swiftlint:disable:next function_parameter_count
    fileprivate func row(id: String, storeKey: String, status: Bool?, name: String, url: URL?, subtitle: String) -> NSView {
        let toggle = switchView(action: #selector(self.toggle), state: Store.shared.bool(key: storeKey, defaultValue: true))
        toggle.identifier = NSUserInterfaceItemIdentifier(storeKey)
        
        let dot = DotView(color: self.dotColor(status))
        
        let titleField = TextView()
        titleField.stringValue = name
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        
        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 4
        titleRow.addArrangedSubview(titleField)
        
        if let url {
            titleRow.addArrangedSubview(LinkButton(url))
        }
        
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 0
        textStack.alignment = .leading
        textStack.addArrangedSubview(titleRow)
        
        if !subtitle.isEmpty {
            let subtitleField = TextView()
            subtitleField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            subtitleField.textColor = .secondaryLabelColor
            subtitleField.stringValue = subtitle
            textStack.addArrangedSubview(subtitleField)
            textStack.addArrangedSubview(NSView())
        }
        
        let row = NSStackView(views: [dot, textStack, NSView(), toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: Constants.Settings.margin / 2, left: 0, bottom: (Constants.Settings.margin / 2) - 1, right: 0)
        row.identifier = NSUserInterfaceItemIdentifier(id)
        
        return row
    }
    
    private func dotColor(_ status: Bool?) -> NSColor {
        switch status {
        case .some(true): return .systemGreen
        case .some(false): return .systemRed
        case .none: return .clear
        }
    }
    
    @objc private func toggle(_ sender: NSControl) {
        guard let key = sender.identifier?.rawValue else { return }
        Store.shared.set(key: key, value: controlState(sender))
        self.toggleCallback()
    }
    
    public func update(machines: [RemoteMachine], orderedGroups: [RemoteGroup], groupById: [String: RemoteGroup]) {
        self.reset()
        
        guard !machines.isEmpty else {
            self.append(PreferencesSection(title: localizedString("Machines"), subtitle: localizedString("No machines yet")))
            return
        }
        
        var byGroup: [String: [RemoteMachine]] = [:]
        var ungrouped: [RemoteMachine] = []
        for m in machines {
            if let gid = m.groupID, !gid.isEmpty, groupById[gid] != nil {
                byGroup[gid, default: []].append(m)
            } else {
                ungrouped.append(m)
            }
        }
        
        if !ungrouped.isEmpty {
            let section = PreferencesSection()
            for m in ungrouped {
                section.add(self.row(
                    id: "machine_\(m.id)",
                    storeKey: "\(ModuleType.remote.stringValue)_machine_\(m.id)",
                    status: m.online,
                    name: m.displayName,
                    url: m.uri,
                    subtitle: m.subtitle
                ))
            }
            self.append(section)
        }
        
        for group in orderedGroups {
            let inGroup = byGroup[group.id] ?? []
            if inGroup.isEmpty { continue }
            let section = PreferencesSection(title: self.groupPath(for: group, in: groupById))
            for m in inGroup {
                section.add(self.row(
                    id: "machine_\(m.id)",
                    storeKey: "\(ModuleType.remote.stringValue)_machine_\(m.id)",
                    status: m.online,
                    name: m.displayName,
                    url: m.uri,
                    subtitle: m.subtitle
                ))
            }
            self.append(section)
        }
    }
    
    public func update(hosts: [RemoteHost], orderedGroups: [RemoteGroup], groupById: [String: RemoteGroup]) {
        self.reset()
        
        guard !hosts.isEmpty else {
            self.append(PreferencesSection(title: localizedString("Hosts"), subtitle: localizedString("No hosts yet")))
            return
        }
        
        var byGroup: [String: [RemoteHost]] = [:]
        var ungrouped: [RemoteHost] = []
        for host in hosts {
            if let gid = host.group, !gid.isEmpty, groupById[gid] != nil {
                byGroup[gid, default: []].append(host)
            } else {
                ungrouped.append(host)
            }
        }
        
        if !ungrouped.isEmpty {
            let section = PreferencesSection()
            for host in ungrouped {
                section.add(self.row(
                    id: "host_\(host.id)",
                    storeKey: "\(ModuleType.remote.stringValue)_host_\(host.id)",
                    status: host.status,
                    name: host.displayName,
                    url: host.uri,
                    subtitle: host.subtitle
                ))
            }
            self.append(section)
        }
        
        for group in orderedGroups {
            guard let inGroup = byGroup[group.id], !inGroup.isEmpty else { continue }
            let section = PreferencesSection(title: self.groupPath(for: group, in: groupById))
            for host in inGroup {
                section.add(self.row(
                    id: "host_\(host.id)",
                    storeKey: "\(ModuleType.remote.stringValue)_host_\(host.id)",
                    status: host.status,
                    name: host.displayName,
                    url: host.uri,
                    subtitle: host.subtitle
                ))
            }
            self.append(section)
        }
    }
}
