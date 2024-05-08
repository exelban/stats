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

public struct Stack_t: KeyValue_p {
    public var key: String
    public var value: String
    
    var index: Int {
        get {
            Store.shared.int(key: "stack_\(self.key)_index", defaultValue: -1)
        }
        set {
            Store.shared.set(key: "stack_\(self.key)_index", value: newValue)
        }
    }
    
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public class StackWidget: WidgetWrapper {
    private var modeState: StackMode = .auto
    private var fixedSizeState: Bool = false
    private var monospacedFontState: Bool = false
    
    private var values: [Stack_t] = []
    
    private var oneRowWidth: CGFloat = 38
    private var twoRowWidth: CGFloat = 28
    
    private let orderTableView: OrderTableView
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if let config, preview {
            if let previewConfig = config["Preview"] as? NSDictionary {
                if let value = previewConfig["Values"] as? String {
                    for (i, value) in value.split(separator: ",").enumerated() {
                        self.values.append(Stack_t(key: "\(i)", value: String(value)))
                    }
                }
            }
        }
        
        self.orderTableView = OrderTableView(&self.values)
        
        super.init(.stack, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width,
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        if !preview {
            self.modeState = StackMode(rawValue: Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_mode", defaultValue: self.modeState.rawValue)) ?? .auto
            self.fixedSizeState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_size", defaultValue: self.fixedSizeState)
            self.monospacedFontState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_monospacedFont", defaultValue: self.monospacedFontState)
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
            self.setWidth(0)
            return
        }
        
        let num: Int = Int(round(Double(self.values.count) / 2))
        var totalWidth: CGFloat = Constants.Widget.spacing  // opening space
        var x: CGFloat = Constants.Widget.spacing
        
        var i = 0
        while i < self.values.count {
            switch self.modeState {
            case .auto, .twoRows:
                let firstElement: Stack_t = self.values[i]
                let secondElement: Stack_t? = self.values.indices.contains(i+1) ? self.values[i+1] : nil
                
                var width: CGFloat = 0
                if self.modeState == .auto && secondElement == nil {
                    width += self.drawOneRow(x, firstElement)
                } else {
                    width += self.drawTwoRows(x, firstElement, secondElement)
                }
                
                x += width
                totalWidth += width
                
                if num != 1 && (i/2) != num {
                    x += Constants.Widget.spacing
                    totalWidth += Constants.Widget.spacing
                }
                
                i += 1
            case .oneRow:
                let width = self.drawOneRow(x, self.values[i])
                
                x += width
                totalWidth += width
                
                // add margins between columns
                if self.values.count != 1 && i != self.values.count {
                    x += Constants.Widget.spacing
                    totalWidth += Constants.Widget.spacing
                }
            }
            
            i += 1
        }
        totalWidth += Constants.Widget.spacing // closing space
        
        guard abs(self.frame.width - totalWidth) > 2 else { return }
        self.setWidth(totalWidth)
    }
    
    private func drawOneRow(_ x: CGFloat, _ element: Stack_t) -> CGFloat {
        var font: NSFont
        if self.monospacedFontState {
            font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            font = NSFont.systemFont(ofSize: 13, weight: .regular)
        }
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        var width: CGFloat = self.oneRowWidth
        if !self.fixedSizeState {
            width = element.value.widthOfString(usingFont: font).rounded(.up) + 2
        }
        
        let rect = CGRect(x: x, y: (Constants.Widget.height-13)/2, width: width, height: 13)
        let str = NSAttributedString.init(string: element.value, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ])
        str.draw(with: rect)
        
        return width
    }
    
    private func drawTwoRows(_ x: CGFloat, _ topElement: Stack_t, _ bottomElement: Stack_t?) -> CGFloat {
        let rowHeight: CGFloat = self.frame.height / 2
        
        var font: NSFont
        if self.monospacedFontState {
            font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .light)
        } else {
            font = NSFont.systemFont(ofSize: 10, weight: .light)
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        
        var width: CGFloat = self.twoRowWidth
        if !self.fixedSizeState {
            let firstRowWidth = topElement.value.widthOfString(usingFont: font)
            let secondRowWidth = bottomElement?.value.widthOfString(usingFont: font) ?? 0
            width = max(20, max(firstRowWidth, secondRowWidth)).rounded(.up) + 2
        }
        
        var rect = CGRect(x: x, y: rowHeight+1, width: width, height: rowHeight)
        var str = NSAttributedString.init(string: topElement.value, attributes: attributes)
        str.draw(with: rect)
        
        if bottomElement != nil {
            rect = CGRect(x: x, y: 1, width: width, height: rowHeight)
            str = NSAttributedString.init(string: bottomElement!.value, attributes: attributes)
            str.draw(with: rect)
        }
        
        return width
    }
    
    public func setValues(_ values: [Stack_t]) {
        var tableNeedsToBeUpdated: Bool = false
        
        values.forEach { (p: Stack_t) in
            if let idx = self.values.firstIndex(where: { $0.key == p.key }) {
                self.values[idx].value = p.value
                return
            }
            tableNeedsToBeUpdated = true
            self.values.append(p)
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
            self.display()
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        var rows = [
            PreferencesRow(localizedString("Display mode"), component: selectView(
                action: #selector(self.changeDisplayMode),
                items: SensorsWidgetMode,
                selected: self.modeState.rawValue
            )),
            PreferencesRow(localizedString("Monospaced font"), component: switchView(
                action: #selector(self.toggleMonospacedFont),
                state: self.monospacedFontState
            ))
        ]
        if self.title != "Clock" {
            rows.append(PreferencesRow(localizedString("Static width"), component: switchView(
                action: #selector(self.toggleSize),
                state: self.fixedSizeState
            )))
        }
        view.addArrangedSubview(PreferencesSection(rows))
        
        view.addArrangedSubview(self.orderTableView)
        
        return view
    }
    
    @objc private func changeDisplayMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.modeState = StackMode(rawValue: key) ?? .auto
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_mode", value: key)
        self.display()
    }
    
    @objc private func toggleSize(_ sender: NSControl) {
        self.fixedSizeState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_size", value: self.fixedSizeState)
        self.display()
    }
    
    @objc private func toggleMonospacedFont(_ sender: NSControl) {
        self.monospacedFontState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_monospacedFont", value: self.monospacedFontState)
        self.display()
    }
}

private class OrderTableView: NSView, NSTableViewDelegate, NSTableViewDataSource {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "\(Bundle.main.bundleIdentifier!).sensors-row")
    
    fileprivate var reorderCallback: () -> Void = {}
    private let list: UnsafeMutablePointer<[Stack_t]>
    
    init(_ list: UnsafeMutablePointer<[Stack_t]>) {
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
        
        self.tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "name")))
        
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
    
    fileprivate func update() {
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
        case "name": text.stringValue = item.key
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
