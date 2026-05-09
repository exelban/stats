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

    private let minTickInterval: TimeInterval = 0.5   // 500 ms — fast response

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
                let minRPM = Int(bounds?.min ?? fan.minSpeed)
                let maxRPM = Int(bounds?.max ?? fan.maxSpeed)
                guard maxRPM > minRPM else { continue }

                let prev = self.lastSetRPM[fan.id] ?? -1

                if maxCPUTemp > Double(targetTemp) {
                    // --- HOT: blast fans immediately to max ---
                    // Small linear ramp in the first 3°C above target for smoothness,
                    // then stay at max. This gives an instant "kick" feel.
                    let overshoot = maxCPUTemp - Double(targetTemp)
                    let ratio = min(1.0, overshoot / 3.0)   // full blast within 3°C overshoot
                    let newRPM = Int(Double(minRPM) + ratio * Double(maxRPM - minRPM))

                    if newRPM != prev {
                        if fan.mode.isAutomatic {
                            SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue)
                        }
                        SMCHelper.shared.setFanSpeed(fan.id, speed: newRPM)
                        self.lastSetRPM[fan.id] = newRPM
                    }
                } else {
                    // --- COOL: reduce slowly so the laptop stays comfortable ---
                    // Max 200 RPM step per 500 ms tick → takes ~20 s to spin fully down.
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
