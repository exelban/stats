//
//  popup.swift
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

internal class Popup: PopupWrapper {
    private let orderTableView: OrderTableView = OrderTableView()
    private var list: [Clock_t] = []
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orderTableView.reorderCallback = { [weak self] in
            self?.rearrange()
        }
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.margins
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func callback(_ list: [Clock_t]) {
        defer {
            let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
            if h > 0 && self.frame.size.height != h {
                self.setFrameSize(NSSize(width: self.frame.width, height: h))
                self.sizeCallback?(self.frame.size)
            }
        }
        
        var sorted = list.sorted(by: { $0.popupIndex < $1.popupIndex })
        var views = self.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        
        if sorted.count != self.orderTableView.list.count {
            self.orderTableView.list = sorted
            self.orderTableView.update()
        }
        
        sorted = sorted.filter({ $0.popupState })
        
        if sorted.count < views.count && !views.isEmpty {
            views.forEach{ $0.removeFromSuperview() }
            views = []
        }
        
        sorted.forEach { (c: Clock_t) in
            if let view = views.first(where: { $0.clock.id == c.id }) {
                view.update(c)
            } else {
                self.addArrangedSubview(ClockView(width: self.frame.width, clock: c))
            }
        }
        
        self.list = sorted
    }
    
    override func settings() -> NSView? {
        let view = SettingsContainerView()
        view.addArrangedSubview(self.orderTableView)
        return view
    }
    
    private func rearrange() {
        let views = self.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        views.forEach{ $0.removeFromSuperview() }
        self.callback(self.list)
    }
}

private class ClockView: NSStackView {
    public var clock: Clock_t
    
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.bounds.width, height: self.bounds.height)
    }
    
    private var ready: Bool = false
    
    private let clockView: ClockChart = ClockChart(frame: CGRect(x: 0, y: 0, width: 34, height: 34))
    private let nameField: NSTextField = TextView()
    private let timeField: NSTextField = TextView()
    
    init(width: CGFloat, clock: Clock_t) {
        self.clock = clock
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 44))
        
        self.orientation = .horizontal
        self.spacing = 5
        self.edgeInsets = NSEdgeInsets(
            top: 5,
            left: 5,
            bottom: 5,
            right: 5
        )
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.clockView.widthAnchor.constraint(equalToConstant: 34).isActive = true
        
        let container: NSStackView = NSStackView()
        container.orientation = .vertical
        container.spacing = 2
        container.distribution = .fillEqually
        container.alignment = .left
        
        self.nameField.font = NSFont.systemFont(ofSize: 11, weight: .light)
        self.setTZ()
        self.nameField.cell?.truncatesLastVisibleLine = true
        
        self.timeField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        self.timeField.stringValue = clock.formatted()
        self.timeField.cell?.truncatesLastVisibleLine = true
        
        container.addArrangedSubview(self.nameField)
        container.addArrangedSubview(self.timeField)
        
        self.addArrangedSubview(self.clockView)
        self.addArrangedSubview(container)
        
        self.update(clock)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (isDarkMode ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25) : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)).cgColor
    }
    
    private func setTZ() {
        self.nameField.stringValue = "\(self.clock.name)"
        if let tz = Clock.zones.first(where: { $0.key == self.clock.tz }) {
            self.nameField.stringValue += " (\(tz.value))"
        }
    }
    
    public func update(_ newClock: Clock_t) {
        if self.clock.tz != newClock.tz {
            self.clock = newClock
            self.setTZ()
        }
        
        if (self.window?.isVisible ?? false) || !self.ready {
            self.timeField.stringValue = newClock.formatted()
            if let value = newClock.value {
                self.clockView.setValue(value.convertToTimeZone(TimeZone(fromUTC: newClock.tz)))
            }
            self.ready = true
        }
    }
}

internal class ClockChart: NSView {
    private var color: NSColor = SColor.systemAccent.additional as! NSColor
    
    private let calendar = Calendar.current
    private var hour: Int = 0
    private var minute: Int = 0
    private var second: Int = 0
    
    private let hourLayer = CALayer()
    private let minuteLayer = CALayer()
    private let secondsLayer = CALayer()
    private let pinLayer = CAShapeLayer()
    
