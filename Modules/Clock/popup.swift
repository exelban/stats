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
    
    private var calendarView: CalendarView? = nil
    private var calendarState: Bool = true
    
    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 0))
        
        self.orientation = .vertical
        self.spacing = Constants.Popup.margins
        
        self.calendarView = CalendarView(self.frame.width)
        self.calendarState = Store.shared.bool(key: "\(self.title)_calendar", defaultValue: self.calendarState)
        
        self.orderTableView.reorderCallback = { [weak self] in
            self?.rearrange()
        }
        
        if let calendar = self.calendarView, self.calendarState {
            self.addArrangedSubview(calendar)
        }
        
        self.recalculateHeight()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func callback(_ list: [Clock_t]) {
        defer { self.recalculateHeight() }
        
        var sorted = list.sorted(by: { $0.popupIndex < $1.popupIndex })
        var views = self.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        
        if sorted.count != self.orderTableView.list.count || self.orderTableView.window?.isVisible ?? false {
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
    
    private func recalculateHeight() {
        let h = self.arrangedSubviews.map({ $0.bounds.height + self.spacing }).reduce(0, +) - self.spacing
        if h > 0 && self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Keyboard shortcut"), component: KeyboardShartcutView(
                callback: self.setKeyboardShortcut,
                value: self.keyboardShortcut
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Calendar"), component: switchView(
                action: #selector(self.toggleCalendarState),
                state: self.calendarState
            ))
        ]))
        
        view.addArrangedSubview(self.orderTableView)
        
        return view
    }
    
    public override func appear() {
        if self.calendarState {
            self.calendarView?.checkCurrentDay()
        }
    }
    
    private func rearrange() {
        let views = self.subviews.filter{ $0 is ClockView }.compactMap{ $0 as? ClockView }
        views.forEach{ $0.removeFromSuperview() }
        self.callback(self.list)
    }
    
    @objc private func toggleCalendarState(_ sender: NSControl) {
        self.calendarState = controlState(sender)
        Store.shared.set(key: "\(self.title)_calendar", value: self.calendarState)
        
        guard let view = self.calendarView else { return }
        if self.calendarState {
            self.insertArrangedSubview(view, at: 0)
        } else {
            view.removeFromSuperview()
        }
        self.recalculateHeight()
    }
}

private class CalendarView: NSStackView {
    private let itemSize: CGSize
    
    private var year: Int
    private var month: Int
    private var day: Int
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    private var currentDay: Int {
        Calendar.current.component(.day, from: Date())
    }
    
    private var weekDays: [String] {
        let calendar = Calendar.current
        let firstWeekdayIndex = calendar.firstWeekday - 1
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.calendar = calendar
        let weekdaySymbols = dateFormatter.shortWeekdaySymbols
        return Array(weekdaySymbols![firstWeekdayIndex...]) + weekdaySymbols![..<firstWeekdayIndex]
    }
    
    private var grid: NSGridView = NSGridView()
    private var current: NSTextField = NSTextField()
    
