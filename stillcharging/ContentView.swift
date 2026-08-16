//
//  ContentView.swift
//  stillcharging
//
//  Created by Elif Dodanlı on 15.08.2026.
//

import SwiftUI

struct ContentView: View {
    /// A value from 0 through 100, or `nil` when the reading is unavailable.
    let percentage: Int?

    /// The normalized charging state supplied by `BatteryMonitor`.
    let state: ChargingState

    var body: some View {
        VStack(spacing: 12) {
            // Monospaced digits prevent the percentage from visually jumping
            // when numbers with different widths replace each other.
            Text(percentageText)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Label keeps the SF Symbol and its readable status text together.
            Label(statusText, systemImage: statusSymbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    /// Converts the optional number into a user-facing percentage.
    private var percentageText: String {
        guard let percentage else {
            return "—%"
        }

        return "\(percentage)%"
    }

    /// Provides a clear label for every charging state.
    private var statusText: String {
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

    /// Selects an SF Symbol that supports the status text visually.
    private var statusSymbol: String {
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

    /// Uses color as a secondary cue while keeping the text as the primary cue.
    private var statusColor: Color {
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

#Preview("Charging") {
    // Preview values avoid depending on the Simulator's unavailable battery data.
    ContentView(percentage: 67, state: .charging)
}

#Preview("Unknown") {
    // This verifies the honest fallback shown when UIKit returns no battery level.
    ContentView(percentage: nil, state: .unknown)
}
