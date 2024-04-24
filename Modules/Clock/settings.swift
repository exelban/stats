//
//  settings.swift
//  Clock
//
//  Created by Serhiy Mytrovtsiy on 24/03/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

let nameColumnID = NSUserInterfaceItemIdentifier(rawValue: "name")
let formatColumnID = NSUserInterfaceItemIdentifier(rawValue: "format")
let tzColumnID = NSUserInterfaceItemIdentifier(rawValue: "tz")
let statusColumnID = NSUserInterfaceItemIdentifier(rawValue: "status")

internal class Settings: NSStackView, Settings_v, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    public var callback: (() -> Void) = {}
    
    private var list: [Clock_t] {
        get {
            if let objects = Store.shared.data(key: "\(self.title)_list") {
                let decoder = JSONDecoder()
                if let objectsDecoded = try? decoder.decode(Array.self, from: objects) as [Clock_t] {
                    return objectsDecoded
                }
            }
            return [Clock.local]
        }
        set {
            if newValue.isEmpty {
                Store.shared.remove("\(self.title)_list")
            } else {
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(newValue){
                    Store.shared.set(key: "\(self.title)_list", value: encoded)
                }
            }
        }
    }
    
    private var title: String
    private var selectedRow: Int = -1
    
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var footerView: NSStackView? = nil
    private var deleteButton: NSButton? = nil
    
    public init(_ module: ModuleType) {
        self.title = module.rawValue
        
        super.init(frame: NSRect.zero)
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.spacing = 0
        
        self.scrollView.documentView = self.tableView
        self.scrollView.hasHorizontalScroller = false
        self.scrollView.hasVerticalScroller = true
        self.scrollView.autohidesScrollers = true
        self.scrollView.backgroundColor = NSColor.clear
        self.scrollView.drawsBackground = true
        
        self.tableView.frame = self.scrollView.bounds
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = false
        self.tableView.focusRingType = .none
        self.tableView.gridColor = .gridColor
        self.tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        self.tableView.allowsColumnResizing = false
        self.tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        self.tableView.usesAlternatingRowBackgroundColors = true
        if #available(macOS 11.0, *) {
            self.tableView.style = .plain
        }
        self.tableView.rowHeight = 27
        
        let nameColumn = NSTableColumn(identifier: nameColumnID)
        nameColumn.headerCell.title = localizedString("Name")
        nameColumn.headerCell.alignment = .center
        let formatColumn = NSTableColumn(identifier: formatColumnID)
        formatColumn.headerCell.title = localizedString("Format")
        formatColumn.headerCell.alignment = .center
        formatColumn.width = 160
        let tzColumn = NSTableColumn(identifier: tzColumnID)
        tzColumn.headerCell.title = localizedString("Time zone")
        tzColumn.headerCell.alignment = .center
        tzColumn.width = 132
        let statusColumn = NSTableColumn(identifier: statusColumnID)
        statusColumn.headerCell.title = ""
        statusColumn.width = 16
        
        self.tableView.addTableColumn(nameColumn)
        self.tableView.addTableColumn(formatColumn)
        self.tableView.addTableColumn(tzColumn)
        self.tableView.addTableColumn(statusColumn)
        
        let separator = NSBox()
        separator.boxType = .separator
        
        self.addArrangedSubview(self.scrollView)
        self.addArrangedSubview(separator)
        self.addArrangedSubview(self.footer())
        
        NSLayoutConstraint.activate([
            self.scrollView.heightAnchor.constraint(equalToConstant: 296)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func footer() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: 27).isActive = true
        view.spacing = 4
        view.orientation = .horizontal
        
        var addButton: NSButton {
            let btn = NSButton()
            btn.widthAnchor.constraint(equalToConstant: 27).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 27).isActive = true
            btn.bezelStyle = .rounded
            if #available(macOS 11.0, *) {
                btn.image =  iconFromSymbol(name: "plus", scale: .medium)
            } else {
                btn.title = localizedString("Add")
            }
            btn.action = #selector(self.addNewClock)
            btn.target = self
            btn.toolTip = localizedString("Add new clock")
            btn.focusRingType = .none
            return btn
        }
        var deleteButton: NSButton {
            let btn = NSButton()
            btn.widthAnchor.constraint(equalToConstant: 27).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 27).isActive = true
            btn.bezelStyle = .rounded
            if #available(macOS 11.0, *) {
                btn.image =  iconFromSymbol(name: "minus", scale: .medium)
            } else {
                btn.title = localizedString("Delete")
            }
            btn.action = #selector(self.deleteClock)
            btn.target = self
            btn.toolTip = localizedString("Delete selected clock")
            btn.focusRingType = .none
            return btn
        }
        self.deleteButton = deleteButton
        
        view.addArrangedSubview(addButton)
        view.addArrangedSubview(NSView())
        
        let helpBtn = NSButton()
        helpBtn.widthAnchor.constraint(equalToConstant: 27).isActive = true
        helpBtn.heightAnchor.constraint(equalToConstant: 27).isActive = true
        helpBtn.bezelStyle = .helpButton
        helpBtn.title = ""
        helpBtn.action = #selector(self.openFormatHelp)
        helpBtn.target = self
        helpBtn.toolTip = localizedString("Help with datetime format")
        view.addArrangedSubview(helpBtn)
        
        self.footerView = view
        return view
    }
    
    func load(widgets: [Kit.widget_t]) {
        self.tableView.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.list.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier else { return nil }
        let cell = NSTableCellView()
        let item = self.list[row]
        
        switch id {
        case nameColumnID, formatColumnID:
            let text: NSTextField = NSTextField()
            text.identifier = id
            text.drawsBackground = false
            text.isBordered = false
            text.sizeToFit()
            text.delegate = self
            text.stringValue = id == nameColumnID ? item.name : item.format
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            text.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
        case tzColumnID:
            let select: NSPopUpButton = selectView(action: #selector(self.toggleTZ), items: Clock.zones, selected: item.tz)
            select.identifier = NSUserInterfaceItemIdentifier("\(row)")
            select.sizeToFit()
            cell.addSubview(select)
        case statusColumnID:
            let button: NSButton = NSButton(frame: NSRect(x: 0, y: 5, width: 10, height: 10))
            button.identifier = NSUserInterfaceItemIdentifier("\(row)")
            button.setButtonType(.switch)
            button.state = item.enabled ? .on : .off
            button.action = #selector(self.toggleClock)
            button.title = ""
            button.isBordered = false
            button.isTransparent = false
            button.target = self
            button.sizeToFit()
            cell.addSubview(button)
        default: break
        }
        
        return cell
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField, let id = textField.identifier {
            let i = self.tableView.selectedRow
            switch id {
            case nameColumnID:
                self.list[i].name = textField.stringValue
            case formatColumnID:
                self.list[i].format = textField.stringValue
            default: return
            }
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if self.tableView.selectedRow == -1 {
            self.deleteButton?.removeFromSuperview()
        } else {
            if let btn = self.deleteButton {
                self.footerView?.insertArrangedSubview(btn, at: 1)
            }
        }
    }
    
    @objc private func toggleTZ(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, let id = sender.identifier, let i = Int(id.rawValue) else { return }
        self.list[i].tz = key
    }
    @objc private func toggleClock(_ sender: NSButton) {
        guard let id = sender.identifier, let i = Int(id.rawValue) else { return }
        self.list[i].enabled = sender.state == NSControl.StateValue.on
    }
    @objc private func addNewClock(_ sender: Any) {
        self.list.append(Clock_t(name: "Clock \(self.list.count)", format: Clock.local.format, tz: Clock.local.tz))
        self.tableView.reloadData()
    }
    @objc private func deleteClock(_ sender: Any) {
        guard self.tableView.selectedRow != -1 else { return }
        self.list.remove(at: self.tableView.selectedRow)
        self.tableView.reloadData()
        self.deleteButton?.removeFromSuperview()
    }
    @objc private func openFormatHelp(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://www.nsdateformatter.com")!)
    }
}
