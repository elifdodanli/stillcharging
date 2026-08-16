//
//  NearbyBatteryPeripheral.swift
//  stillcharging
//
//  Serves fresh battery snapshots to a nearby Mac over Bluetooth Low Energy.
//

@preconcurrency import CoreBluetooth
import Foundation

/// Publishes a small read-only BLE service from the iPhone.
///
/// With the `bluetooth-peripheral` background mode, iOS can briefly wake this
/// app to answer a read request while the app is suspended.
@MainActor
final class NearbyBatteryPeripheral: NSObject, @preconcurrency CBPeripheralManagerDelegate {
    /// Supplies a fresh reading only when a connected Mac requests one.
    private let batteryMonitor: BatteryMonitor

    /// Manages the iPhone's Bluetooth peripheral role.
    private var peripheralManager: CBPeripheralManager!

    /// Retains the published service for the lifetime of the app.
    private var batteryService: CBMutableService?

    private let serviceUUID = CBUUID(string: NearbyBatteryProtocol.serviceUUID)
    private let snapshotCharacteristicUUID = CBUUID(
        string: NearbyBatteryProtocol.snapshotCharacteristicUUID
    )

    init(batteryMonitor: BatteryMonitor) {
        self.batteryMonitor = batteryMonitor
        super.init()

        // CoreBluetooth delivers delegate callbacks on the main queue.
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    /// Responds when Bluetooth becomes available, unavailable, or unauthorized.
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            peripheral.stopAdvertising()
            peripheral.removeAllServices()
            batteryService = nil
            return
        }

        publishBatteryService()
    }

    /// Starts advertising only after CoreBluetooth accepts the custom service.
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        guard error == nil, service.uuid == serviceUUID else {
            return
        }

        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "Still Charging",
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ])
    }

    /// Returns a newly read battery snapshot to the Mac's BLE read request.
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        guard request.characteristic.uuid == snapshotCharacteristicUUID else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }

        do {
            let snapshot = batteryMonitor.currentSnapshot()
            let encodedSnapshot = try JSONEncoder().encode(snapshot)

            guard request.offset <= encodedSnapshot.count else {
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }

            // Support Bluetooth reads that request the value in multiple chunks.
            request.value = encodedSnapshot.subdata(in: request.offset..<encodedSnapshot.count)
            peripheral.respond(to: request, withResult: .success)
        } catch {
            peripheral.respond(to: request, withResult: .unlikelyError)
        }
    }

    /// Creates a dynamic characteristic whose value is supplied for each read.
    private func publishBatteryService() {
        guard batteryService == nil else {
            return
        }

        let snapshotCharacteristic = CBMutableCharacteristic(
            type: snapshotCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [snapshotCharacteristic]
        batteryService = service
        peripheralManager.add(service)
    }
}
