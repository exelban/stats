//
//  MonitorView.swift
//  Stats
//
//  Unified dark popup: CPU / Memory / Network / Storage tabs.
//

import Cocoa
import Kit
import CPU
import RAM
import Net
import Battery
import Sensors

// MARK: - Design tokens

private let bgColor      = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.09, alpha: 1)
private let cardBG       = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.16, alpha: 1)
private let cardBorder   = NSColor.white.withAlphaComponent(0.09)
private let accentBlue   = NSColor(red: 74/255,  green: 158/255, blue: 255/255, alpha: 1)
private let accentOrange = NSColor(red: 255/255, green: 149/255, blue: 0/255,   alpha: 1)
private let mutedText    = NSColor.white.withAlphaComponent(0.38)
private let bodyText     = NSColor.white
private let rowSep       = NSColor.white.withAlphaComponent(0.07)

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - MonitorView

internal class MonitorView: NSView, Popup_p {

    override var isFlipped: Bool { true }

    var keyboardShortcut: [UInt16] = []
    var sizeCallback: ((NSSize) -> Void)?

    private let W: CGFloat   = 360
    private let pad: CGFloat = 12
    private let gap: CGFloat = 8
    private let tabH: CGFloat = 44

    private enum Tab: Int { case cpu = 0, memory = 1, network = 2, storage = 3, battery = 4, fans = 5 }
    private var activeTab: Tab = .memory

    // UI structure
    private var tabBar:     NSView!
    private var tabPill:    NSView!
    private var tabBtns:    [NSButton] = []
    private var contentBox: FlippedView!

    // Per-tab content (built once, swapped in/out)
    private var cpuContent:  NSView!
    private var memContent:  NSView!
    private var netContent:  NSView!
    private var storContent: NSView!
    private var batContent:  NSView!
    private var senContent:  NSView!

    // CPU outlets
    private var cpuChart: LineChartView?
    private var cpuUserF, cpuSysF, cpuIdleF, cpuCoresF: NSTextField?
    private var cpuSearch:  NSSearchField?
    private var cpuProcBox: FlippedView?
    private var cpuTempBox: FlippedView?
    private var cpuTempBaseY: CGFloat = 0
    private var cpuProcs:   [TopProcess] = []
    private var cpuFilter:  String = ""

    // Memory outlets
    private var memChart:   LineChartView?
    private var memTotal:   Double = 0
    private var memYLabels: [NSTextField] = []
    private var memSearch:  NSSearchField?
    private var memProcBox: FlippedView?
    private var memProcs:   [TopProcess] = []
    private var memFilter:  String = ""

    // Network outlets
    private var netChart: NetworkChartView?
    private var netDownF, netUpF, netTotDownF, netTotUpF: NSTextField?

    // Storage outlets
    private var storBar:   BarChartView?
    private var storTotF, storUsedF, storFreeF, storPurgeF: NSTextField?
    private var storTimer: Timer?

    // Battery outlets
    private var batBar:   BarChartView?
    private var batLevelF, batSourceF, batHealthF, batCyclesF: NSTextField?
    private var batTimeF, batTempF, batVoltF, batWattsF: NSTextField?

    // Cached latest values
    private var lastCPU: CPU_Load?
    private var lastRAM: RAM_Usage?
    private var lastNet: Network_Usage?
    private var lastBat: Battery_Usage?
    private var lastSensors: [Sensor_p] = []

