//
//  fanTempController.swift
//  Sensors
//
//  Created by Morteza Rastgoo on 09/05/2026.
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import IOKit.ps
import Kit

// MARK: - Power source

internal enum PowerSource {
    case ac, battery

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

// MARK: - Controller

/// Temperature-driven fan controller. Each fan independently opts in via setTempMode().
public class FanTempController {
    public static let shared = FanTempController()

    private let hysteresisRPM: Int = 100
    private let minTickInterval: TimeInterval = 1.0

    private var lastSetRPM: [Int: Int] = [:]        // fanID → last written RPM (-1 = auto)
    private var fanBounds: [Int: (min: Double, max: Double)] = [:]
    private let queue = DispatchQueue(label: "eu.exelban.Stats.FanTempController", qos: .utility)

    private init() {}

    // MARK: - Per-fan settings (stored in UserDefaults via Store)

    public func isTempMode(fanID: Int) -> Bool {
        Store.shared.bool(key: "Sensors_Fan_\(fanID)_tempMode", defaultValue: false)
    }

    public func setTempMode(fanID: Int, _ enabled: Bool) {
        Store.shared.set(key: "Sensors_Fan_\(fanID)_tempMode", value: enabled)
        if !enabled {
            // Release SMC control immediately when leaving temp mode
            queue.async {
                if let prev = self.lastSetRPM[fanID], prev >= 0 {
                    SMCHelper.shared.setFanMode(fanID, mode: FanMode.automatic.rawValue)
                    self.lastSetRPM[fanID] = -1
                }
            }
        }
    }

    public func acTarget(fanID: Int) -> Int {
        Store.shared.int(key: "Sensors_Fan_\(fanID)_AC_target", defaultValue: 50)
    }

    public func setACTarget(fanID: Int, _ temp: Int) {
        Store.shared.set(key: "Sensors_Fan_\(fanID)_AC_target", value: max(30, min(85, temp)))
    }

    public func battTarget(fanID: Int) -> Int {
        Store.shared.int(key: "Sensors_Fan_\(fanID)_Batt_target", defaultValue: 50)
    }

    public func setBattTarget(fanID: Int, _ temp: Int) {
        Store.shared.set(key: "Sensors_Fan_\(fanID)_Batt_target", value: max(30, min(85, temp)))
    }

    // MARK: - Lifecycle

    /// Cache hardware RPM bounds so we don't re-read them every tick.
    public func registerFans(_ fans: [Fan]) {
        queue.async {
            for fan in fans where fan.id >= 0 {
                self.fanBounds[fan.id] = (min: fan.minSpeed, max: fan.maxSpeed)
            }
        }
    }

    /// Called from Sensors.usageCallback on every sensor read.
    public func processTick(_ sensors: [Sensor_p]) {
        queue.async { [weak self] in
            guard let self else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastTickDate) >= self.minTickInterval else { return }
            self.lastTickDate = now

            guard SMCHelper.shared.isInstalled else { return }

            let source = PowerSource.current
            let cpuTemps = sensors.compactMap { s -> Double? in
                guard s.type == .temperature, s.group == .CPU, s.value > 5 else { return nil }
                return s.value
            }
            guard let maxCPUTemp = cpuTemps.max() else { return }

            let fans = sensors.compactMap { $0 as? Fan }.filter { $0.id >= 0 }
            for fan in fans {
                guard self.isTempMode(fanID: fan.id) else {
                    // Not in temp mode — release if we were controlling it
                    if let prev = self.lastSetRPM[fan.id], prev >= 0 {
                        SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
                        self.lastSetRPM[fan.id] = -1
                    }
                    continue
                }

                let targetTemp = source == .battery
                    ? self.battTarget(fanID: fan.id)
                    : self.acTarget(fanID: fan.id)

                let bounds = self.fanBounds[fan.id]
                let minRPM = bounds?.min ?? fan.minSpeed
                let maxRPM = bounds?.max ?? fan.maxSpeed
                // Ramp linearly from min to max over a 25°C window above the target
                let target = self.targetRPM(
                    temp: maxCPUTemp,
                    targetTemp: Double(targetTemp),
                    maxTemp: Double(targetTemp + 25),
                    minRPM: minRPM,
                    maxRPM: maxRPM
                )

                if target < 0 {
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

    /// Restore automatic mode for all controlled fans. Call from willTerminate.
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

    public func isControlling(fanID: Int) -> Bool {
        isTempMode(fanID: fanID) && (lastSetRPM[fanID] ?? -1) >= 0
    }

    // MARK: - Private

    private var lastTickDate: Date = .distantPast

    private func targetRPM(temp: Double, targetTemp: Double, maxTemp: Double,
                           minRPM: Double, maxRPM: Double) -> Int {
        guard temp > targetTemp else { return -1 }
        let range = max(1, maxTemp - targetTemp)
        let ratio = min(1.0, (temp - targetTemp) / range)
        return Int(minRPM + ratio * (maxRPM - minRPM))
    }
}