    override init(frame: CGRect = NSRect.zero) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.setFillColor(self.color.cgColor)
        context.fillEllipse(in: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        context.restoreGState()
        
        let anchor = CGPoint(x: 0.5, y: 0)
        let center = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
        
        let hourAngle: CGFloat = CGFloat(Double(hour) * (360.0 / 12.0)) + CGFloat(Double(minute) * (1.0 / 60.0) * (360.0 / 12.0))
        let minuteAngle: CGFloat = CGFloat(minute) * CGFloat(360.0 / 60.0)
        let secondsAngle: CGFloat = CGFloat(self.second) * CGFloat(360.0 / 60.0)
        
        self.hourLayer.backgroundColor = NSColor.white.cgColor
        self.hourLayer.anchorPoint = anchor
        self.hourLayer.position = center
        self.hourLayer.bounds = CGRect(x: 0, y: 0, width: 3, height: self.frame.size.width / 2 - 7)
        self.hourLayer.transform = CATransform3DMakeRotation(-hourAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.hourLayer)
        
        self.minuteLayer.backgroundColor = NSColor.white.cgColor
        self.minuteLayer.anchorPoint = anchor
        self.minuteLayer.position = center
        self.minuteLayer.bounds = CGRect(x: 0, y: 0, width: 2, height: self.frame.size.width / 2 - 4)
        self.minuteLayer.transform = CATransform3DMakeRotation(-minuteAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.minuteLayer)
        
        self.secondsLayer.backgroundColor = NSColor.red.cgColor
        self.secondsLayer.anchorPoint = anchor
        self.secondsLayer.position = center
        self.secondsLayer.bounds = CGRect(x: 0, y: 0, width: 1, height: self.frame.size.width / 2 - 2)
        self.secondsLayer.transform = CATransform3DMakeRotation(-secondsAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.secondsLayer)
        
        self.pinLayer.fillColor = NSColor.white.cgColor
        self.pinLayer.anchorPoint = anchor
        self.pinLayer.path = CGMutablePath(roundedRect: CGRect(
            x: center.x - 3 / 2,
            y: center.y - 3 / 2,
            width: 3,
            height: 3
        ), cornerWidth: 4, cornerHeight: 4, transform: nil)
        self.layer?.addSublayer(self.pinLayer)
    }
    
    public func setValue(_ value: Date) {
        self.hour = self.calendar.component(.hour, from: value)
        self.minute = self.calendar.component(.minute, from: value)
        self.second = self.calendar.component(.second, from: value)
        
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}

private class OrderTableView: NSView, NSTableViewDelegate, NSTableViewDataSource {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "\(Bundle.main.bundleIdentifier!).sensors-row")
    
    public var reorderCallback: () -> Void = {}
    public var list: [Clock_t] = []
    
    init() {
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
        self.tableView.backgroundColor = NSColor.clear
        self.tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        self.tableView.registerForDraggedTypes([dragDropType])
        self.tableView.gridColor = .gridColor
        self.tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        if #available(macOS 11.0, *) {
            self.tableView.style = .plain
        }
        
        let nameColumn = NSTableColumn(identifier: nameColumnID)
        nameColumn.headerCell.title = localizedString("Name")
        nameColumn.headerCell.alignment = .center
        let statusColumn = NSTableColumn(identifier: statusColumnID)
        statusColumn.headerCell.title = ""
        statusColumn.width = 16
        
        self.tableView.addTableColumn(nameColumn)
        self.tableView.addTableColumn(statusColumn)
        
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
        return self.list.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if !self.list.indices.contains(row) { return nil }
        let item = self.list[row]
        
        let cell = NSTableCellView()
        
        switch tableColumn?.identifier {
        case nameColumnID: 
            let text: NSTextField = NSTextField()
            text.drawsBackground = false
            text.isBordered = false
            text.isEditable = false
            text.isSelectable = false
            text.translatesAutoresizingMaskIntoConstraints = false
            text.identifier = NSUserInterfaceItemIdentifier(item.name)
            text.stringValue = item.name
            
            text.sizeToFit()
            
            cell.addSubview(text)
            
            NSLayoutConstraint.activate([
                text.widthAnchor.constraint(equalTo: cell.widthAnchor),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        case statusColumnID:
            let button: NSButton = NSButton(frame: NSRect(x: 0, y: 5, width: 10, height: 10))
            button.identifier = NSUserInterfaceItemIdentifier("\(row)")
            button.setButtonType(.switch)
            button.state = item.popupState ? .on : .off
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
                
                self.list[currentIdx].popupIndex = newIdx
                self.list[newIdx].popupIndex = currentIdx
                
                oldIndexOffset -= 1
            } else {
                let currentIdx = oldIndex
                let newIdx = row + newIndexOffset
                
                self.list[currentIdx].popupIndex = newIdx
                self.list[newIdx].popupIndex = currentIdx
                
                newIndexOffset += 1
            }
            self.list = self.list.sorted(by: { $0.popupIndex < $1.popupIndex })
            self.reorderCallback()
            tableView.reloadData()
        }
        tableView.endUpdates()
        
        return true
    }
    
    @objc private func toggleClock(_ sender: NSButton) {
        guard let id = sender.identifier, let i = Int(id.rawValue) else { return }
        self.list[i].popupState = sender.state == NSControl.StateValue.on
    }
}
