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
/// Uses exhaust airflow temperature (left/right wing vents, TaLW/TaRW) as the control
/// signal — directly measuring the air that heats the user's lap.
public class FanTempController {
    public static let shared = FanTempController()

    private let minTickInterval: TimeInterval = 0.5   // 500 ms — fast response

    private var lastSetRPM: [Int: Int] = [:]        // fanID → last written RPM (-1 = auto)
    private let queue = DispatchQueue(label: "eu.exelban.Stats.FanTempController", qos: .utility)

    private init() {}

    // MARK: - Per-fan settings (stored in UserDefaults via Store)

    public func isTempMode(fanID: Int) -> Bool {
        Store.shared.bool(key: "Sensors_Fan_\(fanID)_tempMode", defaultValue: false)
    }

    public func setTempMode(fanID: Int, _ enabled: Bool) {
        Store.shared.set(key: "Sensors_Fan_\(fanID)_tempMode", value: enabled)
        if !enabled {
            // Clear our tracking — popup's mode button handles the SMC transition.
            // We deliberately do NOT call setFanMode here to avoid racing with
            // the popup's own setFanMode call that follows immediately.
            queue.async { self.lastSetRPM[fanID] = -1 }
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

    /// Called from Sensors.usageCallback on every sensor read.
    public func processTick(_ sensors: [Sensor_p]) {
        queue.async { [weak self] in
            guard let self else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastTickDate) >= self.minTickInterval else { return }
            self.lastTickDate = now

            guard SMCHelper.shared.isInstalled else { return }

            let source = PowerSource.current

            // Use exhaust airflow temperatures (left/right wing vents) as control signal.
            // These directly measure the air that heats your lap — far better than CPU or Airport.
            // Falls back through: wing sensors → generic airflow sensors → CPU max.
            let airflowL = sensors.first { $0.key == "TaLW" && $0.value > 5 }?.value
                        ?? sensors.first { $0.key == "TaLP" && $0.value > 5 }?.value
            let airflowR = sensors.first { $0.key == "TaRW" && $0.value > 5 }?.value
                        ?? sensors.first { $0.key == "TaRF" && $0.value > 5 }?.value
            let airflowMax = [airflowL, airflowR].compactMap { $0 }.max()
            let cpuMax = sensors.compactMap { s -> Double? in
                guard s.type == .temperature, s.group == .CPU, s.value > 5 else { return nil }
                return s.value
            }.max()
            let controlTemp = airflowMax ?? cpuMax ?? 0

            let fans = sensors.compactMap { $0 as? Fan }.filter { $0.id >= 0 }
            for fan in fans {
                // If this fan is not in temp mode, skip it entirely.
                // The popup's own mode buttons handle all Auto/Manual transitions —
                // we must NOT send setFanMode(automatic) here or we will race with
                // the popup's setFanMode(forced) call and silently break manual mode.
                guard self.isTempMode(fanID: fan.id) else { continue }

                let targetTemp = source == .battery
                    ? self.battTarget(fanID: fan.id)
                    : self.acTarget(fanID: fan.id)

                // Always use live fan.maxSpeed (same value the turbo button uses).
                let minRPM = Int(fan.minSpeed)
                let maxRPM = Int(fan.maxSpeed)
                guard maxRPM > minRPM else { continue }

                let prev = self.lastSetRPM[fan.id] ?? -1

                if controlTemp > Double(targetTemp) {
                    // HOT: blast to max immediately — aggressive spin-up.
                    let newRPM = maxRPM
                    if newRPM != prev {
                        // Force mode then set speed (always send both on first activation
                        // or whenever the target RPM actually changes).
                        SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue)
                        SMCHelper.shared.setFanSpeed(fan.id, speed: newRPM)
                        self.lastSetRPM[fan.id] = newRPM
                    }
                } else {
                    // COOL: step down 200 RPM per tick (~20 s to fully spin down).
                    if prev > 0 {
                        let stepped = max(minRPM, prev - 200)
                        if stepped <= minRPM {
                            SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
                            self.lastSetRPM[fan.id] = -1
                        } else {
                            SMCHelper.shared.setFanSpeed(fan.id, speed: stepped)
                            self.lastSetRPM[fan.id] = stepped
                        }
                    }
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
}
