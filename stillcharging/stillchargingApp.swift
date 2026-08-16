//
//  stillchargingApp.swift
//  stillcharging
//
//  Created by Elif Dodanlı on 15.08.2026.
//

import SwiftUI

@main
struct stillchargingApp: App {
    /// The app owns one model and its services for the lifetime of its main scene.
    @State private var appModel = PhoneAppModel()

    var body: some Scene {
        WindowGroup {
            // Reading observable properties here makes SwiftUI update the view
            // whenever the monitor publishes a new battery reading.
            ContentView(
                percentage: appModel.batteryMonitor.percentage,
                state: appModel.batteryMonitor.state
            )
        }
    }
}
