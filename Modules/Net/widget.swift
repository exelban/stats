//
//  widget.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 30/07/2024
//  Using Swift 5.0
//  Running on macOS 14.5
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//  

import SwiftUI
import WidgetKit
import Charts
import Kit

public struct Network_entry: TimelineEntry {
    public static let kind = "NetworkWidget"
    public static var snapshot: Network_entry = Network_entry()
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    public var value: Network_Usage? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = Network_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(suiteName: "eu.exelban.Stats.widgets")
    
    public func placeholder(in context: Context) -> Network_entry {
        Network_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (Network_entry) -> Void) {
        completion(Network_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<Network_entry>) -> Void) {
        var entry = Network_entry()
        if let raw = userDefaults?.data(forKey: "Network@UsageReader"), let load = try? JSONDecoder().decode(Network_Usage.self, from: raw) {
            entry.value = load
        }
        let entries: [Network_entry] = [entry]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

@available(macOS 14.0, *)
public struct NetworkWidget: Widget {
    private var downloadColor: Color = Color(nsColor: NSColor.systemBlue)
    private var uploadColor: Color = Color(nsColor: NSColor.systemRed)
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Network_entry.kind, provider: Provider()) { entry in
            VStack(spacing: 10) {
                if let value = entry.value {
                    VStack {
                        HStack {
                            VStack {
                                VStack(spacing: 0) {
                                    Text(Units(bytes: value.bandwidth.download).getReadableTuple().0).font(.system(size: 24, weight: .regular))
                                    Text(Units(bytes: value.bandwidth.download).getReadableTuple().1).font(.system(size: 10, weight: .regular))
                                }
                                Text("Download").font(.system(size: 12, weight: .regular)).foregroundColor(.gray)
                            }.frame(maxWidth: .infinity)
                            VStack {
                                VStack(spacing: 0) {
                                    Text(Units(bytes: value.bandwidth.upload).getReadableTuple().0).font(.system(size: 24, weight: .regular))
                                    Text(Units(bytes: value.bandwidth.upload).getReadableTuple().1).font(.system(size: 10, weight: .regular))
                                }
                                Text("Upload").font(.system(size: 12, weight: .regular)).foregroundColor(.gray)
                            }.frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: .infinity)
                        VStack(spacing: 3) {
                            HStack {
                                Text("Status").font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                                Spacer()
                                Text(value.status ? "UP" : "DOWN")
                            }
                            if let interface = value.interface {
                                HStack {
                                    Text("Interface").font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                                    Spacer()
                                    Text(value.wifiDetails.ssid ?? interface.displayName)
                                }
                            }
                            HStack {
                                Text("IP").font(.system(size: 12, weight: .regular)).foregroundColor(.secondary)
                                Spacer()
                                if let raddr = value.raddr.v6 {
                                    Text(raddr)
                                        .font(.system(size: 8))
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else if let raddr = value.raddr.v4 {
                                    Text(raddr)
                                } else {
                                    Text("Unknown")
                                }
                            }
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
        .configurationDisplayName("Network widget")
        .description("Displays network stats")
        .supportedFamilies([.systemSmall])
    }
}
