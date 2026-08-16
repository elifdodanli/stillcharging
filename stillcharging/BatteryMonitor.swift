//
//  BatteryMonitor.swift
//  stillcharging
//
//  Created for the first iPhone battery-monitoring milestone.
//

import Foundation
import Observation
import UIKit

extension ChargingState {
    /// Converts UIKit's device-specific state into our app's own state.
    init(deviceState: UIDevice.BatteryState) {
        switch deviceState {
        case .unknown:
            self = .unknown
        case .unplugged:
            self = .unplugged
        case .charging:
            self = .charging
        case .full:
            self = .full
        @unknown default:
            // A future iOS version may add a new UIKit state that this app
            // does not know about yet. Treating it as unknown is the safest fallback.
            self = .unknown
        }
    }
}

/// Reads the current iPhone battery and publishes changes for SwiftUI.
///
/// `@MainActor` keeps observable UI state and UIKit access on the main thread.
/// `@Observable` lets SwiftUI track the properties that a view reads.
@MainActor
@Observable
final class BatteryMonitor {
    /// An integer from 0 through 100, or `nil` when iOS has no valid reading.
    private(set) var percentage: Int?

    /// The latest charging state reported by the current iPhone.
    private(set) var state: ChargingState = .unknown

    /// The moment when the latest reading was produced.
    private(set) var updatedAt = Date.now

    /// UIKit's representation of the device running this app.
    @ObservationIgnored
    private let device: UIDevice

    /// Delivers battery-change events inside this app process.
    @ObservationIgnored
    private let notificationCenter: NotificationCenter

    /// Tokens are retained so every notification subscription can be removed later.
    @ObservationIgnored
    private var observerTokens: [NSObjectProtocol] = []

    init() {
        // Access the main-actor UIKit singleton inside this main-actor initializer.
        self.device = UIDevice.current
        self.notificationCenter = NotificationCenter.default

        // Battery values and battery notifications are unavailable until monitoring is enabled.
        device.isBatteryMonitoringEnabled = true

        // Read immediately so the first screen does not wait for a notification.
        refresh()

        // Keep future readings synchronized with UIKit's battery events.
        startObservingBatteryChanges()
    }

    deinit {
        // Block-based NotificationCenter observers must be removed with their tokens.
        for token in observerTokens {
            notificationCenter.removeObserver(token)
        }
    }

    /// Produces a fresh transferable reading for an on-demand remote request.
    func currentSnapshot() -> BatterySnapshot {
        refresh()

        return BatterySnapshot(
            level: percentage,
            state: state,
            updatedAt: updatedAt
        )
    }

    /// Subscribes to both percentage changes and plugged-in state changes.
    private func startObservingBatteryChanges() {
        let notificationNames: [Notification.Name] = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification
        ]

        observerTokens = notificationNames.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // The observer uses a weak reference so NotificationCenter does not keep
                // the monitor alive after its owner releases it.
                Task { @MainActor [weak self] in
                    // Make the actor hop explicit because NotificationCenter's closure
                    // does not carry a compile-time main-actor guarantee.
                    self?.refresh()
                }
            }
        }
    }

    /// Reads level and state together to keep the displayed snapshot consistent.
    private func refresh() {
        let rawLevel = device.batteryLevel

        if rawLevel < 0 {
            // UIKit reports -1 when monitoring is unavailable or not ready.
            percentage = nil
        } else {
            // UIKit uses 0.0...1.0; the UI needs a rounded 0...100 percentage.
            percentage = min(100, max(0, Int((rawLevel * 100).rounded())))
        }

        state = ChargingState(deviceState: device.batteryState)
        updatedAt = .now
    }
}
