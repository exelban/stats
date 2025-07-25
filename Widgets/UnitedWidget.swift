//
//  UnitedWidget.swift
//  WidgetsExtension
//
//  Created by Serhiy Mytrovtsiy on 22/07/2025.
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import SwiftUI
import WidgetKit

import CPU
import GPU
import RAM
import Disk

public struct Value {
    public var value: Double = 0
    public var color: Color = Color(nsColor: .controlAccentColor)
}

public struct United_entry: TimelineEntry {
    public static let kind = "UnitedWidget"
    public static var snapshot: United_entry = United_entry()
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    
    public var cpu: Value? = nil
    public var gpu: Value? = nil
    public var ram: Value? = nil
    public var disk: Value? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = United_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(suiteName: "\(Bundle.main.object(forInfoDictionaryKey: "TeamId") as! String).eu.exelban.Stats.widgets")
    
    public func placeholder(in context: Context) -> United_entry {
        United_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (United_entry) -> Void) {
        completion(United_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<United_entry>) -> Void) {
        var entry = United_entry()
        if let raw = userDefaults?.data(forKey: "CPU@LoadReader"), let value = try? JSONDecoder().decode(CPU_Load.self, from: raw) {
            entry.cpu = Value(value: value.totalUsage)
        }
        if let raw = userDefaults?.bool(forKey: "CPU_state"), !raw {
            entry.cpu = nil
        }
        
        if let raw = userDefaults?.data(forKey: "GPU@InfoReader"), let value = try? JSONDecoder().decode(GPU_Info.self, from: raw) {
            entry.gpu = Value(value: value.utilization ?? 0)
        }
        if let raw = userDefaults?.bool(forKey: "GPU_state"), !raw {
            entry.gpu = nil
        }
        
        if let raw = userDefaults?.data(forKey: "RAM@UsageReader"), let value = try? JSONDecoder().decode(RAM_Usage.self, from: raw) {
            entry.ram = Value(value: value.usage)
        }
        if let raw = userDefaults?.bool(forKey: "RAM_state"), !raw {
            entry.ram = nil
        }
        
        if let raw = userDefaults?.data(forKey: "Disk@CapacityReader"), let value = try? JSONDecoder().decode(drive.self, from: raw) {
            entry.disk = Value(value: value.percentage)
        }
        if let raw = userDefaults?.bool(forKey: "Disk_state"), !raw {
            entry.disk = nil
        }
        
        let entries: [United_entry] = [entry]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@available(macOS 14.0, *)
public struct UnitedWidget: Widget {
    public init() {}
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: United_entry.kind, provider: Provider()) { entry in
            let values: [(String, Double, Color)] = [
                entry.cpu.map { ("CPU", $0.value, $0.color) },
                entry.gpu.map { ("GPU", $0.value, $0.color) },
                entry.ram.map { ("RAM", $0.value, $0.color) },
                entry.disk.map { ("Disk", $0.value, $0.color) }
            ].compactMap { $0 }
            
            VStack {
                if values.isEmpty {
                    Text("No data available")
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(values.indices, id: \.self) { index in
                            let item = values[index]
                            CircularGaugeView(title: item.0, progress: item.1, color: item.2)
                        }
                        ForEach(values.count..<4, id: \.self) { _ in
                            Color.clear
                                .frame(width: 60, height: 60)
                        }
                    }
                }
            }
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
        .configurationDisplayName("United widget")
        .description("Displays CPU/GPU/RAM/Disk stats")
        .supportedFamilies([.systemSmall])
    }
    
}

struct CircularGaugeView: View {
    var title: String
    var progress: Double
    var color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: self.progress)
                .stroke(self.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: self.progress)
            VStack(spacing: 0) {
                Text(self.title).font(.system(size: 10))
                Text("\(Int(self.progress * 100))%").font(.system(size: 12))
            }
        }
        .frame(width: 60, height: 60)
    }
}
