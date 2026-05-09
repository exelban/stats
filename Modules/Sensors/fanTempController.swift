//
//  fanTempController.swift
//  Sensors
//
//  Created by Morteza Rastgoo on 09/05/2026.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import IOKit.ps
import Kit

// MARK: - Power source

internal enum PowerSource {
    case ac, battery

    /// Reads the current power source directly from IOKit.
    static var current: PowerSource {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(info, ps).takeUnretainedValue() as? [String: Any],
               let state = desc[kIOPSPowerSourceStateKey] as? String {
                return state == kIOPSBatteryPowerValue ? .battery : .ac
            }
        }
        return .ac
    }
}

// MARK: - Controller settings model

/// Per-power-source configuration, persisted in Store.shared.
internal struct FanTempSettings {
    let storePrefix: String

    /// Whether the controller is active for this power source.
    var enabled: Bool {
        get { Store.shared.bool(key: "\(storePrefix)_enabled", defaultValue: false) }
        set { Store.shared.set(key: "\(storePrefix)_enabled", value: newValue) }
    }

    /// Target CPU temperature in °C (whole degrees, clamped to 30–85).
    var targetTemp: Int {
        get { Store.shared.int(key: "\(storePrefix)_targetTemp", defaultValue: 40) }
        set { Store.shared.set(key: "\(storePrefix)_targetTemp", value: max(30, min(85, newValue))) }
    }

    /// Upper bound for the proportional ramp: above this temp fans run at max speed.
    var maxTemp: Int {
        get { Store.shared.int(key: "\(storePrefix)_maxTemp", defaultValue: 85) }
        set { Store.shared.set(key: "\(storePrefix)_maxTemp", value: max(targetTemp + 5, min(95, newValue))) }
    }
}

// MARK: - Controller

/// Proportional fan speed controller driven by CPU temperature.
///
/// Architecture overview:
/// - `processTick(_:)` is called from `Sensors.usageCallback` on every sensor read.
/// - A 1 s gate prevents excessive SMC writes regardless of reader frequency.
/// - Fan speed is determined by a simple proportional ramp:
///     temp ≤ target  →  automatic mode (macOS controls fans)
///     target < temp ≤ maxTemp  →  linear interpolation between minSpeed and maxSpeed
///     temp > maxTemp  →  maxSpeed
/// - A 100 RPM hysteresis window suppresses SMC writes when the target is stable.
/// - Separate settings are stored for battery and AC adapter power sources.
/// - On app termination, `releaseAll(fans:)` restores automatic fan mode.
public class FanTempController {
    public static let shared = FanTempController()

    internal var acSettings    = FanTempSettings(storePrefix: "Sensors_FanTempCtrl_AC")
    internal var battSettings  = FanTempSettings(storePrefix: "Sensors_FanTempCtrl_Batt")

    // RPM hysteresis – skip SMC write if new target is within this delta of the last write.
    private let hysteresisRPM: Int = 100
    // Minimum interval between control actions, regardless of reader cadence.
    private let minTickInterval: TimeInterval = 1.0

    private var lastSetRPM: [Int: Int] = [:]          // [fanID: lastWrittenRPM]
    private var lastTickDate: Date = .distantPast
    private var fanBounds: [Int: (min: Double, max: Double)] = [:]
    private let queue = DispatchQueue(label: "eu.exelban.Stats.FanTempController", qos: .utility)

    private init() {}

    // MARK: - Public API

    /// Called once from `Sensors.init` after the sensor reader is ready, so we can
    /// clamp RPM targets to hardware min/max without re-reading sensors each tick.
    public func registerFans(_ fans: [Fan]) {
        queue.async {
            for fan in fans where fan.id >= 0 {
                self.fanBounds[fan.id] = (min: fan.minSpeed, max: fan.maxSpeed)
            }
        }
    }

    /// Called from `Sensors.usageCallback` on every sensor read.
    /// `sensors` is the full Sensors_List.sensors array from the reader callback.
    public func processTick(_ sensors: [Sensor_p]) {
        queue.async { [weak self] in
            guard let self else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastTickDate) >= self.minTickInterval else { return }
            self.lastTickDate = now

            let source = PowerSource.current
            let settings: FanTempSettings = source == .battery ? self.battSettings : self.acSettings
            guard settings.enabled else { return }
            guard SMCHelper.shared.isActive() else { return }

            // Drive off the max CPU temp to match hardware thermal behaviour.
            let cpuTemps = sensors.compactMap { s -> Double? in
                guard s.type == .temperature, s.group == .CPU else { return nil }
                return s.value > 5 ? s.value : nil   // ignore parked/offline cores near 0
            }
            guard let maxCPUTemp = cpuTemps.max() else { return }

            let fans = sensors.compactMap { $0 as? Fan }.filter { $0.id >= 0 }
            for fan in fans {
                let bounds = self.fanBounds[fan.id]
                let minRPM = bounds?.min ?? fan.minSpeed
                let maxRPM = bounds?.max ?? fan.maxSpeed
                let target = self.targetRPM(
                    temp: maxCPUTemp,
                    targetTemp: Double(settings.targetTemp),
                    maxTemp: Double(settings.maxTemp),
                    minRPM: minRPM,
                    maxRPM: maxRPM
                )

                if target < 0 {
                    // Below target temp — restore automatic control (only if we previously forced it).
                    if let prev = self.lastSetRPM[fan.id], prev >= 0 {
                        SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
                        self.lastSetRPM[fan.id] = -1
                    }
                } else {
                    let prev = self.lastSetRPM[fan.id] ?? -1
                    guard prev < 0 || abs(target - prev) >= self.hysteresisRPM else { continue }
                    if fan.mode.isAutomatic {
                        SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue)
                    }
                    SMCHelper.shared.setFanSpeed(fan.id, speed: target)
                    self.lastSetRPM[fan.id] = target
                }
            }
        }
    }

    /// Restores automatic fan mode for all controlled fans. Call from `willTerminate`.
    public func releaseAll(fans: [Fan]) {
        queue.sync {
            for fan in fans where fan.id >= 0 {
                if let prev = self.lastSetRPM[fan.id], prev >= 0 {
                    SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
                }
            }
            self.lastSetRPM.removeAll()
        }
    }

    /// Returns `true` if the controller is currently driving this fan.
    public func isControlling(fanID: Int) -> Bool {
        let settings: FanTempSettings = PowerSource.current == .battery ? battSettings : acSettings
        return settings.enabled && (lastSetRPM[fanID] ?? -1) >= 0
    }

    // MARK: - Private helpers

    /// Returns the target RPM for the given temperature, or -1 if temp ≤ targetTemp
    /// (meaning automatic mode should be used).
    private func targetRPM(temp: Double, targetTemp: Double, maxTemp: Double,
                           minRPM: Double, maxRPM: Double) -> Int {
        guard temp > targetTemp else { return -1 }
        let range = max(1, maxTemp - targetTemp)
        let ratio = min(1.0, (temp - targetTemp) / range)
        return Int(minRPM + ratio * (maxRPM - minRPM))
    }
}
