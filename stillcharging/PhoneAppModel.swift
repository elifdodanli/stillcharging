//
//  PhoneAppModel.swift
//  stillcharging
//
//  Owns the long-lived services used by the iPhone app.
//

import Observation

/// Keeps the battery monitor and Bluetooth peripheral alive together.
@MainActor
@Observable
final class PhoneAppModel {
    /// Supplies observable battery values to the iPhone UI.
    let batteryMonitor: BatteryMonitor

    /// Listens for on-demand battery requests from a nearby Mac.
    @ObservationIgnored
    private let nearbyBatteryPeripheral: NearbyBatteryPeripheral

    init() {
        let batteryMonitor = BatteryMonitor()
        self.batteryMonitor = batteryMonitor
        self.nearbyBatteryPeripheral = NearbyBatteryPeripheral(
            batteryMonitor: batteryMonitor
        )
    }
}
