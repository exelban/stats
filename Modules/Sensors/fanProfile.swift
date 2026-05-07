//
//  fanProfile.swift
//  Sensors
//
//  Created for Stats fan profile engine.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

#if arch(arm64)

import Foundation

// A single point on the temperature→RPM curve.
public struct CurvePoint: Codable, Equatable {
    public var temperatureC: Double
    public var rpm: Int

    public init(temperatureC: Double, rpm: Int) {
        self.temperatureC = temperatureC
        self.rpm = rpm
    }
}

// A fan profile binding a curve to one fan (by id) or all fans (fanID == -1).
public struct FanProfile: Codable, Identifiable {
    public var id: UUID
    public var name: String
    // fanID == -1 means "all fans"
    public var fanID: Int
    // Curve points must be ordered ascending by temperatureC.
    public var points: [CurvePoint]

    public init(id: UUID = UUID(), name: String, fanID: Int, points: [CurvePoint]) {
        self.id = id
        self.name = name
        self.fanID = fanID
        self.points = points
    }

    // Whether this profile is currently controlling fans.
    // Stored in Store.shared so it survives restarts without rewriting the JSON.
    public var enabled: Bool {
        get { Store.shared.bool(key: "fanProfile_\(self.id.uuidString)_enabled", defaultValue: false) }
        set { Store.shared.set(key: "fanProfile_\(self.id.uuidString)_enabled", value: newValue) }
    }

    // Linear interpolation: given a temperature, return the target RPM.
    // Below the first point → first point's RPM. Above the last → last point's RPM.
    public func targetRPM(forTemperature temp: Double) -> Int {
        guard !points.isEmpty else { return 0 }
        let sorted = points.sorted { $0.temperatureC < $1.temperatureC }
        if temp <= sorted.first!.temperatureC { return sorted.first!.rpm }
        if temp >= sorted.last!.temperatureC  { return sorted.last!.rpm }

        for i in 0..<(sorted.count - 1) {
            let lo = sorted[i]
            let hi = sorted[i + 1]
            if temp >= lo.temperatureC && temp <= hi.temperatureC {
                let ratio = (temp - lo.temperatureC) / (hi.temperatureC - lo.temperatureC)
                return Int(Double(lo.rpm) + ratio * Double(hi.rpm - lo.rpm))
            }
        }
        return sorted.last!.rpm
    }
}

// MARK: - Built-in presets (templates the user can duplicate and edit)

public enum FanProfilePreset: CaseIterable {
    case silent, balanced, performance

    public var profile: FanProfile {
        switch self {
        case .silent:
            return FanProfile(
                name: "Silent",
                fanID: -1,
                points: [
                    CurvePoint(temperatureC: 40, rpm: 1200),
                    CurvePoint(temperatureC: 60, rpm: 1800),
                    CurvePoint(temperatureC: 75, rpm: 2800),
                    CurvePoint(temperatureC: 90, rpm: 4000)
                ]
            )
        case .balanced:
            return FanProfile(
                name: "Balanced",
                fanID: -1,
                points: [
                    CurvePoint(temperatureC: 40, rpm: 1500),
                    CurvePoint(temperatureC: 60, rpm: 2500),
                    CurvePoint(temperatureC: 75, rpm: 3500),
                    CurvePoint(temperatureC: 90, rpm: 5000)
                ]
            )
        case .performance:
            // Ramps aggressively from 50°C onward
            return FanProfile(
                name: "Performance",
                fanID: -1,
                points: [
                    CurvePoint(temperatureC: 40, rpm: 2000),
                    CurvePoint(temperatureC: 50, rpm: 3000),
                    CurvePoint(temperatureC: 65, rpm: 4500),
                    CurvePoint(temperatureC: 80, rpm: 6000)
                ]
            )
        }
    }
}

// MARK: - JSON persistence

// Profile bodies (curve data) live in a JSON file in Application Support.
// Enabled flags live in Store.shared so they round-trip through Stats' normal prefs.
public class FanProfileStore {
    private static let fileName = "fan-profiles.json"

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Stats")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent(fileName)
    }

    public static func load() -> [FanProfile] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([FanProfile].self, from: data)) ?? []
    }

    public static func save(_ profiles: [FanProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

#endif
