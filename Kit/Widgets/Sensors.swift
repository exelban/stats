//
//  Sensors.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

private struct Sensor_t: KeyValue_p {
    let key: String
    let name: String?
    
    var value: String
    var additional: Any?
    
    var index: Int {
        get {
            return Store.shared.int(key: "sensors_\(self.key)_index", defaultValue: -1)
        }
        set {
            Store.shared.set(key: "sensors_\(self.key)_index", value: newValue)
        }
    }
    
    init(key: String, value: String, name: String? = nil) {
        self.key = key
        self.value = value
        self.name = name
    }
}

public class SensorsWidget: WidgetWrapper {
    private var modeState: String = "automatic"
    private var fixedSizeState: Bool = false
    private var values: [Sensor_t] = []
    
    private var oneRowWidth: CGFloat = 36
    private var twoRowWidth: CGFloat = 26
    
    private let orderTableView: OrderTableView
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Values"] as? String {
                        for (i, value) in value.split(separator: ",").enumerated() {
                            self.values.append(Sensor_t(key: "\(i)", value: String(value)))
                        }
                    }
                }
            }
        }
        
        self.orderTableView = OrderTableView(&self.values)
        
        super.init(.sensors, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        if !preview {
            self.modeState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState)
            self.fixedSizeState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_size", defaultValue: self.fixedSizeState)
        }
        
        self.orderTableView.reorderCallback = { [weak self] in
            self?.display()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !self.values.isEmpty else {
            self.setWidth(1)
            return
        }
        
        let num: Int = Int(round(Double(self.values.count) / 2))
        var totalWidth: CGFloat = Constants.Widget.spacing  // opening space
        var x: CGFloat = Constants.Widget.spacing
        
        var i = 0
        while i < self.values.count {
            switch self.modeState {
            case "automatic", "twoRows":
                let firstSensor: Sensor_t = self.values[i]
                let secondSensor: Sensor_t? = self.values.indices.contains(i+1) ? self.values[i+1] : nil
                
                var width: CGFloat = 0
                if self.modeState == "automatic" && secondSensor == nil {
                    width += self.drawOneRow(firstSensor, x: x)
                } else {
                    width += self.drawTwoRows(topSensor: firstSensor, bottomSensor: secondSensor, x: x)
                }
                
                x += width
                totalWidth += width
                
                if num != 1 && (i/2) != num {
                    x += Constants.Widget.spacing
                    totalWidth += Constants.Widget.spacing
                }
                
                i += 1
            case "oneRow":
                let width = self.drawOneRow(self.values[i], x: x)
                
                x += width
                totalWidth += width
                
                // add margins between columns
                if self.values.count != 1 && i != self.values.count {
                    x += Constants.Widget.spacing
                    totalWidth += Constants.Widget.spacing
                }
            default: break
            }
            
            i += 1
        }
        totalWidth += Constants.Widget.spacing // closing space
        
        if abs(self.frame.width - totalWidth) < 2 {
            return
        }
        self.setWidth(totalWidth)
    }
    
    private func drawOneRow(_ sensor: Sensor_t, x: CGFloat) -> CGFloat {
        let font: NSFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        var width: CGFloat = self.oneRowWidth
        if !self.fixedSizeState {
            width = sensor.value.widthOfString(usingFont: font).rounded(.up) + 2
        }
        
        let rect = CGRect(x: x, y: (Constants.Widget.height-13)/2, width: width, height: 13)
        let str = NSAttributedString.init(string: sensor.value, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ])
        str.draw(with: rect)
        
        return width
    }
    
    private func drawTwoRows(topSensor: Sensor_t, bottomSensor: Sensor_t?, x: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = self.frame.height / 2
        
        let font: NSFont = NSFont.systemFont(ofSize: 10, weight: .light)
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        var width: CGFloat = self.twoRowWidth
        if !self.fixedSizeState {
            let firstRowWidth = topSensor.value.widthOfString(usingFont: font)
            let secondRowWidth = bottomSensor?.value.widthOfString(usingFont: font) ?? 0
            width = max(20, max(firstRowWidth, secondRowWidth)).rounded(.up) + 2
        }
        
        var rect = CGRect(x: x, y: rowHeight+1, width: width, height: rowHeight)
        var str = NSAttributedString.init(string: topSensor.value, attributes: attributes)
        str.draw(with: rect)
        
        if bottomSensor != nil {
            rect = CGRect(x: x, y: 1, width: width, height: rowHeight)
            str = NSAttributedString.init(string: bottomSensor!.value, attributes: attributes)
            str.draw(with: rect)
        }
        
        return width
    }
    
    public func setValues(_ values: [KeyValue_t]) {
        var tableNeedsToBeUpdated: Bool = false
        
        values.forEach { (p: KeyValue_t) in
            if let idx = self.values.firstIndex(where: { $0.key == p.key }) {
                self.values[idx].value = p.value
                return
            }
            tableNeedsToBeUpdated = true
            self.values.append(Sensor_t(key: p.key, value: p.value, name: p.additional as? String))
        }
        
        let diff = self.values.filter({ v in values.contains(where: { $0.key == v.key }) })
        if diff.count != self.values.count {
            tableNeedsToBeUpdated = true
        }
        self.values = diff.sorted(by: { $0.index < $1.index })
        
        DispatchQueue.main.async(execute: {
            if tableNeedsToBeUpdated {
                self.orderTableView.update()
            }
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(selectSettingsRow(
            title: localizedString("Display mode"),
            action: #selector(changeMode),
            items: SensorsWidgetMode,
            selected: self.modeState
        ))
        
        view.addArrangedSubview(toggleSettingRow(
            title: localizedString("Static width"),
            action: #selector(toggleSize),
            state: self.fixedSizeState
        ))
        
        view.addArrangedSubview(self.orderTableView)
        
        return view
    }
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }
        self.modeState = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
    }
    
    @objc private func toggleSize(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        self.fixedSizeState = state! == .on ? true : false
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_size", value: self.fixedSizeState)
        self.display()
    }
}