    init(_ width: CGFloat) {
        self.itemSize = NSSize(
            width: (width-(Constants.Popup.margins*2))/7,
            height: (width-(Constants.Popup.spacing*2))/8 - 4
        )
        self.year = Calendar.current.component(.year, from: Date())
        self.month = Calendar.current.component(.month, from: Date())
        self.day = Calendar.current.component(.day, from: Date())
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: width - 32))
        self.setAccessibilityElement(true)
        self.toolTip = localizedString("Calendar")
        
        self.spacing = 0
        self.orientation = .vertical
        self.edgeInsets = .init(
            top: Constants.Popup.spacing,
            left: Constants.Popup.margins,
            bottom: Constants.Popup.spacing,
            right: Constants.Popup.margins
        )
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
        
        self.addArrangedSubview(self.navigation())
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func checkCurrentDay() {
        guard self.day != self.currentDay || self.month != self.currentMonth || self.year != self.currentYear else { return }
        
        self.year = self.currentYear
        self.month = self.currentMonth
        self.day = self.currentDay
        
        self.setup()
    }
    
    override func updateLayer() {
        self.layer?.backgroundColor = (isDarkMode ? NSColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 0.25) : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)).cgColor
    }
    
    private func setup() {
        self.grid.removeFromSuperview()
        
        let grid = NSGridView()
        grid.rowSpacing = 0
        grid.columnSpacing = 0
        grid.addRow(with: self.weekDays.map { headerItem($0) })
          
        let weeks = self.generateDays(for: self.month, in: self.year)
        for week in weeks {
            let labels = week.map { rowItem($0) }
            grid.addRow(with: labels)
        }
        
        self.grid = grid
        self.current.stringValue = "\(Calendar.current.standaloneMonthSymbols[self.month-1]) \(self.year)"
        
        self.addArrangedSubview(grid)
    }
    
    private func navigation() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: self.itemSize.height).isActive = true
        view.orientation = .horizontal
        
        let details = NSTextField(labelWithString: "\(Calendar.current.standaloneMonthSymbols[self.month-1]) \(self.year)")
        details.font = .systemFont(ofSize: 16, weight: .medium)
        self.current = details
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        
        let prev = NSButton()
        prev.bezelStyle = .regularSquare
        prev.translatesAutoresizingMaskIntoConstraints = false
        prev.imageScaling = .scaleNone
        if #available(macOS 11.0, *) {
            prev.image = iconFromSymbol(name: "arrow.left", scale: .medium)!
        } else {
            prev.title = "<"
        }
        prev.contentTintColor = .labelColor
        prev.isBordered = false
        prev.action = #selector(self.prevMonth)
        prev.target = self
        prev.toolTip = localizedString("Previous month")
        prev.focusRingType = .none
        
        let next = NSButton()
        next.bezelStyle = .regularSquare
        next.translatesAutoresizingMaskIntoConstraints = false
        next.imageScaling = .scaleNone
        if #available(macOS 11.0, *) {
            next.image = iconFromSymbol(name: "arrow.right", scale: .medium)!
        } else {
            next.title = ">"
        }
        next.contentTintColor = .labelColor
        next.isBordered = false
        next.action = #selector(self.nextMonth)
        next.target = self
        next.toolTip = localizedString("Next month")
        next.focusRingType = .none
        
        buttons.addArrangedSubview(prev)
        buttons.addArrangedSubview(next)
        
        view.addArrangedSubview(details)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(buttons)
        
        return view
    }
    
    private func headerItem(_ value: String) -> NSView {
        let view = NSTextField()
        let cell = VerticallyCenteredTextFieldCell(textCell: value)
        view.cell = cell
        view.alignment = .center
        view.textColor = .gray
        view.font = .systemFont(ofSize: 12)
        view.widthAnchor.constraint(equalToConstant: self.itemSize.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: self.itemSize.height).isActive = true
        return view
    }
    
    private func rowItem(_ day: DateComponents) -> NSView {
        if day.year == self.currentYear && day.month == self.currentMonth && day.day == self.currentDay {
            return self.todayItem()
        }
        let view = NSTextField()
        let cell = VerticallyCenteredTextFieldCell(textCell: "\(day.day ?? 0)")
        view.cell = cell
        view.alignment = .center
        if day.month != self.month {
            view.textColor = .lightGray
        }
        
        view.widthAnchor.constraint(equalToConstant: self.itemSize.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: self.itemSize.height).isActive = true
        return view
    }
    
    private func todayItem() -> NSView {
        let view = NSView()
        
        let size: CGFloat = 25
        let circle = NSView(frame: NSRect(x: (self.itemSize.width-size)/2, y: (self.itemSize.height-size)/2, width: size, height: size))
        circle.wantsLayer = true
        circle.layer?.backgroundColor = NSColor.systemRed.cgColor
        circle.layer?.cornerRadius = size/2
        
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        let cell = VerticallyCenteredTextFieldCell(textCell: "\(self.currentDay)")
        field.cell = cell
        field.alignment = .center
        field.textColor = .white
        
        view.addSubview(circle)
        view.addSubview(field)
        
        view.widthAnchor.constraint(equalToConstant: self.itemSize.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: self.itemSize.height).isActive = true
        field.widthAnchor.constraint(equalToConstant: self.itemSize.width).isActive = true
        field.heightAnchor.constraint(equalToConstant: self.itemSize.height).isActive = true
        return view
    }
    
    private func generateDays(for month: Int, in year: Int) -> [[DateComponents]] {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        
        guard let range = calendar.range(of: .day, in: .month, for: calendar.date(from: dateComponents)!),
              let firstDayOfMonth = calendar.date(from: dateComponents),
              let firstWeekdayOfMonth = calendar.dateComponents([.weekday], from: firstDayOfMonth).weekday else {
            return []
        }
        
        let localeFirstWeekday = calendar.firstWeekday
        let daysFromPreviousMonth = (firstWeekdayOfMonth - localeFirstWeekday + 7) % 7
        
        var previousMonthComponents = dateComponents
        previousMonthComponents.month = (month == 1) ? 12 : month - 1
        previousMonthComponents.year = (month == 1) ? year - 1 : year
        
        let previousMonthDate = calendar.date(from: previousMonthComponents)!
        let previousMonthRange = calendar.range(of: .day, in: .month, for: previousMonthDate)!
        let lastDayOfPreviousMonth = previousMonthRange.upperBound - 1
        
        var nextMonthComponents = dateComponents
        nextMonthComponents.month = (month == 12) ? 1 : month + 1
        nextMonthComponents.year = (month == 12) ? year + 1 : year
        
        var weeks = [[DateComponents]]()
        var currentWeek = [DateComponents]()
        let validDaysFromPreviousMonth = min(daysFromPreviousMonth, lastDayOfPreviousMonth)
        if validDaysFromPreviousMonth > 0 {
            for day in (lastDayOfPreviousMonth - validDaysFromPreviousMonth + 1)...lastDayOfPreviousMonth {
                var components = previousMonthComponents
                components.day = day
                currentWeek.append(components)
            }
        }
        
        for day in range {
            var components = dateComponents
            components.day = day
            currentWeek.append(components)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        
        var nextMonthDay = 1
        while currentWeek.count < 7 {
            var components = nextMonthComponents
            components.day = nextMonthDay
            currentWeek.append(components)
            nextMonthDay += 1
        }
        weeks.append(currentWeek)
        
        if weeks.count < 6 {
            currentWeek = []
            for _ in 1...7 {
                var components = nextMonthComponents
                components.day = nextMonthDay
                currentWeek.append(components)
                nextMonthDay += 1
            }
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    @objc private func prevMonth() {
        self.month -= 1
        if self.month < 1 {
            self.month = 12
            self.year -= 1
        }
        self.setup()
    }
    @objc private func nextMonth() {
        self.month += 1
        if self.month > 12 {
            self.month = 1
            self.year += 1
        }
        self.setup()
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
        self.setAccessibilityElement(true)
        self.toolTip = "\(clock.name): \(clock.formatted())"
        
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
        if let tz = Clock.zones.first(where: { $0.key == self.clock.tz }), tz.key != "local" {
            self.nameField.stringValue += " (\(tz.value))"
        }
    }
    
    public func update(_ newClock: Clock_t) {
        if self.clock.tz != newClock.tz || self.clock.name != newClock.name {
            self.clock = newClock
            self.setTZ()
        }
        
        if (self.window?.isVisible ?? false) || !self.ready {
            self.timeField.stringValue = newClock.formatted()
            if let value = newClock.value {
                self.clockView.setValue(value.convertToTimeZone(TimeZone(from: newClock.tz)))
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
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.setStrokeColor((isDarkMode ? NSColor.darkGray : NSColor.lightGray).cgColor)
        context.setLineWidth(1)
        context.addEllipse(in: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        context.drawPath(using: .fillStroke)
        context.restoreGState()
        
        let anchor = CGPoint(x: 0.5, y: 0)
        let center = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
        
        let hourAngle: CGFloat = CGFloat(Double(hour) * (360.0 / 12.0)) + CGFloat(Double(minute) * (1.0 / 60.0) * (360.0 / 12.0))
        let minuteAngle: CGFloat = CGFloat(minute) * CGFloat(360.0 / 60.0)
        let secondsAngle: CGFloat = CGFloat(self.second) * CGFloat(360.0 / 60.0)
        
        self.hourLayer.backgroundColor = NSColor.labelColor.cgColor
        self.hourLayer.anchorPoint = anchor
        self.hourLayer.position = center
        self.hourLayer.cornerRadius = 2
        self.hourLayer.bounds = CGRect(x: 0, y: 0, width: 2, height: self.frame.size.width / 2 - 4)
        self.hourLayer.transform = CATransform3DMakeRotation(-hourAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.hourLayer)
        
        self.minuteLayer.backgroundColor = NSColor.secondaryLabelColor.cgColor
        self.minuteLayer.anchorPoint = anchor
        self.minuteLayer.position = center
        self.minuteLayer.cornerRadius = 2
        self.minuteLayer.bounds = CGRect(x: 0, y: 0, width: 2, height: self.frame.size.width / 2 - 2)
        self.minuteLayer.transform = CATransform3DMakeRotation(-minuteAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.minuteLayer)
        
        self.secondsLayer.backgroundColor = NSColor.red.cgColor
        self.secondsLayer.anchorPoint = anchor
        self.secondsLayer.position = center
        self.secondsLayer.cornerRadius = 1
        self.secondsLayer.bounds = CGRect(x: 0, y: 0, width: 1, height: self.frame.size.width / 2 - 1)
        self.secondsLayer.transform = CATransform3DMakeRotation(-secondsAngle / 180 * CGFloat(Double.pi), 0, 0, 1)
        self.layer?.addSublayer(self.secondsLayer)
        
        self.pinLayer.fillColor = NSColor.controlBackgroundColor.cgColor
        self.pinLayer.strokeColor = (isDarkMode ? NSColor.darkGray : NSColor.lightGray).cgColor
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
