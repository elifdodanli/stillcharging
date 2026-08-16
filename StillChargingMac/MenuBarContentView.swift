//
//  MenuBarContentView.swift
//  StillChargingMac
//
//  The popover-like content shown from the macOS menu bar.
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    /// The latest iPhone reading, or `nil` before the first successful sync.
    let snapshot: BatterySnapshot?

    /// Describes Bluetooth discovery, connection, reading, or failure.
    let status: NearbyBatteryCentral.Status

    /// Starts an on-demand Bluetooth read from the nearby iPhone.
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let snapshot {
                snapshotContent(snapshot)
            } else {
                waitingContent
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRefresh) {
                HStack(spacing: 8) {
                    if status.isWorking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(status.isWorking ? "Refreshing…" : "Refresh")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(status.isWorking)

            Divider()

            // A menu-bar-only app needs an explicit quit command because it has no Dock menu.
            Button("Quit stillcharging") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 260)
    }

    /// Displays the most recently received battery reading.
    @ViewBuilder
    private func snapshotContent(_ snapshot: BatterySnapshot) -> some View {
        Text("iPhone")
            .font(.headline)

        Text(levelText(for: snapshot))
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .monospacedDigit()

        Label(statusText(for: snapshot.state), systemImage: statusSymbol(for: snapshot.state))
            .font(.title3.weight(.semibold))
            .foregroundStyle(statusColor(for: snapshot.state))

        // Relative formatting turns the absolute Date into text such as "2 min. ago".
        Text("Updated \(snapshot.updatedAt, style: .relative)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Clearly explains why no percentage is shown before sync is implemented.
    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("iPhone", systemImage: "iphone")
                .font(.headline)

            Text("Waiting for iPhone data")
                .font(.title3.weight(.semibold))

            Text("Press Refresh to request the current battery over Bluetooth.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Provides progress or actionable Bluetooth error feedback.
    private var statusMessage: String? {
        switch status {
        case .idle:
            return nil
        case .scanning:
            return "Looking for your iPhone…"
        case .connecting:
            return "Connecting to your iPhone…"
        case .refreshing:
            return "Reading the current battery…"
        case let .unavailable(message):
            return message
        }
    }

    /// Distinguishes an error from neutral progress without relying on color alone.
    private var statusColor: Color {
        switch status {
        case .unavailable:
            return .red
        case .idle, .scanning, .connecting, .refreshing:
            return .secondary
        }
    }

    /// Converts an optional battery level into honest display text.
    private func levelText(for snapshot: BatterySnapshot) -> String {
        snapshot.level.map { "\($0)%" } ?? "—%"
    }

    /// Maps the shared state to a user-facing macOS label.
    private func statusText(for state: ChargingState) -> String {
        switch state {
        case .unknown:
            return "Unknown"
        case .unplugged:
            return "Not Charging"
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        }
    }

    /// Maps the shared state to an SF Symbol available on macOS.
    private func statusSymbol(for state: ChargingState) -> String {
        switch state {
        case .unknown:
            return "questionmark.circle"
        case .unplugged:
            return "bolt.slash.fill"
        case .charging:
            return "bolt.fill"
        case .full:
            return "battery.100percent.bolt"
        }
    }

    /// Uses color only as a secondary status cue.
    private func statusColor(for state: ChargingState) -> Color {
        switch state {
        case .unknown:
            return .secondary
        case .unplugged:
            return .primary
        case .charging, .full:
            return .green
        }
    }
}

#Preview("Received Snapshot") {
    MenuBarContentView(
        snapshot: BatterySnapshot(
            level: 67,
            state: .charging,
            updatedAt: .now.addingTimeInterval(-32)
        ),
        status: .idle,
        onRefresh: {}
    )
}

#Preview("Waiting for Sync") {
    MenuBarContentView(snapshot: nil, status: .scanning, onRefresh: {})
}
