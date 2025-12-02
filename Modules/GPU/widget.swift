//
//  widget.swift
//  GPU
//
//  Created by Serhiy Mytrovtsiy on 17/07/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI
import WidgetKit
import Charts
import Kit

public struct GPU_entry: TimelineEntry {
    public static let kind = "GPUWidget"
    public static var snapshot: GPU_entry = GPU_entry(value: GPU_Info(id: "", type: "", IOClass: "", model: "", cores: nil, utilization: 0.11, render: 0.11, tiler: 0.11))
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    public var value: GPU_Info? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = GPU_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(suiteName: "\(Bundle.main.object(forInfoDictionaryKey: "TeamId") as! String).eu.exelban.Stats.widgets")
    
    public func placeholder(in context: Context) -> GPU_entry {
        GPU_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (GPU_entry) -> Void) {
        completion(GPU_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<GPU_entry>) -> Void) {
        self.userDefaults?.set(Date().timeIntervalSince1970, forKey: GPU_entry.kind)
        var entry = GPU_entry()
        if let raw = userDefaults?.data(forKey: "GPU@InfoReader"), let load = try? JSONDecoder().decode(GPU_Info.self, from: raw) {
            entry.value = load
        }
        let entries: [GPU_entry] = [entry]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@available(macOS 14.0, *)
public struct GPUWidget: Widget {
    var usedColor: Color = Color(nsColor: NSColor.systemBlue)
    var freeColor: Color = Color(nsColor: NSColor.lightGray)
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: GPU_entry.kind, provider: Provider()) { entry in
            VStack(spacing: 10) {
                if let value = entry.value {
                    HStack {
                        Chart {
                            SectorMark(angle: .value(localizedString("Used"), value.utilization ?? 0), innerRadius: .ratio(0.8)).foregroundStyle(self.usedColor)
                            SectorMark(angle: .value(localizedString("Free"), 1-(value.utilization ?? 0)), innerRadius: .ratio(0.8)).foregroundStyle(self.freeColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 84)
                        .chartLegend(.hidden)
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                if let anchor = chartProxy.plotFrame {
                                    let frame = geometry[anchor]
                                    Text("\(Int((value.utilization ?? 0)*100))%")
                                        .font(.system(size: 14, weight: .regular))
                                        .position(x: frame.midX, y: frame.midY-5)
                                    Text("GPU")
                                        .font(.system(size: 8, weight: .semibold))
                                        .position(x: frame.midX, y: frame.midY+8)
                                }
                            }
                        }
                    }
                    VStack(spacing: 3) {
                        HStack {
                            Text(localizedString("Usage")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int((value.utilization ?? 0)*100))%")
                        }
                        HStack {
                            Text(localizedString("Render")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int((value.renderUtilization ?? 0)*100))%")
                        }
                        HStack {
                            Text(localizedString("Tiler")).font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int((value.tilerUtilization ?? 0)*100))%")
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
        .configurationDisplayName("GPU widget")
        .description("Displays GPU stats")
        .supportedFamilies([.systemSmall])
    }
}
