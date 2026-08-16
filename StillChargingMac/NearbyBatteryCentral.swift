//
//  NearbyBatteryCentral.swift
//  StillChargingMac
//
//  Requests fresh iPhone battery snapshots over Bluetooth Low Energy.
//

@preconcurrency import CoreBluetooth
import Foundation
import Observation

/// Discovers the iPhone's custom BLE service and reads its battery snapshot.
@MainActor
@Observable
final class NearbyBatteryCentral: NSObject,
    @preconcurrency CBCentralManagerDelegate,
    @preconcurrency CBPeripheralDelegate {

    /// Describes the current on-demand refresh operation.
    enum Status: Equatable {
        case idle
        case scanning
        case connecting
        case refreshing
        case unavailable(String)

        /// Prevents duplicate refresh requests while one is already running.
        var isWorking: Bool {
            switch self {
            case .scanning, .connecting, .refreshing:
                return true
            case .idle, .unavailable:
                return false
            }
        }
    }

    /// The newest snapshot successfully read from the iPhone.
    private(set) var snapshot: BatterySnapshot?

    /// Drives progress and error feedback in the menu bar popover.
    private(set) var status: Status = .idle

    @ObservationIgnored
    private var centralManager: CBCentralManager!

    @ObservationIgnored
    private var iPhonePeripheral: CBPeripheral?

    @ObservationIgnored
    private var snapshotCharacteristic: CBCharacteristic?

    @ObservationIgnored
    private var refreshRequested = false

    @ObservationIgnored
    private var scanTimeoutTask: Task<Void, Never>?

    private let serviceUUID = CBUUID(string: NearbyBatteryProtocol.serviceUUID)
    private let snapshotCharacteristicUUID = CBUUID(
        string: NearbyBatteryProtocol.snapshotCharacteristicUUID
    )
    private let rememberedPeripheralKey = "rememberedIPhonePeripheralIdentifier"

    override init() {
        super.init()

        // CoreBluetooth delivers every delegate callback on the main queue.
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    /// Starts an on-demand read without continuously polling the iPhone.
    func refresh() {
        guard !status.isWorking else {
            return
        }

        refreshRequested = true
        continueRefreshWhenBluetoothIsReady()
    }

    /// Continues a pending request after Bluetooth changes state.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard refreshRequested else {
            return
        }

        continueRefreshWhenBluetoothIsReady()
    }

    /// Connects to the first nearby device advertising our custom service.
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        central.stopScan()
        scanTimeoutTask?.cancel()
        remember(peripheral)
        connect(to: peripheral)
    }

    /// Begins service discovery after the Bluetooth connection succeeds.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = .connecting
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    /// Reports a failed connection without discarding an older valid snapshot.
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        finishWithError(error?.localizedDescription ?? "Could not connect to the iPhone.")
    }

    /// Clears the cached characteristic when the current connection ends.
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        snapshotCharacteristic = nil

        if refreshRequested {
            finishWithError(error?.localizedDescription ?? "The iPhone disconnected.")
        }
    }

    /// Finds the Still Charging service on the connected iPhone.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finishWithError(error.localizedDescription)
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            finishWithError("The iPhone does not expose the Still Charging service.")
            return
        }

        peripheral.discoverCharacteristics([snapshotCharacteristicUUID], for: service)
    }

    /// Finds and reads the snapshot characteristic.
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            finishWithError(error.localizedDescription)
            return
        }

        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == snapshotCharacteristicUUID
        }) else {
            finishWithError("The iPhone battery characteristic is unavailable.")
            return
        }

        snapshotCharacteristic = characteristic
        readSnapshot(from: peripheral, characteristic: characteristic)
    }

    /// Decodes the iPhone's response into the shared model.
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            finishWithError(error.localizedDescription)
            return
        }

        guard
            characteristic.uuid == snapshotCharacteristicUUID,
            let data = characteristic.value
        else {
            finishWithError("The iPhone returned an empty battery response.")
            return
        }

        do {
            snapshot = try JSONDecoder().decode(BatterySnapshot.self, from: data)
            refreshRequested = false
            status = .idle
        } catch {
            finishWithError("The iPhone returned an unreadable battery response.")
        }
    }

    /// Selects the fastest available path for a refresh request.
    private func continueRefreshWhenBluetoothIsReady() {
        switch centralManager.state {
        case .poweredOn:
            if
                let peripheral = iPhonePeripheral,
                peripheral.state == .connected,
                let characteristic = snapshotCharacteristic
            {
                readSnapshot(from: peripheral, characteristic: characteristic)
            } else if let peripheral = rememberedPeripheral() {
                connect(to: peripheral)
            } else {
                scanForIPhone()
            }
        case .poweredOff:
            finishWithError("Turn on Bluetooth on this Mac and your iPhone.")
        case .unauthorized:
            finishWithError("Allow Bluetooth access in System Settings to refresh the iPhone.")
        case .unsupported:
            finishWithError("This Mac does not support Bluetooth Low Energy.")
        case .resetting, .unknown:
            status = .connecting
        @unknown default:
            finishWithError("Bluetooth is currently unavailable.")
        }
    }

    /// Searches only for devices publishing the Still Charging service UUID.
    private func scanForIPhone() {
        status = .scanning
        centralManager.scanForPeripherals(withServices: [serviceUUID])

        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))

            guard !Task.isCancelled, let self, self.status == .scanning else {
                return
            }

            self.centralManager.stopScan()
            self.finishWithError(
                "iPhone not found. Keep it nearby and open Still Charging once."
            )
        }
    }

    /// Connects to a newly discovered or previously remembered iPhone.
    private func connect(to peripheral: CBPeripheral) {
        status = .connecting
        iPhonePeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }

    /// Requests the latest dynamic characteristic value.
    private func readSnapshot(
        from peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) {
        status = .refreshing
        peripheral.readValue(for: characteristic)
    }

    /// Stores the system Bluetooth identifier for quicker future reconnects.
    private func remember(_ peripheral: CBPeripheral) {
        iPhonePeripheral = peripheral
        UserDefaults.standard.set(
            peripheral.identifier.uuidString,
            forKey: rememberedPeripheralKey
        )
    }

    /// Retrieves the previously connected iPhone without scanning when possible.
    private func rememberedPeripheral() -> CBPeripheral? {
        if let iPhonePeripheral {
            return iPhonePeripheral
        }

        guard
            let identifierText = UserDefaults.standard.string(forKey: rememberedPeripheralKey),
            let identifier = UUID(uuidString: identifierText)
        else {
            return nil
        }

        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
        iPhonePeripheral = peripherals.first
        return peripherals.first
    }

    /// Ends the current request with actionable feedback for the user.
    private func finishWithError(_ message: String) {
        scanTimeoutTask?.cancel()
        centralManager.stopScan()
        refreshRequested = false
        status = .unavailable(message)
    }
}
