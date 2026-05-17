//
//  MonitorView.swift
//  Stats
//
//  Unified dark-themed popup: CPU / Memory / Network tabs + always-visible Storage.
//

import Cocoa
import Kit
import CPU
import RAM
import Net

// MARK: - Accent & card colours

private let accentBlue    = NSColor(red: 74/255, green: 158/255, blue: 255/255, alpha: 1)
private let accentOrange  = NSColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1)
private let accentPurple  = NSColor(red: 155/255, green: 89/255, blue: 182/255, alpha: 1)
private let accentTeal    = NSColor(red: 26/255, green: 188/255, blue: 156/255, alpha: 1)
private let cardBG        = NSColor(red: 28/255, green: 28/255, blue: 46/255, alpha: 1)
private let dividerColor  = NSColor.white.withAlphaComponent(0.12)

// MARK: - MonitorView

internal class MonitorView: NSView, Popup_p {
    // Popup_p
    var keyboardShortcut: [UInt16] = []
    var sizeCallback: ((NSSize) -> Void)?

    private let popupWidth: CGFloat = 340
    private let padding: CGFloat    = 12

    // Tab state
    private enum Tab: Int { case cpu = 0, memory = 1, network = 2 }
    private var activeTab: Tab = .memory

    // Sub-views
    private var tabBar:      NSView!
    private var tabButtons:  [NSButton] = []
    private var contentBox:  NSView!
    private var cpuContent:  NSView!
    private var memContent:  NSView!
    private var netContent:  NSView!
    private var storageView: NSView!

    // CPU fields
    private var cpuChart:        LineChartView?
    private var cpuUserField:    NSTextField?
    private var cpuSystemField:  NSTextField?
    private var cpuIdleField:    NSTextField?
    private var cpuCoresField:   NSTextField?

    // Memory fields
    private var memChart:            LineChartView?
    private var memUsedField:        NSTextField?
    private var memWiredField:       NSTextField?
    private var memCompressedField:  NSTextField?
    private var memFreeField:        NSTextField?
    private var memTotalLabel:       NSTextField?
    private var memSearchField:      NSSearchField?
    private var memProcessesView:    ProcessesView?
    private var memProcessFilter:    String = ""
    private var memAllProcesses:     [TopProcess] = []

    // Network fields
    private var netChart:           NetworkChartView?
    private var netDownField:       NSTextField?
    private var netUpField:         NSTextField?
    private var netTotalDownField:  NSTextField?
    private var netTotalUpField:    NSTextField?

    // Storage fields
    private var storageBar:        BarChartView?
    private var storageUsedLabel:  NSTextField?
    private var storageTotalField: NSTextField?
    private var storageUsedField:  NSTextField?
    private var storageFreeField:  NSTextField?
    private var storagePurgeField: NSTextField?

    // Settings overlay
    private var settingsOverlay: NSView?
    private var settingsVisible = false

    // Cached latest values for replay on appear
    private var lastCPU:   CPU_Load?
    private var lastRAM:   RAM_Usage?
    private var lastNet:   Network_Usage?

    // Timer for storage
    private var storageTimer: Timer?

