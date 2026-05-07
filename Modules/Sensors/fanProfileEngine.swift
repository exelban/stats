//
//  fanProfileEngine.swift
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
import Kit

// Minimum RPM delta before we issue a new setFanSpeed call.
// Prevents constant SMC writes when the temperature hovers around a curve knee.
private let hysteresisThreshold: Int = 100

// Cap how often the engine acts on a temperature tick regardless of how fast
// the sensor reader fires.
private let minTickInterval: TimeInterval = 1.0

public class FanProfileEngine {
    public static let shared = FanProfileEngine()

    private var profiles: [FanProfile] = []
    // Last RPM written to each fan id, used for hysteresis.
    private var lastSetRPM: [Int: Int] = [:]
    private var lastTickDate: Date = .distantPast
    private let queue = DispatchQueue(label: "eu.exelban.Stats.FanProfileEngine", qos: .utility)

    // Fan min/max bounds populated when the sensor list is available, so we can
    // clamp RPM to hardware limits without reaching back to the sensor reader.
    // TODO: per-fan minSpeed/maxSpeed — currently clamped to 0…maxSpeed from
    //       the first fan seen; multi-fan machines may have different ranges.
    private var fanBounds: [Int: (min: Double, max: Double)] = [:]

    private init() {
        self.profiles = FanProfileStore.load()
    }

    // MARK: - Public API

    public var allProfiles: [FanProfile] { profiles }

    public func profileForFan(_ fanID: Int) -> FanProfile? {
        profiles.first(where: { $0.enabled && ($0.fanID == fanID || $0.fanID == -1) })
    }

    public func addProfile(_ profile: FanProfile) {
        profiles.append(profile)
        FanProfileStore.save(profiles)
    }

    public func updateProfile(_ profile: FanProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        FanProfileStore.save(profiles)
    }

    public func removeProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        // Clean up the enabled key from Store.
        Store.shared.remove("fanProfile_\(id.uuidString)_enabled")
        FanProfileStore.save(profiles)
    }

    // Called by main.swift once the sensor list is known.
    public func registerFans(_ fans: [Fan]) {
        for fan in fans {
            fanBounds[fan.id] = (min: fan.minSpeed, max: fan.maxSpeed)
        }
    }

    // Called from the sensor reader callback in main.swift on every tick.
    // sensors: the full Sensors_List.sensors array from the reader callback.
    public func processTick(_ sensors: [Sensor_p]) {
        queue.async { [weak self] in
            guard let self else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastTickDate) >= minTickInterval else { return }

            let enabledProfiles = self.profiles.filter { $0.enabled }
            guard !enabledProfiles.isEmpty else { return }

            // Use the average of all CPU temperature sensors as the driving signal.
            // TODO: expose sensor key selection per-profile if the maintainer wants
            //       per-fan source selection (e.g. GPU temp for a dedicated GPU fan).
            let cpuTemps = sensors
                .filter { $0.type == .temperature && $0.group == .CPU && $0.value > 0 }
                .map { $0.value }
            guard !cpuTemps.isEmpty else { return }
            let avgTemp = cpuTemps.reduce(0, +) / Double(cpuTemps.count)

            self.lastTickDate = now

            let fans = sensors.compactMap { $0 as? Fan }
            for fan in fans {
                guard let profile = self.profileForFan(fan.id) else { continue }
                let target = profile.targetRPM(forTemperature: avgTemp)
                let bounds = self.fanBounds[fan.id]
                let minRPM = Int(bounds?.min ?? 0)
                let maxRPM = bounds.map { Int($0.max) } ?? target
                let clamped = max(minRPM, min(maxRPM == 0 ? target : maxRPM, target))

                if let last = self.lastSetRPM[fan.id], abs(clamped - last) < hysteresisThreshold { continue }

                self.lastSetRPM[fan.id] = clamped
                SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue)
                SMCHelper.shared.setFanSpeed(fan.id, speed: clamped)
            }
        }
    }

    public func releaseAll(fans: [Fan]) {
        queue.async {
            for fan in fans {
                guard self.lastSetRPM[fan.id] != nil else { continue }
                SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
            }
            self.lastSetRPM = [:]
        }
    }
}

#endif
