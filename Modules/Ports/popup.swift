//
//  popup.swift
//  Ports
//
//  Created by Dogukan Akin on 05/10/2025.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private var tableView: NSTableView?
    private var scrollView: NSScrollView?
    private var ports: [PortInfo] = []
    private var reader: PortsReader?
    
    private let headerHeight: CGFloat = 50
    private let rowHeight: CGFloat = 30
    private let maxVisibleRows: Int = 15
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width + 100,
            height: 400
        ))
        
        self.addSubview(self.initContent())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        
        // Header
        let headerView = NSView(frame: NSRect(x: 0, y: self.frame.height - headerHeight, width: self.frame.width, height: headerHeight))
        
        let titleLabel = NSTextField(frame: NSRect(x: 15, y: 20, width: 200, height: 20))
        titleLabel.stringValue = localizedString("Active Ports")
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        headerView.addSubview(titleLabel)
        
        let refreshButton = NSButton(frame: NSRect(x: self.frame.width - 80, y: 15, width: 65, height: 25))
        refreshButton.title = localizedString("Refresh")
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshPorts)
        headerView.addSubview(refreshButton)
        
        view.addSubview(headerView)
        
        // Table view
        let tableFrame = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height - headerHeight)
        scrollView = NSScrollView(frame: tableFrame)
        scrollView?.hasVerticalScroller = true
        scrollView?.hasHorizontalScroller = false
        scrollView?.autohidesScrollers = true
        scrollView?.backgroundColor = .clear
        
        tableView = NSTableView(frame: scrollView!.bounds)
        tableView?.headerView = NSTableHeaderView()
        tableView?.backgroundColor = .clear
        tableView?.rowHeight = rowHeight
        tableView?.intercellSpacing = NSSize(width: 0, height: 4)
        tableView?.delegate = self
        tableView?.dataSource = self
        
        // Columns
        let portColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("port"))
        portColumn.title = localizedString("Port")
        portColumn.width = 60
        tableView?.addTableColumn(portColumn)
        
        let processColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("process"))
        processColumn.title = localizedString("Process")
        processColumn.width = 150
        tableView?.addTableColumn(processColumn)
        
        let pidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("pid"))
        pidColumn.title = "PID"
        pidColumn.width = 60
        tableView?.addTableColumn(pidColumn)
        
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = localizedString("Action")
        actionColumn.width = 70
        tableView?.addTableColumn(actionColumn)
        
        scrollView?.documentView = tableView
        view.addSubview(scrollView!)
        
        return view
    }
    
    @objc private func refreshPorts() {
        reader?.read()
    }
    
    public func setReader(_ reader: PortsReader) {
        self.reader = reader
    }
    
    public func portsCallback(_ ports: [PortInfo]) {
        self.ports = ports
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView?.reloadData()
        }
    }
    
    @objc private func killButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < ports.count else { return }
        
        let port = ports[row]
        
        let alert = NSAlert()
        alert.messageText = localizedString("Kill Process")
        alert.informativeText = String(format: localizedString("Are you sure you want to kill process '%@' (PID: %d) on port %d?"), port.processName, port.pid, port.port)
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedString("Kill"))
        alert.addButton(withTitle: localizedString("Cancel"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            if reader?.killProcess(pid: port.pid) == true {
                // Wait a moment and refresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.refreshPorts()
                }
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = localizedString("Error")
                errorAlert.informativeText = localizedString("Failed to kill process. You may need administrator privileges.")
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
}

extension Popup: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ports.count
    }
}

extension Popup: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < ports.count else { return nil }
        let port = ports[row]
        
        let cellView = NSView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 0, height: rowHeight))
        
        switch tableColumn?.identifier.rawValue {
        case "port":
            let textField = NSTextField(frame: NSRect(x: 5, y: 5, width: (tableColumn?.width ?? 0) - 10, height: 20))
            textField.stringValue = "\(port.port)"
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textField.textColor = .labelColor
            cellView.addSubview(textField)
            
        case "process":
            let textField = NSTextField(frame: NSRect(x: 5, y: 5, width: (tableColumn?.width ?? 0) - 10, height: 20))
            textField.stringValue = port.processName
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .labelColor
            textField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(textField)
            
        case "pid":
            let textField = NSTextField(frame: NSRect(x: 5, y: 5, width: (tableColumn?.width ?? 0) - 10, height: 20))
            textField.stringValue = "\(port.pid)"
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            textField.textColor = .secondaryLabelColor
            cellView.addSubview(textField)
            
        case "action":
            let button = NSButton(frame: NSRect(x: 5, y: 2, width: 60, height: 24))
            button.title = localizedString("Kill")
            button.bezelStyle = .rounded
            button.font = NSFont.systemFont(ofSize: 11)
            button.tag = row
            button.target = self
            button.action = #selector(killButtonClicked(_:))
            cellView.addSubview(button)
            
        default:
            break
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return rowHeight
    }
}
