//
//  widget.swift
//  RAM
//
//  Created by Serhiy Mytrovtsiy on 03/07/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI
import WidgetKit
import Charts
import Kit

public struct RAM_entry: TimelineEntry {
    public static let kind = "RAMWidget"
    public static var snapshot: RAM_entry = RAM_entry()
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    public var value: RAM_Usage? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = RAM_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(suiteName: "eu.exelban.Stats.widgets")
    
    public func placeholder(in context: Context) -> RAM_entry {
        RAM_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (RAM_entry) -> Void) {
        completion(RAM_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<RAM_entry>) -> Void) {
        var entry = RAM_entry()
        if let raw = userDefaults?.data(forKey: "RAM@UsageReader"), let load = try? JSONDecoder().decode(RAM_Usage.self, from: raw) {
            entry.value = load
        }
        let entries: [RAM_entry] = [entry]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@available(macOS 14.0, *)
public struct RAMWidget: Widget {
    var usedColor: Color = Color(nsColor: NSColor.systemBlue)
    var freeColor: Color = Color(nsColor: NSColor.lightGray)
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: RAM_entry.kind, provider: Provider()) { entry in
            VStack(spacing: 10) {
                if let value = entry.value {
                    HStack {
                        Chart {
                            SectorMark(angle: .value(localizedString("Used"), value.used/value.total), innerRadius: .ratio(0.8)).foregroundStyle(self.usedColor)
                            SectorMark(angle: .value(localizedString("Free"), 1-(value.used/value.total)), innerRadius: .ratio(0.8)).foregroundStyle(self.freeColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 84)
                        .chartLegend(.hidden)
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                if let anchor = chartProxy.plotFrame {
                                    let frame = geometry[anchor]
                                    Text("\(Int((value.used/value.total)*100))%")
                                        .font(.system(size: 16, weight: .regular))
                                        .position(x: frame.midX, y: frame.midY)
                                }
                            }
                        }
                    }
                    VStack(spacing: 3) {
                        HStack {
                            Rectangle().fill(self.usedColor).frame(width: 12, height: 12).cornerRadius(2)
                            Text(localizedString("Used")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text(Units(bytes: Int64(value.used)).getReadableMemory())
                        }
                        HStack {
                            Rectangle().fill(self.freeColor).frame(width: 12, height: 12).cornerRadius(2)
                            Text(localizedString("Free")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text(Units(bytes: Int64(value.free)).getReadableMemory())
                        }
                        HStack {
                            Text(localizedString("Pressure level")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(value.rawPressureLevel)")
                        }
                    }
                } else {
                    Text("No data")
                }
            }
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
        .configurationDisplayName("RAM widget")
        .description("Displays RAM stats")
        .supportedFamilies([.systemSmall])
    }
}
