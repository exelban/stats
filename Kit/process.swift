//
//  process.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 05/01/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Process_p {
    var pid: Int { get }
    var name: String { get }
    var icon: NSImage { get }
}

public typealias ProcessHeader = (title: String, color: NSColor?)

public class ProcessesView: NSStackView {
    public var count: Int {
        self.list.count
    }
    private var list: [ProcessView] = []
    private var colorViews: [ColorView] = []
    
    public init(frame: NSRect = .zero, values: [ProcessHeader], n: Int = 0) {
        super.init(frame: frame)
        
        self.orientation = .vertical
        self.spacing = 0
        
        let header = self.generateHeaderView(values)
        self.addArrangedSubview(header)
        
        for _ in 0..<n {
            let view = ProcessView(n: values.count)
            self.addArrangedSubview(view)
            self.list.append(view)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func generateHeaderView(_ values: [ProcessHeader]) -> NSView {
        let view = NSStackView()
        view.widthAnchor.constraint(equalToConstant: self.bounds.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
        view.orientation = .horizontal
        view.distribution = .fillProportionally
        view.spacing = 0
        
        let iconView: NSImageView = NSImageView()
        iconView.widthAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
        view.addArrangedSubview(iconView)
        
        let titleField = LabelField()
        titleField.cell?.truncatesLastVisibleLine = true
        titleField.toolTip = localizedString("Process")
        titleField.stringValue = localizedString("Process")
        titleField.textColor = .tertiaryLabelColor
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addArrangedSubview(titleField)
        
        if values.count == 1, let v = values.first {
            let field = LabelField()
            field.cell?.truncatesLastVisibleLine = true
            field.toolTip = v.title
            field.stringValue = v.title
            field.alignment = .right
            field.textColor = .tertiaryLabelColor
            field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            view.addArrangedSubview(field)
        } else {
            for v in values {
                if let color = v.color {
                    let container: NSView = NSView()
                    container.widthAnchor.constraint(equalToConstant: 60).isActive = true
                    container.heightAnchor.constraint(equalToConstant: ProcessView.height).isActive = true
                    let colorBlock: ColorView = ColorView(frame: NSRect(x: 48, y: 5, width: 12, height: 12), color: color, state: true, radius: 4)
                    colorBlock.toolTip = v.title
                    colorBlock.widthAnchor.constraint(equalToConstant: 12).isActive = true
                    colorBlock.heightAnchor.constraint(equalToConstant: 12).isActive = true
                    self.colorViews.append(colorBlock)
                    container.addSubview(colorBlock)
                    view.addArrangedSubview(container)
                }
            }
        }
        
        return view
    }
    
    public func setLock(_ newValue: Bool) {
        self.list.forEach{ $0.setLock(newValue) }
    }
    
    public func clear(_ symbol: String = "") {
        self.list.forEach{ $0.clear(symbol) }
    }
    
    public func set(_ idx: Int, _ process: Process_p, _ values: [String]) {
        if self.list.indices.contains(idx) {
            self.list[idx].set(process, values)
        }
    }
    
    public func setColor(_ idx: Int, _ newColor: NSColor) {
        if self.colorViews.indices.contains(idx) {
            self.colorViews[idx].setColor(newColor)
        }
    }
}

public class ProcessView: NSStackView {
    static let height: CGFloat = 22
    
    private var pid: Int? = nil
    private var lock: Bool = false
    
    private var imageView: NSImageView = NSImageView()
    private var killView: NSButton = NSButton()
    private var treeView: NSButton = NSButton()
    private var labelView: LabelField = {
        let view = LabelField()
        view.cell?.truncatesLastVisibleLine = true
        return view
    }()
    private var valueViews: [ValueField] = []
    
    public init(size: CGSize = CGSize(width: 264, height: 22), n: Int = 1) {
        var rect = NSRect(x: 2, y: 5, width: 12, height: 12)
        if size.height != 22 {
            rect = NSRect(x: 1, y: 3, width: 12, height: 12)
        }
        self.imageView = NSImageView(frame: rect)
        self.killView = NSButton(frame: rect)
        self.treeView = NSButton(frame: rect)
        
        super.init(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        
        self.wantsLayer = true
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0
        self.layer?.cornerRadius = 3
        
        let imageBox: NSView = {
            let view = NSView()
            
            self.killView.bezelStyle = .regularSquare
            self.killView.translatesAutoresizingMaskIntoConstraints = false
            self.killView.imageScaling = .scaleNone
            self.killView.image = Bundle(for: type(of: self)).image(forResource: "cancel")!
            self.killView.contentTintColor = .lightGray
            self.killView.isBordered = false
            self.killView.action = #selector(self.kill)
            self.killView.target = self
            self.killView.toolTip = localizedString("Kill process")
            self.killView.focusRingType = .none
            self.killView.isHidden = true
            
            view.addSubview(self.imageView)
            view.addSubview(self.killView)
            
            return view
        }()
        
        self.treeView.bezelStyle = .regularSquare
        self.treeView.translatesAutoresizingMaskIntoConstraints = false
        self.treeView.imageScaling = .scaleNone
        if #available(macOS 11.0, *) {
            self.treeView.image = NSImage(systemSymbolName: "list.triangle", accessibilityDescription: localizedString("Show process tree"))?
                .withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
        }
        self.treeView.contentTintColor = .lightGray
        self.treeView.isBordered = false
        self.treeView.action = #selector(self.showProcessTree)
        self.treeView.target = self
        self.treeView.toolTip = localizedString("Show process tree")
        self.treeView.focusRingType = .none
        self.treeView.isHidden = true
        
        let treeBox: NSView = {
            let view = NSView()
            view.addSubview(self.treeView)
            return view
        }()
        
        self.addArrangedSubview(imageBox)
        self.addArrangedSubview(self.labelView)
        self.valuesViews(n).forEach{ self.addArrangedSubview($0) }
        self.addArrangedSubview(treeBox)
        
        self.addTrackingArea(NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        ))
        
        NSLayoutConstraint.activate([
            imageBox.widthAnchor.constraint(equalToConstant: self.bounds.height),
            imageBox.heightAnchor.constraint(equalToConstant: self.bounds.height),
            self.labelView.heightAnchor.constraint(equalToConstant: 16),
            treeBox.widthAnchor.constraint(equalToConstant: self.bounds.height),
            treeBox.heightAnchor.constraint(equalToConstant: self.bounds.height),
            self.widthAnchor.constraint(equalToConstant: self.bounds.width),
            self.heightAnchor.constraint(equalToConstant: self.bounds.height)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func valuesViews(_ n: Int) -> [NSView] {
        var list: [ValueField] = []
        
        for _ in 0..<n {
            let view: ValueField = ValueField()
            view.widthAnchor.constraint(equalToConstant: 68).isActive = true
            if n != 1 {
                view.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            }
            list.append(view)
        }
        
        self.valueViews = list
        return list
    }
    
    public override func mouseEntered(with: NSEvent) {
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
            self.treeView.isHidden = false
            return
        }
        self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.05)
    }
    
    public override func mouseExited(with: NSEvent) {
        if self.lock {
            self.imageView.isHidden = false
            self.killView.isHidden = true
            self.treeView.isHidden = true
            return
        }
        self.layer?.backgroundColor = .none
    }
    
    public override func mouseDown(with: NSEvent) {
        self.setLock(!self.lock)
    }
    
    @objc private func showProcessTree() {
        guard let pid = self.pid else { return }
        ProcessTreePanel(pid: pid, processName: self.labelView.stringValue).show()
    }
    
    fileprivate func set(_ process: Process_p, _ values: [String]) {
        if self.lock && process.pid != self.pid { return }
        
        self.labelView.stringValue = process.name
        values.enumerated().forEach({ self.valueViews[$0.offset].stringValue = $0.element })
        self.imageView.image = process.icon
        self.pid = process.pid
        self.toolTip = "pid: \(process.pid)"
    }
    
    fileprivate func clear(_ symbol: String = "") {
        self.labelView.stringValue = symbol
        self.valueViews.forEach({ $0.stringValue = symbol })
        self.imageView.image = nil
        self.pid = nil
        self.setLock(false)
        self.toolTip = symbol
    }
    
    fileprivate func setLock(_ state: Bool) {
        self.lock = state
        if self.lock {
            self.imageView.isHidden = true
            self.killView.isHidden = false
            self.treeView.isHidden = false
            self.layer?.backgroundColor = .init(gray: 0.01, alpha: 0.1)
        } else {
            self.imageView.isHidden = false
            self.killView.isHidden = true
            self.treeView.isHidden = true
            self.layer?.backgroundColor = .none
        }
    }
    
    @objc private func kill() {
        if let pid = self.pid {
            _ = syncShell("kill -9 \(pid)")
            self.clear()
            self.setLock(false)
        }
    }
}

// MARK: - Process Tree

private struct ProcessTreeNode {
    let pid: Int
    let ppid: Int
    let name: String
    var children: [ProcessTreeNode]
}

public class ProcessTreePanel: NSPanel {
    private let targetPid: Int
    private let processName: String
    
    public init(pid: Int, processName: String) {
        self.targetPid = pid
        self.processName = processName
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.hudWindow, .utilityWindow, .titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        self.isFloatingPanel = true
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.title = "\(localizedString("Process tree")): \(processName) (pid \(pid))"
        self.minSize = NSSize(width: 320, height: 200)
    }
    
    public func show() {
        let scrollView = NSScrollView(frame: self.contentRect(forFrameRect: self.frame))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.string = localizedString("Loading...")
        
        scrollView.documentView = textView
        self.contentView = scrollView
        
        self.makeKeyAndOrderFront(nil)
        self.center()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let tree = self.buildTreeString()
            DispatchQueue.main.async {
                textView.string = tree
            }
        }
    }
    
    private func runShell(_ args: String) -> String {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func buildTreeString() -> String {
        let raw = self.runShell("ps -axo pid=,ppid=,%cpu=,rss=,comm=")
        let rawArgs = self.runShell("ps -axo pid=,args=")
        let lines = raw.split(separator: "\n")
        
        // Parse args by pid for enrichment
        var argsMap: [Int: String] = [:]
        for line in rawArgs.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 2, let pid = Int(parts[0]) else { continue }
            argsMap[pid] = String(parts[1])
        }
        
        struct ProcInfo {
            let pid: Int
            let ppid: Int
            let name: String
            let cpu: String
            let memKB: Int
            let args: String
        }
        
        var allProcesses: [ProcInfo] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard parts.count >= 5,
                  let pid = Int(parts[0]),
                  let ppid = Int(parts[1]) else { continue }
            let cpu = String(parts[2])
            let memKB = Int(parts[3]) ?? 0
            let name = String(parts[4])
            let args = argsMap[pid] ?? name
            allProcesses.append(ProcInfo(pid: pid, ppid: ppid, name: name, cpu: cpu, memKB: memKB, args: args))
        }
        
        func formatMem(_ kb: Int) -> String {
            if kb >= 1_048_576 { return String(format: "%.1f GB", Double(kb) / 1_048_576.0) }
            if kb >= 1024 { return String(format: "%.1f MB", Double(kb) / 1024.0) }
            return "\(kb) KB"
        }
        
        func shortName(_ proc: ProcInfo) -> String {
            (proc.name as NSString).lastPathComponent
        }
        
        func detail(_ proc: ProcInfo) -> String {
            // Extract useful info from args (e.g. --type=renderer for Chrome/Electron)
            var extra = ""
            if let typeRange = proc.args.range(of: #"--type=(\S+)"#, options: .regularExpression) {
                extra = " (" + proc.args[typeRange].replacingOccurrences(of: "--type=", with: "") + ")"
            }
            return "\(shortName(proc))\(extra)  [\(proc.pid)]  cpu: \(proc.cpu)%  mem: \(formatMem(proc.memKB))"
        }
        
        // Build ancestor chain from target up to pid 0/1
        var ancestors: [ProcInfo] = []
        var currentPid = self.targetPid
        while currentPid > 1 {
            guard let proc = allProcesses.first(where: { $0.pid == currentPid }) else { break }
            ancestors.append(proc)
            currentPid = proc.ppid
        }
        if let root = allProcesses.first(where: { $0.pid == currentPid }) {
            ancestors.append(root)
        }
        ancestors.reverse()
        
        // Collect direct children of target
        let children = allProcesses.filter { $0.ppid == self.targetPid }
        
        // Compute total tree memory
        func treeMemKB(_ pid: Int) -> Int {
            let self_mem = allProcesses.first(where: { $0.pid == pid })?.memKB ?? 0
            let childMem = allProcesses.filter({ $0.ppid == pid }).reduce(0) { $0 + treeMemKB($1.pid) }
            return self_mem + childMem
        }
        let totalMem = treeMemKB(self.targetPid)
        
        var result = ""
        
        // Summary line
        if let target = allProcesses.first(where: { $0.pid == self.targetPid }) {
            result += "\(shortName(target))  [pid \(target.pid)]\n"
            result += "CPU: \(target.cpu)%  Memory: \(formatMem(target.memKB))"
            if !children.isEmpty {
                result += "  Total (with children): \(formatMem(totalMem))"
            }
            result += "\n\n"
        }
        
        // Ancestor chain
        result += "\(localizedString("Process tree")):\n\n"
        for (i, ancestor) in ancestors.enumerated() {
            let indent = String(repeating: "  ", count: i)
            let marker = ancestor.pid == self.targetPid ? "▶ " : "  "
            result += "\(indent)\(marker)\(detail(ancestor))\n"
        }
        
        // Children under the target
        if !children.isEmpty {
            let childIndent = String(repeating: "  ", count: ancestors.count)
            for (i, child) in children.enumerated() {
                let connector = i == children.count - 1 ? "└─" : "├─"
                result += "\(childIndent)\(connector) \(detail(child))\n"
                
                // Grandchildren (one level deep)
                let grandchildren = allProcesses.filter { $0.ppid == child.pid }
                for (j, gc) in grandchildren.enumerated() {
                    let gcPrefix = i == children.count - 1 ? "  " : "│ "
                    let gcConnector = j == grandchildren.count - 1 ? "└─" : "├─"
                    result += "\(childIndent)\(gcPrefix)\(gcConnector) \(detail(gc))\n"
                }
            }
        }
        
        if children.isEmpty && ancestors.last?.pid == self.targetPid {
            result += "\n\(localizedString("No child processes"))\n"
        }
        
        // Safari tab enrichment
        let isSafari = self.processName.lowercased().contains("safari") ||
            allProcesses.first(where: { $0.pid == self.targetPid })?.name.contains("Safari") == true ||
            allProcesses.first(where: { $0.pid == self.targetPid })?.name.contains("WebContent") == true
        if isSafari {
            // List WebContent processes (each represents a tab/extension)
            let webContentProcs = allProcesses
                .filter { $0.name.contains("WebContent") }
                .sorted(by: { $0.memKB > $1.memKB })
            if !webContentProcs.isEmpty {
                result += "\nWebContent processes (\(webContentProcs.count)):\n\n"
                for proc in webContentProcs {
                    result += "  [\(proc.pid)]  mem: \(formatMem(proc.memKB))  cpu: \(proc.cpu)%\n"
                }
            }
            
            let tabs = self.fetchSafariTabs()
            if !tabs.isEmpty {
                result += "\n\(localizedString("Open Safari tabs")) (\(tabs.count)):\n\n"
                for (i, tab) in tabs.enumerated() {
                    result += "  \(i + 1). \(tab)\n"
                }
                if !webContentProcs.isEmpty {
                    result += "\n  Note: tabs are listed by window order; WebContent processes\n  are sorted by memory (highest first) to help correlate.\n"
                }
            }
        }
        
        return result
    }
    
    private func fetchSafariTabs() -> [String] {
        let script = """
        tell application "System Events"
            if (name of processes) contains "Safari" then
                tell application "Safari"
                    set tabList to ""
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabList to tabList & (name of t) & "|||" & (URL of t) & linefeed
                        end repeat
                    end repeat
                    return tabList
                end tell
            end if
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.launch()
        
        // Timeout: kill if it takes too long
        let deadline = DispatchTime.now() + .seconds(3)
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if task.isRunning { task.terminate() }
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return [] }
        
        return output.split(separator: "\n").compactMap { line in
            let parts = String(line).components(separatedBy: "|||")
            guard let title = parts.first, !title.isEmpty else { return nil }
            let url = parts.count > 1 ? parts[1] : ""
            if url.isEmpty { return String(title) }
            // Show just the domain from the URL
            if let urlObj = URL(string: url), let host = urlObj.host {
                return "\(title)  (\(host))"
            }
            return String(title)
        }
    }
}
