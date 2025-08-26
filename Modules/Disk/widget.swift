//
//  widget.swift
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 16/07/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI
import WidgetKit
import Charts
import Kit

public struct Disk_entry: TimelineEntry {
    public static let kind = "DiskWidget"
    public static var snapshot: Disk_entry = Disk_entry(value: drive(size: 494384795648, free: 251460125440))
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    public var value: drive? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = Disk_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(suiteName: "\(Bundle.main.object(forInfoDictionaryKey: "TeamId") as! String).eu.exelban.Stats.widgets")
    
    public func placeholder(in context: Context) -> Disk_entry {
        Disk_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (Disk_entry) -> Void) {
        completion(Disk_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<Disk_entry>) -> Void) {
        var entry = Disk_entry()
        if let raw = userDefaults?.data(forKey: "Disk@CapacityReader"), let load = try? JSONDecoder().decode(drive.self, from: raw) {
            entry.value = load
        }
        let entries: [Disk_entry] = [entry]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@available(macOS 14.0, *)
public struct DiskWidget: Widget {
    var usedColor: Color = Color(nsColor: NSColor.systemBlue)
    var freeColor: Color = Color(nsColor: NSColor.lightGray)
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Disk_entry.kind, provider: Provider()) { entry in
            VStack(spacing: 10) {
                if let value = entry.value {
                    HStack {
                        Chart {
                            SectorMark(angle: .value(localizedString("Used"), (100*(value.size-value.free))/value.size), innerRadius: .ratio(0.8)).foregroundStyle(self.usedColor)
                            SectorMark(angle: .value(localizedString("Free"), (100*value.free)/value.size), innerRadius: .ratio(0.8)).foregroundStyle(self.freeColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 84)
                        .chartLegend(.hidden)
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                if let anchor = chartProxy.plotFrame {
                                    let frame = geometry[anchor]
                                    Text("\(Int(value.percentage.rounded(toPlaces: 2) * 100))%")
                                        .font(.system(size: 16, weight: .regular))
                                        .position(x: frame.midX, y: frame.midY-5)
                                    Text("Disk")
                                        .font(.system(size: 9, weight: .semibold))
                                        .position(x: frame.midX, y: frame.midY+10)
                                }
                            }
                        }
                    }
                    VStack(spacing: 3) {
                        HStack {
                            Rectangle().fill(self.usedColor).frame(width: 12, height: 12).cornerRadius(2)
                            Text(localizedString("Used")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text(DiskSize(value.size - value.free).getReadableMemory())
                        }
                        HStack {
                            Rectangle().fill(self.freeColor).frame(width: 12, height: 12).cornerRadius(2)
                            Text(localizedString("Free")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text(DiskSize(value.free).getReadableMemory())
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
        .configurationDisplayName("Disk widget")
        .description("Displays disk stats")
        .supportedFamilies([.systemSmall])
    }
}