private class OrderTableView: NSView, NSTableViewDelegate, NSTableViewDataSource {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "\(Bundle.main.bundleIdentifier!).sensors-row")
    
    public var reorderCallback: () -> Void = {}
    private let list: UnsafeMutablePointer<[Sensor_t]>
    
    init(_ list: UnsafeMutablePointer<[Sensor_t]>) {
        self.list = list
        
        super.init(frame: NSRect.zero)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.documentView = self.tableView
        self.scrollView.hasHorizontalScroller = false
        self.scrollView.hasVerticalScroller = true
        self.scrollView.autohidesScrollers = true
        self.scrollView.backgroundColor = NSColor.clear
        self.scrollView.drawsBackground = true
        
        self.tableView.frame = self.scrollView.bounds
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.headerView = nil
        self.tableView.backgroundColor = NSColor.clear
        self.tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        self.tableView.registerForDraggedTypes([dragDropType])
        self.tableView.gridColor = .gridColor
        self.tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        if #available(macOS 11.0, *) {
            self.tableView.style = .plain
        }
        
        let colKey = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "key"))
        colKey.width = 50
        let colName = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
        
        self.tableView.addTableColumn(colName)
        self.tableView.addTableColumn(colKey)
        
        self.addSubview(self.scrollView)
        
        NSLayoutConstraint.activate([
            self.scrollView.leftAnchor.constraint(equalTo: self.leftAnchor),
            self.scrollView.rightAnchor.constraint(equalTo: self.rightAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            self.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func update() {
        self.tableView.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return list.pointee.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if !self.list.pointee.indices.contains(row) { return nil }
        let item = self.list.pointee[row]
        
        let text: NSTextField = NSTextField()
        text.drawsBackground = false
        text.isBordered = false
        text.isEditable = false
        text.isSelectable = false
        text.translatesAutoresizingMaskIntoConstraints = false
        text.identifier = NSUserInterfaceItemIdentifier(item.key)
        
        switch tableColumn?.identifier.rawValue {
        case "key":
            text.stringValue = item.key
        case "name":
            text.stringValue = "\(item.name ?? localizedString("Unknown"))"
        default: break
        }
        
        text.sizeToFit()
        
        let cell = NSTableCellView()
        cell.addSubview(text)
        
        NSLayoutConstraint.activate([
            text.widthAnchor.constraint(equalTo: cell.widthAnchor),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                oldIndexes.append(index)
            }
        }
        
        var oldIndexOffset = 0
        var newIndexOffset = 0
        
        tableView.beginUpdates()
        for oldIndex in oldIndexes {
            if oldIndex < row {
                let currentIdx = oldIndex + oldIndexOffset
                let newIdx = row - 1
                
                self.list.pointee[currentIdx].index = newIdx
                self.list.pointee[newIdx].index = currentIdx
                
                oldIndexOffset -= 1
            } else {
                let currentIdx = oldIndex
                let newIdx = row + newIndexOffset
                
                self.list.pointee[currentIdx].index = newIdx
                self.list.pointee[newIdx].index = currentIdx
                
                newIndexOffset += 1
            }
            self.list.pointee = self.list.pointee.sorted(by: { $0.index < $1.index })
            self.reorderCallback()
            tableView.reloadData()
        }
        tableView.endUpdates()
        
        return true
    }
}
