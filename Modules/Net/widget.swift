import SwiftUI
import WidgetKit
import Charts
import Kit

public struct Network_entry: TimelineEntry {
    public static let kind = "NetworkWidget"
    public static var snapshot: Network_entry = Network_entry(value: Network_Usage(
        bandwidth: Bandwidth(upload: 1_238_400, download: 18_732_000),
        raddr: Network_addr(v4: "192.168.0.1"),
        interface: Network_interface(displayName: "Stats"),
        status: true
    ))
    
    public var date: Date {
        Calendar.current.date(byAdding: .second, value: 5, to: Date())!
    }
    
    public var value: Network_Usage? = nil
}

@available(macOS 11.0, *)
public struct Provider: TimelineProvider {
    public typealias Entry = Network_entry
    
    private let userDefaults: UserDefaults? = UserDefaults(
        suiteName: "\(Bundle.main.object(forInfoDictionaryKey: "TeamId") as! String).eu.exelban.Stats.widgets"
    )
    
    public func placeholder(in context: Context) -> Network_entry {
        Network_entry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (Network_entry) -> Void) {
        completion(Network_entry.snapshot)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<Network_entry>) -> Void) {
        self.userDefaults?.set(Date().timeIntervalSince1970, forKey: Network_entry.kind)
        var entry = Network_entry()
        if let raw = userDefaults?.data(forKey: "Network@UsageReader"),
           let load = try? JSONDecoder().decode(Network_Usage.self, from: raw) {
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
                        // Download & Upload
                        HStack {
                            VStack {
                                VStack(spacing: 0) {
                                    Text(Units(bytes: value.bandwidth.download).getReadableTuple().0)
                                        .font(.system(size: 24, weight: .regular))
                                    Text(Units(bytes: value.bandwidth.download).getReadableTuple().1)
                                        .font(.system(size: 10, weight: .regular))
                                }
                                Text("Download")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                VStack(spacing: 0) {
                                    Text(Units(bytes: value.bandwidth.upload).getReadableTuple().0)
                                        .font(.system(size: 24, weight: .regular))
                                    Text(Units(bytes: value.bandwidth.upload).getReadableTuple().1)
                                        .font(.system(size: 10, weight: .regular))
                                }
                                Text("Upload")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: .infinity)
                        
                        // Details: Status, Interface, IP
                        VStack(spacing: 3) {
                            // Status
                            HStack {
                                Text("Status")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(value.status ? "UP" : "DOWN")
                            }
                            
                            // Interface
                            if let interface = value.interface {
                                HStack {
                                    Text("Interface")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(value.wifiDetails.ssid ?? interface.displayName)
                                }
                            }
                            
                            // IP + Flag
                            HStack {
                                Text("IP")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let flag = loadFlag(countryCode: value.raddr.countryCode) {
                                    flag
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 18, height: 12)
                                        .padding(.trailing, 4)
                                }
                                
                                if let raddr = value.raddr.v6 {
                                    Text(raddr)
                                        .font(.system(size: 8))
                                        .multilineTextAlignment(.trailing)
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
    
    private func loadFlag(countryCode: String?) -> Image? {
        guard let code = countryCode?.lowercased() else { return nil }
        
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        
        let url = appSupport
            .appendingPathComponent("Net/flags")
            .appendingPathComponent("\(code).png")
        
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        
        return Image(nsImage: nsImage)
    }
}