    // MARK: Init

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 100))
        wantsLayer = true
        layer?.backgroundColor = bgColor.cgColor

        buildUI()
        subscribeNotifications()
        switchTab(activeTab)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: Popup_p

    func settings() -> NSView? { nil }

    func appear() {
        storTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshStorage()
        }
        storTimer?.fire()
        if let v = lastCPU { renderCPU(v) }
        if let v = lastRAM { renderRAM(v) }
        if let v = lastNet { renderNet(v) }
        if let v = lastBat { renderBattery(v) }
        renderCPUTemps(lastSensors)
    }

    func disappear() {
        storTimer?.invalidate()
        storTimer = nil
    }

    func setKeyboardShortcut(_ b: [UInt16]) {
        keyboardShortcut = b
        Store.shared.set(key: "MonitorPopup_keyboardShortcut", value: b)
    }

    // MARK: Notifications

    private func subscribeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(onCPU),      name: .monitorCPULoad,       object: nil)
        nc.addObserver(self, selector: #selector(onCPUProcs), name: .monitorCPUProcesses,  object: nil)
        nc.addObserver(self, selector: #selector(onRAM),      name: .monitorRAMUsage,      object: nil)
        nc.addObserver(self, selector: #selector(onRAMProcs), name: .monitorRAMProcesses,  object: nil)
        nc.addObserver(self, selector: #selector(onNet),      name: .monitorNetUsage,      object: nil)
        nc.addObserver(self, selector: #selector(onBat),      name: .monitorBatteryUsage,  object: nil)
        nc.addObserver(self, selector: #selector(onSensors),  name: .monitorSensorsData,   object: nil)
    }

    @objc private func onCPU(_ n: Notification) {
        guard let v = n.object as? CPU_Load else { return }
        lastCPU = v
        DispatchQueue.main.async { self.renderCPU(v) }
    }

    @objc private func onCPUProcs(_ n: Notification) {
        guard let list = n.object as? [TopProcess] else { return }
        DispatchQueue.main.async {
            self.cpuProcs = list
            self.refreshCPUProcList()
        }
    }

    @objc private func onRAM(_ n: Notification) {
        guard let v = n.object as? RAM_Usage else { return }
        lastRAM = v
        DispatchQueue.main.async { self.renderRAM(v) }
    }

    @objc private func onRAMProcs(_ n: Notification) {
        guard let list = n.object as? [TopProcess] else { return }
        DispatchQueue.main.async {
            self.memProcs = list
            self.refreshProcList()
        }
    }

    @objc private func onNet(_ n: Notification) {
        guard let v = n.object as? Network_Usage else { return }
        lastNet = v
        DispatchQueue.main.async { self.renderNet(v) }
    }

    @objc private func onBat(_ n: Notification) {
        guard let v = n.object as? Battery_Usage else { return }
        lastBat = v
        DispatchQueue.main.async { self.renderBattery(v) }
    }

    @objc private func onSensors(_ n: Notification) {
        guard let list = n.object as? Sensors_List else { return }
        let sensors = list.sensors
        lastSensors = sensors
        DispatchQueue.main.async {
            if self.activeTab == .fans { self.renderSensors(sensors) }
            if self.activeTab == .cpu  { self.renderCPUTemps(sensors) }
        }
    }

    // MARK: Build UI

    private func buildUI() {
        tabBar     = buildTabBar()
        contentBox = FlippedView()
        contentBox.wantsLayer = true

        cpuContent  = buildCPUContent()
        memContent  = buildMemContent()
        netContent  = buildNetContent()
        storContent = buildStorContent()
        batContent  = buildBatContent()
        senContent  = buildSensorsContent()

        let tabSep = NSView(frame: NSRect(x: 16, y: tabH - 1, width: W - 32, height: 0.5))
        tabSep.wantsLayer = true
        tabSep.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor

        addSubview(tabBar)
        addSubview(tabSep)
        addSubview(contentBox)
    }

    // MARK: Tab bar — pill style, text only

    private func buildTabBar() -> NSView {
        let bar = FlippedView(frame: NSRect(x: 0, y: 0, width: W, height: tabH))
        bar.wantsLayer = true

        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor.white.cgColor
        pill.layer?.cornerRadius = 14
        self.tabPill = pill
        bar.addSubview(pill)

        let titles = ["CPU", "Memory", "Network", "Storage", "Battery", "Fans"]
        let tabW = W / CGFloat(titles.count)
        for (i, title) in titles.enumerated() {
            let btn = NSButton(frame: NSRect(x: CGFloat(i) * tabW, y: 6, width: tabW, height: 32))
            btn.bezelStyle    = .regularSquare
            btn.isBordered    = false
            btn.wantsLayer    = true
            btn.title         = title
            btn.font          = NSFont.systemFont(ofSize: 11, weight: .medium)
            btn.alignment     = .center
            btn.tag           = i
            btn.target        = self
            btn.action        = #selector(tabTapped(_:))
            btn.focusRingType = .none
            btn.contentTintColor = mutedText
            tabBtns.append(btn)
            bar.addSubview(btn)
        }
        return bar
    }

    @objc private func tabTapped(_ s: NSButton) {
        guard let tab = Tab(rawValue: s.tag) else { return }
        switchTab(tab)
    }

    private func switchTab(_ tab: Tab) {
        activeTab = tab

        let tabW = W / CGFloat(tabBtns.count)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.allowsImplicitAnimation = true
            tabPill.frame = NSRect(
                x: CGFloat(tab.rawValue) * tabW + 4,
                y: 8, width: tabW - 8, height: 28
            )
        }
        tabBtns.enumerated().forEach { i, b in
            b.contentTintColor = i == tab.rawValue ? .black : mutedText
        }

        contentBox.subviews.forEach { $0.removeFromSuperview() }
        let content: NSView
        switch tab {
        case .cpu:     content = cpuContent; renderCPUTemps(lastSensors)
        case .memory:  content = memContent
        case .network: content = netContent
        case .storage: content = storContent
        case .battery: content = batContent
        case .fans:    content = senContent; renderSensors(lastSensors)
        }
        contentBox.addSubview(content)
        recalculate()
        content.frame = contentBox.bounds
    }

    private func recalculate() {
        let contentH: CGFloat
        switch activeTab {
        case .cpu:     contentH = cpuContent.frame.height
        case .memory:  contentH = memContent.frame.height
        case .network: contentH = netContent.frame.height
        case .storage: contentH = storContent.frame.height
        case .battery: contentH = batContent.frame.height
        case .fans:    contentH = senContent.frame.height
        }
        tabBar.frame     = NSRect(x: 0, y: 0,    width: W, height: tabH)
        contentBox.frame = NSRect(x: 0, y: tabH, width: W, height: contentH)

        let total = tabH + contentH
        if frame.height != total {
            setFrameSize(NSSize(width: W, height: total))
            sizeCallback?(frame.size)
        }
    }

    // MARK: CPU content

    private func buildCPUContent() -> NSView {
        let w = W - pad * 2
        var y: CGFloat = gap
        let v = FlippedView()

        let chartH: CGFloat = 130
        let chartCard = card(w: w, h: chartH, at: NSPoint(x: pad, y: y))
        let chart = LineChartView(
            frame: NSRect(x: 0, y: 0, width: w, height: chartH),
            num: 60, scale: .none, fixedScale: 1
        )
        chart.setColor(accentBlue)
        chartCard.addSubview(chart)
        cpuChart = chart
        v.addSubview(chartCard)
        y += chartH + gap

        let statsCard = card(w: w, h: 80, at: NSPoint(x: pad, y: y))
        let fs = statsGrid(in: statsCard,
                           labels: ["User", "System", "Idle", "Cores"],
                           values: ["—", "—", "—", "—"])
        cpuUserF = fs[0]; cpuSysF = fs[1]; cpuIdleF = fs[2]; cpuCoresF = fs[3]
        v.addSubview(statsCard)
        y += 80 + gap

        v.addSubview(sectionHeader("TOP PROCESSES", at: NSPoint(x: pad, y: y)))
        y += 18

        // Search field
        let search = NSSearchField(frame: NSRect(x: pad, y: y, width: w, height: 32))
        search.placeholderString = "Search process"
        search.font = NSFont.systemFont(ofSize: 13)
        search.target = self
        search.action = #selector(cpuSearchChanged(_:))
        cpuSearch = search
        v.addSubview(search)
        y += 32 + gap

        // Process list
        let rows = 8
        let procBox = FlippedView(frame: NSRect(x: pad, y: y, width: w, height: CGFloat(rows) * 44))
        cpuProcBox = procBox
        v.addSubview(procBox)
        y += CGFloat(rows) * 44 + gap

        v.addSubview(sectionHeader("CPU TEMPERATURES", at: NSPoint(x: pad, y: y)))
        y += 18

        let tempBox = FlippedView(frame: NSRect(x: pad, y: y, width: w, height: 0))
        cpuTempBox = tempBox
        v.addSubview(tempBox)
        cpuTempBaseY = y

        v.frame = NSRect(x: 0, y: 0, width: W, height: y + pad)
        return v
    }

    @objc private func cpuSearchChanged(_ sender: NSSearchField) {
        cpuFilter = sender.stringValue.lowercased()
        refreshCPUProcList()
    }

    private func refreshCPUProcList() {
        guard let box = cpuProcBox else { return }
        box.subviews.forEach { $0.removeFromSuperview() }

        let list: [TopProcess] = cpuFilter.isEmpty
            ? Array(cpuProcs.prefix(8))
            : Array(cpuProcs.filter { $0.name.lowercased().contains(cpuFilter) }.prefix(8))

        for (i, proc) in list.enumerated() {
            box.addSubview(cpuProcRow(proc, i))
        }
    }

    private func cpuProcRow(_ proc: TopProcess, _ idx: Int) -> NSView {
        let w = W - pad * 2
        let rowH: CGFloat = 44
        let row = NSView(frame: NSRect(x: 0, y: CGFloat(idx) * rowH, width: w, height: rowH))

        if idx > 0 {
            let sep = NSView(frame: NSRect(x: 34, y: 0, width: w - 34, height: 0.5))
            sep.wantsLayer = true
            sep.layer?.backgroundColor = rowSep.cgColor
            row.addSubview(sep)
        }

        var icon = Constants.defaultProcessIcon
        if let app = NSRunningApplication(processIdentifier: pid_t(proc.pid)),
           let appIcon = app.icon {
            icon = appIcon
        }
        let imgV = NSImageView(frame: NSRect(x: 0, y: (rowH - 28) / 2, width: 28, height: 28))
        imgV.image = icon
        imgV.imageScaling = .scaleProportionallyUpOrDown
        imgV.wantsLayer = true
        imgV.layer?.cornerRadius = 6
        imgV.layer?.masksToBounds = true
        row.addSubview(imgV)

        let nameF = lbl(proc.name, size: 13, color: bodyText)
        nameF.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameF.frame = NSRect(x: 36, y: (rowH - 16) / 2, width: w - 36 - 80, height: 16)
        nameF.lineBreakMode = .byTruncatingTail
        row.addSubview(nameF)

        let badge = NSView(frame: NSRect(x: w - 70, y: (rowH - 22) / 2, width: 66, height: 22))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = accentBlue.withAlphaComponent(0.14).cgColor
        badge.layer?.cornerRadius = 7
        row.addSubview(badge)

        let valF = lbl(String(format: "%.1f%%", proc.usage), size: 12, color: accentBlue)
        valF.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        valF.frame = NSRect(x: w - 70, y: (rowH - 22) / 2 + 3, width: 66, height: 16)
        valF.alignment = .center
        row.addSubview(valF)

        return row
    }

    // MARK: Memory content

    private func buildMemContent() -> NSView {
        let w = W - pad * 2
        var y: CGFloat = gap
        let v = FlippedView()

        // Chart
        let chartH: CGFloat = 160
        let chartCard = card(w: w, h: chartH, at: NSPoint(x: pad, y: y))
        let chart = LineChartView(
            frame: NSRect(x: 0, y: 0, width: w, height: chartH),
            num: 60, scale: .none, fixedScale: 1
        )
        chart.setColor(accentBlue)
        chartCard.addSubview(chart)
        memChart = chart
        v.addSubview(chartCard)
        y += chartH + gap

        v.addSubview(sectionHeader("TOP PROCESSES", at: NSPoint(x: pad, y: y)))
        y += 18

        // Search field
        let search = NSSearchField(frame: NSRect(x: pad, y: y, width: w, height: 32))
        search.placeholderString = "Search process"
        search.font = NSFont.systemFont(ofSize: 13)
        search.target = self
        search.action = #selector(searchChanged(_:))
        memSearch = search
        v.addSubview(search)
        y += 32 + gap

        // Process list
        let rows = 8
        let procBox = FlippedView(frame: NSRect(x: pad, y: y, width: w, height: CGFloat(rows) * 44))
        memProcBox = procBox
        v.addSubview(procBox)
        y += CGFloat(rows) * 44 + pad

        v.frame = NSRect(x: 0, y: 0, width: W, height: y)
        return v
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        memFilter = sender.stringValue.lowercased()
        refreshProcList()
    }

    private func refreshProcList() {
        guard let box = memProcBox else { return }
        box.subviews.forEach { $0.removeFromSuperview() }

        let list: [TopProcess] = memFilter.isEmpty
            ? Array(memProcs.prefix(8))
            : Array(memProcs.filter { $0.name.lowercased().contains(memFilter) }.prefix(8))

        for (i, proc) in list.enumerated() {
            box.addSubview(procRow(proc, i))
        }
    }

    private func procRow(_ proc: TopProcess, _ idx: Int) -> NSView {
        let w = W - pad * 2
        let rowH: CGFloat = 44
        let row = NSView(frame: NSRect(x: 0, y: CGFloat(idx) * rowH, width: w, height: rowH))

        // Separator (not on first row)
        if idx > 0 {
            let sep = NSView(frame: NSRect(x: 34, y: 0, width: w - 34, height: 0.5))
            sep.wantsLayer = true
            sep.layer?.backgroundColor = rowSep.cgColor
            row.addSubview(sep)
        }

        // App icon
        var icon = Constants.defaultProcessIcon
        if let app = NSRunningApplication(processIdentifier: pid_t(proc.pid)),
           let appIcon = app.icon {
            icon = appIcon
        }
        let imgV = NSImageView(frame: NSRect(x: 0, y: (rowH - 28) / 2, width: 28, height: 28))
        imgV.image = icon
        imgV.imageScaling = .scaleProportionallyUpOrDown
        imgV.wantsLayer = true
        imgV.layer?.cornerRadius = 6
        imgV.layer?.masksToBounds = true
        row.addSubview(imgV)

        // Process name
        let nameF = lbl(proc.name, size: 13, color: bodyText)
        nameF.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameF.frame = NSRect(x: 36, y: (rowH - 16) / 2, width: w - 36 - 86, height: 16)
        nameF.lineBreakMode = .byTruncatingTail
        row.addSubview(nameF)

        let mem = Units(bytes: Int64(proc.usage)).getReadableMemory(style: .memory)
        let badge = NSView(frame: NSRect(x: w - 76, y: (rowH - 22) / 2, width: 72, height: 22))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = accentBlue.withAlphaComponent(0.14).cgColor
        badge.layer?.cornerRadius = 7
        row.addSubview(badge)

        let valF = lbl(mem, size: 12, color: accentBlue)
        valF.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        valF.frame = NSRect(x: w - 76, y: (rowH - 22) / 2 + 3, width: 72, height: 16)
        valF.alignment = .center
        row.addSubview(valF)

        return row
    }

    // MARK: Battery content

    private func buildBatContent() -> NSView {
        let w = W - pad * 2
        var y: CGFloat = gap
        let v = FlippedView()

        // Level bar
        let barCard = card(w: w, h: 48, at: NSPoint(x: pad, y: y))
        let bar = BarChartView(frame: NSRect(x: 8, y: 10, width: w - 16, height: 28), horizontal: true)
        barCard.addSubview(bar)
        batBar = bar
        v.addSubview(barCard)
        y += 48 + gap

        // Stats card 1: Level, Source, Health, Cycles
        let card1 = card(w: w, h: 80, at: NSPoint(x: pad, y: y))
        let fs1 = statsGrid(in: card1,
                            labels: ["Level", "Source", "Health", "Cycles"],
                            values: ["—", "—", "—", "—"])
        batLevelF = fs1[0]; batSourceF = fs1[1]; batHealthF = fs1[2]; batCyclesF = fs1[3]
        v.addSubview(card1)
        y += 80 + gap

        // Stats card 2: Time, Temperature, Voltage, Watts
        let card2 = card(w: w, h: 80, at: NSPoint(x: pad, y: y))
        let fs2 = statsGrid(in: card2,
                            labels: ["Time", "Temperature", "Voltage", "AC Watts"],
                            values: ["—", "—", "—", "—"])
        batTimeF = fs2[0]; batTempF = fs2[1]; batVoltF = fs2[2]; batWattsF = fs2[3]
        v.addSubview(card2)
        y += 80 + pad

        v.frame = NSRect(x: 0, y: 0, width: W, height: y)
        return v
    }

    private func renderBattery(_ b: Battery_Usage) {
        batBar?.setValue(ColorValue(b.level, color: batteryColor(b.level)))

        batLevelF?.stringValue  = "\(Int((b.level * 100).rounded()))%"
        if b.isCharging {
            batSourceF?.stringValue = "Charging"
        } else if b.isCharged {
            batSourceF?.stringValue = "Charged"
        } else {
            batSourceF?.stringValue = b.isBatteryPowered ? "Battery" : "AC Power"
        }
        batHealthF?.stringValue  = "\(b.health)%"
        batCyclesF?.stringValue  = "\(b.cycles)"

        if b.isCharging && b.timeToCharge > 0 {
            batTimeF?.stringValue = formatBatTime(b.timeToCharge) + " left"
        } else if b.timeToEmpty > 0 {
            batTimeF?.stringValue = formatBatTime(b.timeToEmpty) + " left"
        } else {
            batTimeF?.stringValue = "—"
        }

        batTempF?.stringValue = b.temperature > 0 ? String(format: "%.1f °C", b.temperature) : "—"
        batVoltF?.stringValue = b.voltage > 0 ? String(format: "%.2f V", b.voltage) : "—"
        batWattsF?.stringValue = b.ACwatts > 0 ? "\(b.ACwatts) W" : "—"
    }

    private func batteryColor(_ level: Double) -> NSColor {
        if level < 0.15 { return NSColor(red: 1, green: 0.23, blue: 0.19, alpha: 1) }
        if level < 0.30 { return accentOrange }
        return accentBlue
    }

    private func formatBatTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Network content

    private func buildNetContent() -> NSView {
        let w = W - pad * 2
        var y: CGFloat = gap
        let v = FlippedView()

        let chartH: CGFloat = 110
        let chartCard = card(w: w, h: chartH, at: NSPoint(x: pad, y: y))
        let chart = NetworkChartView(
            frame: NSRect(x: 0, y: 0, width: w, height: chartH),
            num: 60, reversedOrder: false,
            outColor: accentOrange, inColor: accentBlue
        )
        chartCard.addSubview(chart)
        netChart = chart
        v.addSubview(chartCard)
        y += chartH + gap

        // Legend
        let legend = netLegend(at: NSPoint(x: pad, y: y), width: w)
        v.addSubview(legend)
        y += 22 + gap

        let statsCard = card(w: w, h: 80, at: NSPoint(x: pad, y: y))
        let fs = statsGrid(in: statsCard,
                           labels: ["Download", "Upload", "Total Down", "Total Up"],
                           values: ["—", "—", "—", "—"])
        netDownF = fs[0]; netUpF = fs[1]; netTotDownF = fs[2]; netTotUpF = fs[3]
        v.addSubview(statsCard)
        y += 80 + pad

        v.frame = NSRect(x: 0, y: 0, width: W, height: y)
        return v
    }

    private func netLegend(at origin: NSPoint, width: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(origin: origin, size: CGSize(width: width, height: 22)))
        let dot1 = dot(color: accentOrange, frame: NSRect(x: 0, y: 6, width: 10, height: 10))
        let l1 = lbl("↑ Upload", size: 11, color: mutedText)
        l1.frame = NSRect(x: 14, y: 0, width: 70, height: 22)
        let dot2 = dot(color: accentBlue, frame: NSRect(x: 92, y: 6, width: 10, height: 10))
        let l2 = lbl("↓ Download", size: 11, color: mutedText)
        l2.frame = NSRect(x: 106, y: 0, width: 80, height: 22)
        [dot1, l1, dot2, l2].forEach { v.addSubview($0) }
        return v
    }

    // MARK: Storage content

    private func buildStorContent() -> NSView {
        let w = W - pad * 2
        var y: CGFloat = gap
        let v = FlippedView()

        let barCard = card(w: w, h: 48, at: NSPoint(x: pad, y: y))
        let bar = BarChartView(frame: NSRect(x: 8, y: 10, width: w - 16, height: 28), horizontal: true)
        barCard.addSubview(bar)
        storBar = bar
        v.addSubview(barCard)
        y += 48 + gap

        let statsCard = card(w: w, h: 80, at: NSPoint(x: pad, y: y))
        let fs = statsGrid(in: statsCard,
                           labels: ["Total", "Used", "Free", "Purgeable"],
                           values: ["—", "—", "—", "—"])
        storTotF = fs[0]; storUsedF = fs[1]; storFreeF = fs[2]; storPurgeF = fs[3]
        v.addSubview(statsCard)
        y += 80 + pad

        v.frame = NSRect(x: 0, y: 0, width: W, height: y)
        return v
    }

    // MARK: Storage refresh

    private func refreshStorage() {
        DispatchQueue.global(qos: .background).async {
            let fm = FileManager.default
            guard let attrs = try? fm.attributesOfFileSystem(forPath: "/"),
                  let total = attrs[.systemSize] as? Int64,
                  let free  = attrs[.systemFreeSize] as? Int64 else { return }
            let used = total - free

            var purgeable: Int64 = 0
            if let vals = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ]) {
                let imp   = vals.volumeAvailableCapacityForImportantUsage ?? 0
                let avail = Int64(vals.volumeAvailableCapacity ?? 0)
                purgeable = max(0, imp - avail)
            }

            DispatchQueue.main.async { [weak self] in
                self?.updateStorUI(total: total, used: used, free: free, purgeable: purgeable)
            }
        }
    }

    private func updateStorUI(total: Int64, used: Int64, free: Int64, purgeable: Int64) {
        storTotF?.stringValue  = DiskSize(total).getReadableMemory()
        storUsedF?.stringValue = DiskSize(used).getReadableMemory()
        storFreeF?.stringValue = DiskSize(free).getReadableMemory()
        storPurgeF?.stringValue = purgeable > 0 ? DiskSize(purgeable).getReadableMemory() : "—"
        if total > 0 {
            storBar?.setValue(ColorValue(Double(used) / Double(total), color: accentBlue))
        }
    }

    // MARK: Render

    private func renderCPU(_ v: CPU_Load) {
        cpuChart?.addValue(v.totalUsage)
        cpuChart?.display()
        cpuUserF?.stringValue  = "\(pct(v.userLoad))%"
        cpuSysF?.stringValue   = "\(pct(v.systemLoad))%"
        cpuIdleF?.stringValue  = "\(pct(v.idleLoad))%"
        cpuCoresF?.stringValue = "\(SystemKit.shared.device.info.cpu?.logicalCores ?? 0)"
    }

    private func renderRAM(_ v: RAM_Usage) {
        memChart?.addValue(v.usage)
        memChart?.display()
        if memTotal != v.total {
            memTotal = v.total
            updateYAxisLabels()
        }
    }

    private func updateYAxisLabels() {
        memYLabels.forEach { $0.removeFromSuperview() }
        memYLabels.removeAll()
        guard memTotal > 0, let chartCard = memChart?.superview else { return }

        // chartCard is non-flipped: y=0 is visual bottom
        let h = chartCard.frame.height
        let gb = memTotal / 1_073_741_824

        let steps: [(Double, String)] = [
            (0.75, String(format: "%.2f GB", gb * 0.75)),
            (0.50, String(format: "%.2f GB", gb * 0.50)),
            (0.25, String(format: "%.2f GB", gb * 0.25)),
        ]
        for (frac, text) in steps {
            let label = lbl(text, size: 9, color: NSColor.white.withAlphaComponent(0.40))
            label.frame = NSRect(x: 4, y: CGFloat(frac) * h - 6, width: 60, height: 12)
            chartCard.addSubview(label)
            memYLabels.append(label)
        }
    }

    private func renderNet(_ v: Network_Usage) {
        netChart?.addValue(upload: Double(v.bandwidth.upload), download: Double(v.bandwidth.download))
        netDownF?.stringValue    = Units(bytes: v.bandwidth.download).getReadableSpeed()
        netUpF?.stringValue      = Units(bytes: v.bandwidth.upload).getReadableSpeed()
        netTotDownF?.stringValue = Units(bytes: v.total.download).getReadableMemory()
        netTotUpF?.stringValue   = Units(bytes: v.total.upload).getReadableMemory()
    }

    // MARK: Factory helpers

    private func card(w: CGFloat, h: CGFloat, at origin: NSPoint = .zero) -> NSView {
        let v = NSView(frame: NSRect(origin: origin, size: CGSize(width: w, height: h)))
        v.wantsLayer = true
        v.layer?.backgroundColor = cardBG.cgColor
        v.layer?.cornerRadius = 12
        v.layer?.borderWidth = 0.5
        v.layer?.borderColor = cardBorder.cgColor
        return v
    }

    private func lbl(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let f = NSTextField()
        f.stringValue = text
        f.font = NSFont.systemFont(ofSize: size)
        f.textColor = color
        f.isEditable = false
        f.isSelectable = false
        f.isBezeled = false
        f.drawsBackground = false
        return f
    }

    private func dot(color: NSColor, frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        v.layer?.cornerRadius = frame.width / 2
        return v
    }

    /// 2-column × 2-row stats grid. Returns the four value fields in order.
    private func statsGrid(in card: NSView, labels: [String], values: [String]) -> [NSTextField] {
        let colW = card.frame.width / 2
        let rowH: CGFloat = 32
        let vPad = (card.frame.height - 2 * rowH) / 2
        var fields: [NSTextField] = []

        for (i, (l, v)) in zip(labels, values).enumerated() {
            let col = i % 2
            let row = i / 2
            let x = CGFloat(col) * colW + 12
            // card is non-flipped: y from bottom
            let y = card.frame.height - vPad - CGFloat(row + 1) * rowH

            let lv = lbl(l.uppercased(), size: 9, color: NSColor.white.withAlphaComponent(0.30))
            lv.frame = NSRect(x: x, y: y + 19, width: colW - 14, height: 11)

            let vv = lbl(v, size: 15, color: bodyText)
            vv.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
            vv.frame = NSRect(x: x, y: y, width: colW - 14, height: 17)

            card.addSubview(lv)
            card.addSubview(vv)
            fields.append(vv)
        }
        return fields
    }

    private func sectionHeader(_ text: String, at origin: NSPoint) -> NSTextField {
        let f = lbl(text, size: 10, color: NSColor.white.withAlphaComponent(0.30))
        f.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        f.frame = NSRect(origin: origin, size: CGSize(width: W - pad * 2, height: 14))
        return f
    }

    private func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }

    private func renderCPUTemps(_ sensors: [Sensor_p]) {
        guard let box = cpuTempBox else { return }
        box.subviews.forEach { $0.removeFromSuperview() }

        let w = W - pad * 2
        let cpuTemps = sensors
            .filter { $0.group == .CPU && $0.type == .temperature && $0.value > 0 }
            .sorted { ($0.isComputed ? 1 : 0) != ($1.isComputed ? 1 : 0)
                        ? $0.isComputed
                        : $0.value > $1.value }
            .prefix(8)
            .map { $0 }

        var boxH: CGFloat = 0
        if !cpuTemps.isEmpty {
            let rowH: CGFloat = 34
            let tempCard = card(w: w, h: CGFloat(cpuTemps.count) * rowH, at: .zero)

            for (i, sensor) in cpuTemps.enumerated() {
                let rowY = CGFloat(i) * rowH
                if i > 0 {
                    let sep = NSView(frame: NSRect(x: 12, y: rowY, width: w - 24, height: 0.5))
                    sep.wantsLayer = true
                    sep.layer?.backgroundColor = rowSep.cgColor
                    tempCard.addSubview(sep)
                }
                let nameF = lbl(sensor.name, size: 12, color: bodyText)
                nameF.frame = NSRect(x: 12, y: rowY + 9, width: w - 110, height: 16)
                nameF.lineBreakMode = .byTruncatingTail
                tempCard.addSubview(nameF)

                let color = tempColor(sensor.value)
                let valF = lbl(sensor.formattedValue, size: 13, color: color)
                valF.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
                valF.frame = NSRect(x: w - 96, y: rowY + 9, width: 84, height: 16)
                valF.alignment = .right
                tempCard.addSubview(valF)
            }

            box.addSubview(tempCard)
            boxH = CGFloat(cpuTemps.count) * rowH + gap
        }

        box.setFrameSize(NSSize(width: w, height: boxH))
        cpuContent.setFrameSize(NSSize(width: W, height: cpuTempBaseY + boxH + pad))

        if activeTab == .cpu {
            recalculate()
        }
    }

    private func tempColor(_ celsius: Double) -> NSColor {
        if celsius > 85 { return NSColor(red: 1, green: 0.23, blue: 0.19, alpha: 1) }
        if celsius > 65 { return accentOrange }
        return NSColor(red: 0.25, green: 0.85, blue: 0.45, alpha: 1)
    }

    // MARK: Sensors / Fans content

    private func buildSensorsContent() -> NSView {
        let v = FlippedView(frame: NSRect(x: 0, y: 0, width: W, height: 100))
        return v
    }

    private func renderSensors(_ sensors: [Sensor_p]) {
        guard let box = senContent else { return }
        box.subviews.forEach { $0.removeFromSuperview() }

        let w = W - pad * 2
        var y: CGFloat = gap

        // Fan speeds
        let fans = sensors.compactMap { $0 as? Fan }.filter { $0.value > 0 }

        if !fans.isEmpty {
            box.addSubview(sectionHeader("FAN SPEEDS", at: NSPoint(x: pad, y: y)))
            y += 18

            let fanRowH: CGFloat = 46
            let fanCard = card(w: w, h: CGFloat(fans.count) * fanRowH, at: NSPoint(x: pad, y: y))

            for (i, fan) in fans.enumerated() {
                let rowY = CGFloat(i) * fanRowH
                if i > 0 {
                    let sep = NSView(frame: NSRect(x: 12, y: rowY, width: w - 24, height: 0.5))
                    sep.wantsLayer = true
                    sep.layer?.backgroundColor = rowSep.cgColor
                    fanCard.addSubview(sep)
                }

                let nameF = lbl(fan.name, size: 12, color: bodyText)
                nameF.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                nameF.frame = NSRect(x: 12, y: rowY + 7, width: w - 120, height: 15)
                nameF.lineBreakMode = .byTruncatingTail
                fanCard.addSubview(nameF)

                let rpmF = lbl(fan.formattedValue, size: 13, color: accentBlue)
                rpmF.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
                rpmF.frame = NSRect(x: w - 106, y: rowY + 7, width: 94, height: 15)
                rpmF.alignment = .right
                fanCard.addSubview(rpmF)

                let barW = w - 24
                let barBG = NSView(frame: NSRect(x: 12, y: rowY + 30, width: barW, height: 6))
                barBG.wantsLayer = true
                barBG.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
                barBG.layer?.cornerRadius = 3
                fanCard.addSubview(barBG)

                let pct = fan.maxSpeed > 0 ? min(CGFloat(fan.value) / CGFloat(fan.maxSpeed), 1.0) : 0
                if pct > 0 {
                    let barFill = NSView(frame: NSRect(x: 0, y: 0, width: barW * pct, height: 6))
                    barFill.wantsLayer = true
                    barFill.layer?.backgroundColor = accentBlue.cgColor
                    barFill.layer?.cornerRadius = 3
                    barBG.addSubview(barFill)
                }
            }

            box.addSubview(fanCard)
            y += CGFloat(fans.count) * fanRowH + gap
        } else {
            let noData = lbl("No fan data available", size: 13, color: mutedText)
            noData.frame = NSRect(x: pad, y: y + 8, width: w, height: 20)
            noData.alignment = .center
            box.addSubview(noData)
            y += 36
        }

        box.setFrameSize(NSSize(width: W, height: y + pad))

        if activeTab == .fans {
            recalculate()
        }
    }
}
