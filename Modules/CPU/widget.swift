//
//  widget.swift
//  CPU
//
//  Created by Serhiy Mytrovtsiy on 01/07/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI
import WidgetKit
import Charts
import Kit

public struct CPU_entry: TimelineEntry {
    public static let kind = "CPUWidget"
    public static var snapshot: CPU_entry = CPU_entry(value: CPU_Load(totalUsage: 0.34, systemLoad: 0.11, userLoad: 0.23, idleLoad: 0.66))
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    public var value: CPU_Load? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = CPU_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(suiteName: "\(Bundle.main.object(forInfoDictionaryKey: "TeamId") as! String).eu.exelban.Stats.widgets")
    
    public func placeholder(in context: Context) -> CPU_entry {
        CPU_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (CPU_entry) -> Void) {
        completion(CPU_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<CPU_entry>) -> Void) {
        self.userDefaults?.set(Date().timeIntervalSince1970, forKey: CPU_entry.kind)
        var entry = CPU_entry()
        if let raw = self.userDefaults?.data(forKey: "CPU@LoadReader"), let load = try? JSONDecoder().decode(CPU_Load.self, from: raw) {
            entry.value = load
        }
        let entries: [CPU_entry] = [entry]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@available(macOS 14.0, *)
public struct CPUWidget: Widget {
    var systemColor: Color = Color(nsColor: NSColor.systemRed)
    var userColor: Color = Color(nsColor: NSColor.systemBlue)
    var idleColor: Color = Color(nsColor: NSColor.lightGray)
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: CPU_entry.kind, provider: Provider()) { entry in
            VStack(spacing: 10) {
                if let value = entry.value {
                    HStack {
                        Chart {
                            SectorMark(angle: .value(localizedString("System"), value.systemLoad), innerRadius: .ratio(0.8)).foregroundStyle(self.systemColor)
                            SectorMark(angle: .value(localizedString("User"), value.userLoad), innerRadius: .ratio(0.8)).foregroundStyle(self.userColor)
                            SectorMark(angle: .value(localizedString("Idle"), value.idleLoad), innerRadius: .ratio(0.8)).foregroundStyle(self.idleColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 84)
                        .chartLegend(.hidden)
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                if let anchor = chartProxy.plotFrame {
                                    let frame = geometry[anchor]
                                    Text("\(Int(value.totalUsage*100))%")
                                        .font(.system(size: 16, weight: .regular))
                                        .position(x: frame.midX, y: frame.midY-5)
                                    Text("CPU")
                                        .font(.system(size: 9, weight: .semibold))
                                        .position(x: frame.midX, y: frame.midY+10)
                                }
                            }
                        }
                    }
                    VStack(spacing: 3) {
                        HStack {
                            Rectangle().fill(self.systemColor).frame(width: 12, height: 12).cornerRadius(2)
                            Text(localizedString("System")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(value.systemLoad*100))%")
                        }
                        HStack {
                            Rectangle().fill(self.userColor).frame(width: 12, height: 12).cornerRadius(2)
                            Text(localizedString("User")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(value.userLoad*100))%")
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
        .configurationDisplayName("CPU widget")
        .description("Displays CPU stats")
        .supportedFamilies([.systemSmall])
    }
}
