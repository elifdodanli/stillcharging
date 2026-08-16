//
//  StillChargingMacApp.swift
//  StillChargingMac
//
//  The macOS menu bar entry point.
//

import SwiftUI

@main
struct StillChargingMacApp: App {
    /// Owns the Mac's Bluetooth connection and latest iPhone snapshot.
    @State private var batteryCentral = NearbyBatteryCentral()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                snapshot: batteryCentral.snapshot,
                status: batteryCentral.status,
                onRefresh: batteryCentral.refresh
            )
        } label: {
            // The menu bar remains honest until the first successful Bluetooth read.
            Label(menuBarText, systemImage: "iphone")
        }
        .menuBarExtraStyle(.window)
    }

    /// Shows a compact percentage and charging bolt beside the iPhone icon.
    private var menuBarText: String {
        let levelText = batteryCentral.snapshot?.level.map { "\($0)%" } ?? "—%"

        switch batteryCentral.snapshot?.state {
        case .charging, .full:
            return "⚡ \(levelText)"
        case .unknown, .unplugged, nil:
            return levelText
        }
    }
}