    // MARK: Init

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 0))
        self.wantsLayer = true

        buildUI()
        subscribeNotifications()
        switchTab(activeTab, animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Popup_p

    func settings() -> NSView? { nil }

    func appear() {
        storageTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshStorage()
        }
        storageTimer?.fire()

        if let v = lastCPU   { renderCPU(v) }
        if let v = lastRAM   { renderRAM(v) }
        if let v = lastNet   { renderNet(v) }
    }

    func disappear() {
        storageTimer?.invalidate()
        storageTimer = nil
    }

    func setKeyboardShortcut(_ binding: [UInt16]) {
        keyboardShortcut = binding
        Store.shared.set(key: "MonitorPopup_keyboardShortcut", value: binding)
    }

    // MARK: Notifications

    private func subscribeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(onCPULoad(_:)),  name: .monitorCPULoad,      object: nil)
        nc.addObserver(self, selector: #selector(onRAMUsage(_:)), name: .monitorRAMUsage,     object: nil)
        nc.addObserver(self, selector: #selector(onRAMProcs(_:)), name: .monitorRAMProcesses, object: nil)
        nc.addObserver(self, selector: #selector(onNetUsage(_:)), name: .monitorNetUsage,     object: nil)
    }

    @objc private func onCPULoad(_ n: Notification) {
        guard let v = n.object as? CPU_Load else { return }
        lastCPU = v
        DispatchQueue.main.async { self.renderCPU(v) }
    }

    @objc private func onRAMUsage(_ n: Notification) {
        guard let v = n.object as? RAM_Usage else { return }
        lastRAM = v
        DispatchQueue.main.async { self.renderRAM(v) }
    }

    @objc private func onRAMProcs(_ n: Notification) {
        guard let list = n.object as? [TopProcess] else { return }
        DispatchQueue.main.async {
            self.memAllProcesses = list
            self.renderProcessList()
        }
    }

    @objc private func onNetUsage(_ n: Notification) {
        guard let v = n.object as? Network_Usage else { return }
        lastNet = v
        DispatchQueue.main.async { self.renderNet(v) }
    }

    // MARK: Build UI

    private func buildUI() {
        tabBar      = buildTabBar()
        cpuContent  = buildCPUContent()
        memContent  = buildMemContent()
        netContent  = buildNetContent()
        contentBox  = NSView()
        contentBox.wantsLayer = true

        storageView = buildStorageSection()

        let divider = makeDivider()

        for sub in [tabBar, contentBox, divider, storageView] as [NSView] {
            addSubview(sub)
        }

        layoutSubviews()
    }

    private func layoutSubviews() {
        let w = popupWidth

        // tab bar
        let tabH: CGFloat = 40
        tabBar.frame = NSRect(x: 0, y: 0, width: w, height: tabH) // will be positioned later

        // content
        let contentH = contentHeight(for: activeTab)
        contentBox.frame = NSRect(x: 0, y: 0, width: w, height: contentH)

        // storage
        let storH = storageHeight()
        storageView.frame = NSRect(x: 0, y: 0, width: w, height: storH)

        recalculateLayout()
    }

    private func recalculateLayout() {
        let w = popupWidth
        let tabH: CGFloat    = 40
        let divH: CGFloat    = 1
        let storH: CGFloat   = storageHeight()
        let contentH: CGFloat = contentHeight(for: activeTab)
        let spacing: CGFloat = 8

        var y: CGFloat = 0

        storageView.frame = NSRect(x: 0, y: y, width: w, height: storH)
        y += storH + spacing

        if let div = subviews.first(where: { $0.identifier?.rawValue == "monitor-divider" }) {
            div.frame = NSRect(x: padding, y: y, width: w - padding*2, height: divH)
            y += divH + spacing
        }

        contentBox.frame = NSRect(x: 0, y: y, width: w, height: contentH)
        y += contentH + spacing

        tabBar.frame = NSRect(x: 0, y: y, width: w, height: tabH)
        y += tabH

        let totalH = y
        if frame.size.height != totalH {
            setFrameSize(NSSize(width: w, height: totalH))
            sizeCallback?(frame.size)
        }
    }

    // MARK: Tab bar

    private func buildTabBar() -> NSView {
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: popupWidth, height: 40))
        bar.wantsLayer = true

        let titles = ["cpu", "memorychip", "network"]
        let labels = ["CPU", "Memory", "Network"]
        let tabW: CGFloat = (popupWidth - padding * 2) / 3
        let tabH: CGFloat = 28

        for (i, (sym, lbl)) in zip(titles, labels).enumerated() {
            let btn = NSButton(frame: NSRect(
                x: padding + CGFloat(i) * tabW,
                y: (40 - tabH) / 2,
                width: tabW,
                height: tabH
            ))
            btn.bezelStyle = .regularSquare
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 14
            btn.tag = i

            if let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
                btn.image = img.withSymbolConfiguration(config)
            }
            btn.title = " \(lbl)"
            btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            btn.imagePosition = .imageLeft
            btn.alignment = .center
            btn.target = self
            btn.action = #selector(tabTapped(_:))
            btn.focusRingType = .none
            tabButtons.append(btn)
            bar.addSubview(btn)
        }

        // gear button
        let gearBtn = NSButton(frame: NSRect(x: popupWidth - padding - 24, y: (40-24)/2, width: 24, height: 24))
        gearBtn.bezelStyle = .regularSquare
        gearBtn.isBordered = false
        if let img = NSImage(systemSymbolName: "gear", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            gearBtn.image = img.withSymbolConfiguration(config)
        }
        gearBtn.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        gearBtn.target = self
        gearBtn.action = #selector(openAppSettings)
        gearBtn.focusRingType = .none
        bar.addSubview(gearBtn)

        return bar
    }

    @objc private func tabTapped(_ sender: NSButton) {
        guard let tab = Tab(rawValue: sender.tag) else { return }
        switchTab(tab, animated: true)
    }

    @objc private func openAppSettings() {
        NotificationCenter.default.post(name: .toggleSettings, object: nil)
    }

    private func switchTab(_ tab: Tab, animated: Bool) {
        activeTab = tab

        tabButtons.enumerated().forEach { (i, btn) in
            let active = i == tab.rawValue
            btn.wantsLayer = true
            btn.layer?.backgroundColor = active
                ? accentBlue.withAlphaComponent(0.25).cgColor
                : .clear
            btn.contentTintColor = active ? accentBlue : NSColor.white.withAlphaComponent(0.5)
        }

        contentBox.subviews.forEach { $0.removeFromSuperview() }
        let content: NSView
        switch tab {
        case .cpu:     content = cpuContent
        case .memory:  content = memContent
        case .network: content = netContent
        }
        contentBox.addSubview(content)
        content.frame = contentBox.bounds

        recalculateLayout()

        // After layout, re-fit the content inside contentBox
        content.frame = contentBox.bounds
    }

    // MARK: Divider

    private func makeDivider() -> NSView {
        let v = NSView(frame: .zero)
        v.wantsLayer = true
        v.layer?.backgroundColor = dividerColor.cgColor
        v.identifier = NSUserInterfaceItemIdentifier("monitor-divider")
        return v
    }

    // MARK: CPU Content

    private func buildCPUContent() -> NSView {
        let w = popupWidth - padding * 2
        var y: CGFloat = 0

        let stack = NSView()
        stack.wantsLayer = true

        // Chart card
        let chartCard = makeCard(width: w, height: 90)
        let chart = LineChartView(frame: NSRect(x: 0, y: 0, width: w, height: 90), num: 60, scale: .none, fixedScale: 1)
        chart.setColor(accentBlue)
        chartCard.addSubview(chart)
        self.cpuChart = chart
        chartCard.frame.origin = NSPoint(x: padding, y: y)
        stack.addSubview(chartCard)
        y += 90 + 8

        // Stats card
        let statsCard = makeCard(width: w, height: 60)
        let fields = buildStatsGrid(in: statsCard,
            labels: ["User", "System", "Idle", "Cores"],
            values: ["—", "—", "—", "—"]
        )
        cpuUserField   = fields[0]
        cpuSystemField = fields[1]
        cpuIdleField   = fields[2]
        cpuCoresField  = fields[3]
        statsCard.frame.origin = NSPoint(x: padding, y: y)
        stack.addSubview(statsCard)
        y += 60 + 8

        stack.frame = NSRect(x: 0, y: 0, width: popupWidth, height: y)
        return stack
    }

    // MARK: Memory Content

    private func buildMemContent() -> NSView {
        let w = popupWidth - padding * 2
        var y: CGFloat = 0

        let stack = NSView()
        stack.wantsLayer = true

        // "Total RAM" badge will be shown in stats row

        // Chart card
        let chartCard = makeCard(width: w, height: 90)
        let chart = LineChartView(frame: NSRect(x: 0, y: 0, width: w, height: 90), num: 60, scale: .none, fixedScale: 1)
        chart.setColor(accentBlue)
        chartCard.addSubview(chart)
        self.memChart = chart
        chartCard.frame.origin = NSPoint(x: padding, y: y)
        stack.addSubview(chartCard)
        y += 90 + 8

        // Stats card with total label
        let statsCard = makeCard(width: w, height: 68)
        let totalLbl = makeLabel("", size: 10, color: NSColor.white.withAlphaComponent(0.4))
        totalLbl.frame = NSRect(x: w - 80, y: statsCard.frame.height - 18, width: 76, height: 14)
        totalLbl.alignment = .right
        statsCard.addSubview(totalLbl)
        self.memTotalLabel = totalLbl

        let fields = buildStatsGrid(in: statsCard,
            labels: ["Used", "Wired", "Compressed", "Free"],
            values: ["—", "—", "—", "—"]
        )
        memUsedField       = fields[0]
        memWiredField      = fields[1]
        memCompressedField = fields[2]
        memFreeField       = fields[3]
        statsCard.frame.origin = NSPoint(x: padding, y: y)
        stack.addSubview(statsCard)
        y += 68 + 8

        // Process list header row
        let procHeader = NSView(frame: NSRect(x: padding, y: y, width: w, height: 22))
        let procLabel = makeLabel("Top Processes", size: 11, color: NSColor.white.withAlphaComponent(0.6))
        procLabel.frame = NSRect(x: 0, y: 0, width: 120, height: 22)
        procLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let searchField = NSSearchField(frame: NSRect(x: 124, y: 1, width: w - 124, height: 20))
        searchField.placeholderString = "Filter…"
        searchField.font = NSFont.systemFont(ofSize: 11)
        searchField.controlSize = .small
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        (searchField.cell as? NSSearchFieldCell)?.searchButtonCell?.isBordered = false
        self.memSearchField = searchField
        procHeader.addSubview(procLabel)
        procHeader.addSubview(searchField)
        stack.addSubview(procHeader)
        y += 24

        // Process rows
        let procView = ProcessesView(
            frame: NSRect(x: padding, y: y, width: w, height: CGFloat(6) * 22),
            values: [("Memory", nil)],
            n: 6
        )
        self.memProcessesView = procView
        stack.addSubview(procView)
        y += CGFloat(6) * 22 + 8

        stack.frame = NSRect(x: 0, y: 0, width: popupWidth, height: y)
        return stack
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        memProcessFilter = sender.stringValue.lowercased()
        renderProcessList()
    }

    private func renderProcessList() {
        let filtered: [TopProcess]
        if memProcessFilter.isEmpty {
            filtered = Array(memAllProcesses.prefix(6))
        } else {
            filtered = Array(memAllProcesses
                .filter { $0.name.lowercased().contains(memProcessFilter) }
                .prefix(6))
        }
        memProcessesView?.clear()
        for (i, proc) in filtered.enumerated() {
            let mem = Units(bytes: Int64(proc.usage)).getReadableMemory(style: .memory)
            memProcessesView?.set(i, proc, [mem])
        }
    }

    // MARK: Network Content

    private func buildNetContent() -> NSView {
        let w = popupWidth - padding * 2
        var y: CGFloat = 0

        let stack = NSView()
        stack.wantsLayer = true

        // Chart card
        let chartCard = makeCard(width: w, height: 70)
        let chart = NetworkChartView(
            frame: NSRect(x: 0, y: 0, width: w, height: 70),
            num: 60,
            reversedOrder: false,
            outColor: accentOrange,
            inColor: accentBlue
        )
        chartCard.addSubview(chart)
        self.netChart = chart
        chartCard.frame.origin = NSPoint(x: padding, y: y)
        stack.addSubview(chartCard)
        y += 70 + 6

        // Legend row
        let legend = buildNetworkLegend(y: y, width: w)
        stack.addSubview(legend)
        y += 20 + 6

        // Stats card
        let statsCard = makeCard(width: w, height: 68)
        let fields = buildStatsGrid(in: statsCard,
            labels: ["Download", "Upload", "Total Down", "Total Up"],
            values: ["—", "—", "—", "—"]
        )
        netDownField      = fields[0]
        netUpField        = fields[1]
        netTotalDownField = fields[2]
        netTotalUpField   = fields[3]
        statsCard.frame.origin = NSPoint(x: padding, y: y)
        stack.addSubview(statsCard)
        y += 68 + 8

        stack.frame = NSRect(x: 0, y: 0, width: popupWidth, height: y)
        return stack
    }

    private func buildNetworkLegend(y: CGFloat, width: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: padding, y: y, width: width, height: 20))
        let dot1 = makeDot(color: accentOrange, frame: NSRect(x: 0, y: 4, width: 10, height: 10))
        let lbl1 = makeLabel("↑ Upload", size: 11, color: NSColor.white.withAlphaComponent(0.6))
        lbl1.frame = NSRect(x: 14, y: 0, width: 80, height: 20)
        let dot2 = makeDot(color: accentBlue, frame: NSRect(x: 100, y: 4, width: 10, height: 10))
        let lbl2 = makeLabel("↓ Download", size: 11, color: NSColor.white.withAlphaComponent(0.6))
        lbl2.frame = NSRect(x: 114, y: 0, width: 90, height: 20)
        view.addSubview(dot1); view.addSubview(lbl1)
        view.addSubview(dot2); view.addSubview(lbl2)
        return view
    }

    // MARK: Storage Section

    private func buildStorageSection() -> NSView {
        let w = popupWidth - padding * 2
        var y: CGFloat = 0

        let container = NSView()
        container.wantsLayer = true

        // Section title
        let title = makeLabel("Storage", size: 12, color: NSColor.white.withAlphaComponent(0.6))
        title.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        title.frame = NSRect(x: padding, y: y, width: w, height: 18)
        container.addSubview(title)
        y += 18 + 6

        // Used/Total label
        let usedLbl = makeLabel("— / —", size: 11, color: NSColor.white.withAlphaComponent(0.5))
        usedLbl.frame = NSRect(x: padding, y: y, width: w, height: 15)
        container.addSubview(usedLbl)
        self.storageUsedLabel = usedLbl
        y += 15 + 4

        // Segmented bar card
        let barCard = makeCard(width: w, height: 22)
        let bar = BarChartView(frame: NSRect(x: 4, y: 3, width: w - 8, height: 16), horizontal: true)
        bar.widthAnchor.constraint(equalToConstant: w - 8).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 16).isActive = true
        barCard.addSubview(bar)
        barCard.frame.origin = NSPoint(x: padding, y: y)
        container.addSubview(barCard)
        self.storageBar = bar
        y += 22 + 8

        // Stats card
        let statsCard = makeCard(width: w, height: 60)
        let fields = buildStatsGrid(in: statsCard,
            labels: ["Total", "Used", "Free", "Purgeable"],
            values: ["—", "—", "—", "—"]
        )
        storageTotalField = fields[0]
        storageUsedField  = fields[1]
        storageFreeField  = fields[2]
        storagePurgeField = fields[3]
        statsCard.frame.origin = NSPoint(x: padding, y: y)
        container.addSubview(statsCard)
        y += 60 + padding

        container.frame = NSRect(x: 0, y: 0, width: popupWidth, height: y)
        return container
    }

    // MARK: Storage refresh

    private func refreshStorage() {
        DispatchQueue.global(qos: .background).async {
            let fm = FileManager.default
            guard let attrs = try? fm.attributesOfFileSystem(forPath: "/"),
                  let total = attrs[.systemSize] as? Int64,
                  let free  = attrs[.systemFreeSize] as? Int64 else { return }
            let used  = total - free

            var purgeable: Int64 = 0
            if let purgeAttrs = try? fm.attributesOfFileSystem(forPath: "/"),
               let purge = purgeAttrs[.init("NSFileSystemFreeNodes")] as? Int64 {
                purgeable = purge * 4096
            }

            DispatchQueue.main.async { [weak self] in
                self?.updateStorageUI(total: total, used: used, free: free, purgeable: purgeable)
            }
        }
    }

    private func updateStorageUI(total: Int64, used: Int64, free: Int64, purgeable: Int64) {
        let totalStr = DiskSize(total).getReadableMemory()
        let usedStr  = DiskSize(used).getReadableMemory()
        let freeStr  = DiskSize(free).getReadableMemory()
        let purgeStr = purgeable > 0 ? DiskSize(purgeable).getReadableMemory() : "—"

        storageUsedLabel?.stringValue = "\(usedStr) used / \(totalStr) total"
        storageTotalField?.stringValue = totalStr
        storageUsedField?.stringValue  = usedStr
        storageFreeField?.stringValue  = freeStr
        storagePurgeField?.stringValue = purgeStr

        if total > 0 {
            storageBar?.setValue(ColorValue(Double(used) / Double(total), color: accentBlue))
        }
    }

    // MARK: Render helpers

    private func renderCPU(_ v: CPU_Load) {
        cpuChart?.addValue(v.totalUsage)
        cpuChart?.display()
        cpuUserField?.stringValue   = "\(pct(v.userLoad))%"
        cpuSystemField?.stringValue = "\(pct(v.systemLoad))%"
        cpuIdleField?.stringValue   = "\(pct(v.idleLoad))%"
        cpuCoresField?.stringValue  = "\(SystemKit.shared.device.info.cpu?.logicalCores ?? 0)"
    }

    private func renderRAM(_ v: RAM_Usage) {
        memChart?.addValue(v.usage)
        memChart?.display()
        memUsedField?.stringValue       = Units(bytes: Int64(v.used)).getReadableMemory(style: .memory)
        memWiredField?.stringValue      = Units(bytes: Int64(v.wired)).getReadableMemory(style: .memory)
        memCompressedField?.stringValue = Units(bytes: Int64(v.compressed)).getReadableMemory(style: .memory)
        memFreeField?.stringValue       = Units(bytes: Int64(v.free)).getReadableMemory(style: .memory)
        let totalGB = Int(v.total / 1_073_741_824)
        memTotalLabel?.stringValue = totalGB > 0 ? "\(totalGB) GB total" : ""
    }

    private func renderNet(_ v: Network_Usage) {
        netChart?.addValue(upload: Double(v.bandwidth.upload), download: Double(v.bandwidth.download))
        netDownField?.stringValue      = Units(bytes: v.bandwidth.download).getReadableSpeed()
        netUpField?.stringValue        = Units(bytes: v.bandwidth.upload).getReadableSpeed()
        netTotalDownField?.stringValue = Units(bytes: v.total.download).getReadableMemory()
        netTotalUpField?.stringValue   = Units(bytes: v.total.upload).getReadableMemory()
    }

    // MARK: Heights

    private func contentHeight(for tab: Tab) -> CGFloat {
        switch tab {
        case .cpu:
            return cpuContent.frame.height
        case .memory:
            return memContent.frame.height
        case .network:
            return netContent.frame.height
        }
    }

    private func storageHeight() -> CGFloat {
        storageView?.frame.height ?? 160
    }

    // MARK: Shared UI factories

    private func makeCard(width: CGFloat, height: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        v.wantsLayer = true
        v.layer?.backgroundColor = cardBG.cgColor
        v.layer?.cornerRadius = 8
        return v
    }

    private func makeLabel(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let f = NSTextField()
        f.stringValue = text
        f.font = NSFont.systemFont(ofSize: size)
        f.textColor = color
        f.isEditable = false
        f.isSelectable = false
        f.isBezeled = false
        f.drawsBackground = false
        f.backgroundColor = .clear
        return f
    }

    private func makeDot(color: NSColor, frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        v.layer?.cornerRadius = frame.width / 2
        return v
    }

    /// Builds a 2-column × 2-row stats grid inside the card. Returns value fields in order.
    private func buildStatsGrid(in card: NSView, labels: [String], values: [String]) -> [NSTextField] {
        let colW: CGFloat = card.frame.width / 2
        let rowH: CGFloat = 26
        let topPad: CGFloat = (card.frame.height - 2 * rowH) / 2
        var fields: [NSTextField] = []

        for (i, (lbl, val)) in zip(labels, values).enumerated() {
            let col = i % 2
            let row = i / 2
            let x = CGFloat(col) * colW + 10
            let y = card.frame.height - topPad - CGFloat(row + 1) * rowH

            let labelView = makeLabel(lbl, size: 10, color: NSColor.white.withAlphaComponent(0.4))
            labelView.frame = NSRect(x: x, y: y + 13, width: colW - 12, height: 13)

            let valueView = makeLabel(val, size: 13, color: .white)
            valueView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            valueView.frame = NSRect(x: x, y: y, width: colW - 12, height: 14)

            card.addSubview(labelView)
            card.addSubview(valueView)
            fields.append(valueView)
        }

        return fields
    }

    // MARK: Percent helper

    private func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }
}
