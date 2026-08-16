//
//  BatterySnapshot.swift
//  Shared
//
//  Shared by the iOS, macOS, and future watchOS targets.
//

import Foundation

/// A platform-independent description of the iPhone's charging state.
enum ChargingState: String, Codable, Equatable, Sendable {
    case unknown
    case unplugged
    case charging
    case full
}

/// A small, transferable reading of the iPhone battery at one point in time.
struct BatterySnapshot: Codable, Equatable, Sendable {
    /// An integer from 0 through 100, or `nil` when no valid level is available.
    let level: Int?

    /// The normalized charging state understood by every app target.
    let state: ChargingState

    /// The moment when the iPhone produced this reading.
    let updatedAt: Date
}
