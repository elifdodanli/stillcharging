//
//  NearbyBatteryProtocol.swift
//  Shared
//
//  Stable identifiers used by both sides of the Bluetooth connection.
//

/// Names the custom Bluetooth Low Energy service and its readable characteristic.
enum NearbyBatteryProtocol {
    /// Identifies Still Charging devices during Bluetooth discovery.
    static let serviceUUID = "6FE914E9-DE84-413B-BE25-C850270BCF06"

    /// Identifies the characteristic that returns an encoded `BatterySnapshot`.
    static let snapshotCharacteristicUUID = "F9C35E1F-440D-49A9-8FDE-C4630505C93B"
}
