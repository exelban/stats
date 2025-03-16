//
//  main.swift
//  Clock
//
//  Created by Serhiy Mytrovtsiy on 23/03/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import Kit

public struct Clock_t: Codable {
    public var id: String = UUID().uuidString
    public var enabled: Bool = true
    
    public var name: String
    public var format: String
    public var tzKey: String
    
    public var value: Date? = nil
    
    var popupIndex: Int {
        get {
            Store.shared.int(key: "clock_\(self.id)_popupIndex", defaultValue: -1)
        }
        set {
            Store.shared.set(key: "clock_\(self.id)_popupIndex", value: newValue)
        }
    }
    var popupState: Bool {
        get {
            Store.shared.bool(key: "clock_\(self.id)_popupState", defaultValue: true)
        }
        set {
            Store.shared.set(key: "clock_\(self.id)_popupState", value: newValue)
        }
    }
    
    public func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = self.format
        formatter.timeZone = TimeZone(fromKey: self.tzKey)
        return formatter.string(from: self.value ?? Date())
    }
}

internal class ClockReader: Reader<Date> {
    public override func read() {
        self.callback(Date())
    }
}

public class Clock: Module {
    private let popupView: Popup = Popup(.clock)
    private let portalView: Portal
    private let settingsView: Settings = Settings(.clock)
    
    private var reader: ClockReader?
    
    static var list: [Clock_t] {
        if let objects = Store.shared.data(key: "\(ModuleType.clock.stringValue)_list") {
            let decoder = JSONDecoder()
            if let objectsDecoded = try? decoder.decode(Array.self, from: objects) as [Clock_t] {
                return objectsDecoded
            }
        }
        return [Clock.local]
    }
    
    public init() {
        self.portalView = Portal(.clock, list: Clock.list)
        
        super.init(
            moduleType: .clock,
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView
        )
        guard self.available else { return }
        
        self.reader = ClockReader(.clock) { [weak self] value in
            self?.callback(value)
        }
        
        self.setReaders([self.reader])
    }
    
    private func callback(_ value: Date?) {
        guard let value else { return }
        
        var clocks: [Clock_t] = Clock.list
        var widgetList: [Stack_t] = []
        
        for (i, c) in clocks.enumerated() {
            clocks[i].value = value
            if c.enabled {
                widgetList.append(Stack_t(key: c.name, value: clocks[i].formatted()))
            }
        }
        
        DispatchQueue.main.async(execute: {
            self.popupView.callback(clocks)
            self.portalView.callback(clocks)
        })
        
        self.menuBar.widgets.filter{ $0.isActive }.forEach { (w: SWidget) in
            switch w.item {
            case let widget as StackWidget: widget.setValues(widgetList)
            default: break
            }
        }
    }
}

extension Clock {
    static let localID: String = UUID().uuidString
    static var local: Clock_t {
        Clock_t(id: Clock.localID, name: localizedString("Local time"), format: "yyyy-MM-dd HH:mm:ss", tzKey: "local")
    }
    static var zones: [KeyValue_t] {
        [
            KeyValue_t(key: "local", value: "Local"),
            KeyValue_t(key: "separator", value: "separator"),
        ] + TimeZone.knownTimeZoneIdentifiers.map {
            KeyValue_t(key: $0, value: $0)
        } + [
            KeyValue_t(key: "separator", value: "separator"),
            KeyValue_t(key: TimeZone(fromUTC: "-12").identifier, value: "UTC-12:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-11").identifier, value: "UTC-11:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-10").identifier, value: "UTC-10:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-9").identifier, value: "UTC-9:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-8").identifier, value: "UTC-8:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-7").identifier, value: "UTC-7:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-6").identifier, value: "UTC-6:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-5").identifier, value: "UTC-5:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-4:30").identifier, value: "UTC-4:30"),
            KeyValue_t(key: TimeZone(fromUTC: "-4").identifier, value: "UTC-4:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-3:30").identifier, value: "UTC-3:30"),
            KeyValue_t(key: TimeZone(fromUTC: "-3").identifier, value: "UTC-3:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-2").identifier, value: "UTC-2:00"),
            KeyValue_t(key: TimeZone(fromUTC: "-1").identifier, value: "UTC-1:00"),
            KeyValue_t(key: TimeZone(fromUTC: "0").identifier, value: "UTC"),
            KeyValue_t(key: TimeZone(fromUTC: "1").identifier, value: "UTC+1:00"),
            KeyValue_t(key: TimeZone(fromUTC: "2").identifier, value: "UTC+2:00"),
            KeyValue_t(key: TimeZone(fromUTC: "3").identifier, value: "UTC+3:00"),
            KeyValue_t(key: TimeZone(fromUTC: "3:30").identifier, value: "UTC+3:30"),
            KeyValue_t(key: TimeZone(fromUTC: "4").identifier, value: "UTC+4:00"),
            KeyValue_t(key: TimeZone(fromUTC: "4:30").identifier, value: "UTC+4:30"),
            KeyValue_t(key: TimeZone(fromUTC: "5").identifier, value: "UTC+5:00"),
            KeyValue_t(key: TimeZone(fromUTC: "5:30").identifier, value: "UTC+5:30"),
            KeyValue_t(key: TimeZone(fromUTC: "5:45").identifier, value: "UTC+5:45"),
            KeyValue_t(key: TimeZone(fromUTC: "6").identifier, value: "UTC+6:00"),
            KeyValue_t(key: TimeZone(fromUTC: "6:30").identifier, value: "UTC+6:30"),
            KeyValue_t(key: TimeZone(fromUTC: "7").identifier, value: "UTC+7:00"),
            KeyValue_t(key: TimeZone(fromUTC: "8").identifier, value: "UTC+8:00"),
            KeyValue_t(key: TimeZone(fromUTC: "9").identifier, value: "UTC+9:00"),
            KeyValue_t(key: TimeZone(fromUTC: "9:30").identifier, value: "UTC+9:30"),
            KeyValue_t(key: TimeZone(fromUTC: "10").identifier, value: "UTC+10:00"),
            KeyValue_t(key: TimeZone(fromUTC: "10:30").identifier, value: "UTC+10:30"),
            KeyValue_t(key: TimeZone(fromUTC: "11").identifier, value: "UTC+11:00"),
            KeyValue_t(key: TimeZone(fromUTC: "12").identifier, value: "UTC+12:00"),
            KeyValue_t(key: TimeZone(fromUTC: "13").identifier, value: "UTC+13:00"),
            KeyValue_t(key: TimeZone(fromUTC: "14").identifier, value: "UTC+14:00")
        ]
    }
}
