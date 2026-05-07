//
//  fanPower.swift
//  Sensors
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

import IOKit
import IOKit.pwr_mgt
import Kit

// Manages fan mode/speed snapshot across sleep/wake cycles at the IOKit layer.
// NSWorkspace.didWakeNotification arrives after SMC is ready only intermittently;
// IORegisterForSystemPower fires earlier and is not tied to any UI lifecycle.
internal final class FanPowerManager {
    internal static let shared = FanPowerManager()

    // Snapshot keyed by fan id: (mode, speed) captured just before sleep.
    private var snapshot: [Int: (mode: FanMode, speed: Int)] = [:]

    // Fan list registered by the reader on discovery.
    private var fans: [Fan] = []

    private var notifyPort: IONotificationPortRef?
    private var notifierObject: io_object_t = 0
    private var rootPort: io_connect_t = IO_OBJECT_NULL

    private init() {
        self.registerIOPower()
    }

    internal func register(fan: Fan) {
        guard !self.fans.contains(where: { $0.id == fan.id }) else { return }
        self.fans.append(fan)
    }

    private func registerIOPower() {
        // Retain self for the C callback context; released in deinit via IODeregisterForSystemPower.
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let callback: IOPowerSourceCallbackType = { refcon, _, messageType, messageArgument in
            guard let refcon else { return }
            let manager = Unmanaged<FanPowerManager>.fromOpaque(refcon).takeUnretainedValue()
            switch Int(messageType) {
            case kIOMessageSystemWillSleep:
                manager.handleWillSleep()
                IOAllowPowerChange(manager.rootPort, Int(bitPattern: messageArgument))
            case kIOMessageSystemHasPoweredOn:
                manager.handleHasPoweredOn()
            default:
                break
            }
        }

        self.rootPort = IORegisterForSystemPower(selfPtr, &self.notifyPort, callback, &self.notifierObject)

        guard self.rootPort != IO_OBJECT_NULL, let port = self.notifyPort else {
            error("FanPowerManager: IORegisterForSystemPower failed")
            Unmanaged<FanPowerManager>.fromOpaque(selfPtr).release()
            return
        }

        IONotificationPortSetDispatchQueue(port, DispatchQueue.global(qos: .utility))
    }

    private func handleWillSleep() {
        guard SMCHelper.shared.isActive() else { return }

        self.snapshot.removeAll()

        for fan in self.fans {
            guard let mode = fan.customMode, !mode.isAutomatic else { continue }
            self.snapshot[fan.id] = (mode: mode, speed: fan.customSpeed ?? 0)
            SMCHelper.shared.setFanMode(fan.id, mode: FanMode.automatic.rawValue)
        }

        debug("FanPowerManager: snapshotted \(self.snapshot.count) fan(s) before sleep")
    }

    private func handleHasPoweredOn() {
        guard !self.snapshot.isEmpty else { return }

        // Give the SMC ~2 s to settle after wake before restoring.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            guard SMCHelper.shared.isActive() else {
                debug("FanPowerManager: helper not active on wake, skipping restore")
                return
            }

            for (id, entry) in self.snapshot {
                SMCHelper.shared.setFanMode(id, mode: entry.mode.rawValue)
                if !entry.mode.isAutomatic && entry.speed > 0 {
                    SMCHelper.shared.setFanSpeed(id, speed: entry.speed)
                }
            }

            debug("FanPowerManager: restored \(self.snapshot.count) fan(s) after wake")
            self.snapshot.removeAll()
        }
    }

    deinit {
        if self.notifierObject != 0 {
            IODeregisterForSystemPower(&self.notifierObject)
        }
        if self.rootPort != IO_OBJECT_NULL {
            IOServiceClose(self.rootPort)
        }
        if let port = self.notifyPort {
            IONotificationPortDestroy(port)
        }
    }
}
