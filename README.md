# Still Charging

Still Charging is a small Apple ecosystem learning project for checking an iPhone's battery level and charging state without looking at the iPhone.

The idea came from a tiny real-life annoyance: I sometimes charge my iPhone somewhere that is out of sight and keep checking it just to see whether it is still charging or how much charge it has reached. I wanted that information somewhere I was already looking—my Mac, and eventually my Apple Watch.

> [!IMPORTANT]
> This project is experimental and under active development. The current Bluetooth connection is a learning prototype and is not yet reliable enough for everyday use.

## Current status

The repository currently contains:

- An iOS SwiftUI app that reads the current iPhone battery percentage and charging state.
- A native macOS menu bar app built with `MenuBarExtra`.
- A shared `BatterySnapshot` model used by both platforms.
- An experimental on-demand Bluetooth Low Energy connection from the Mac to the iPhone.
- Honest stale-data feedback through the snapshot's last-updated timestamp.

The iOS app observes battery-level and battery-state changes using `UIDevice` notifications. The Mac app can request a fresh snapshot over a custom read-only BLE characteristic.

## Current limitations

- Bluetooth discovery and reconnection still need more work.
- Background behavior is controlled by iOS and is not guaranteed in every situation.
- Force-quitting the iOS app prevents it from responding to background Bluetooth requests.
- Initial BLE discovery may require the iOS app to be open in the foreground.
- The current prototype remembers the first discovered peripheral but does not yet implement app-level pairing or authentication.
- Apple Watch support and charging-threshold notifications have not been implemented yet.

The project deliberately displays the last successful update time instead of pretending that cached data is live.

## Architecture

```text
iPhone
├── BatteryMonitor
│   └── Reads UIDevice battery level and charging state
├── NearbyBatteryPeripheral
│   └── Exposes a read-only BLE characteristic
└── PhoneAppModel
    └── Owns the long-lived iPhone services

Shared
├── BatterySnapshot
└── NearbyBatteryProtocol

Mac
├── NearbyBatteryCentral
│   └── Discovers, connects, and requests a snapshot
└── MenuBarExtra
    └── Displays the latest value and refresh state
```

The shared model does not expose UIKit types to macOS. Instead, the iPhone converts `UIDevice.BatteryState` into the platform-independent `ChargingState` enum before sending a snapshot.

## Apple frameworks

- **SwiftUI** for the iOS interface and macOS menu bar interface.
- **Observation** for model-to-view updates with `@Observable`.
- **UIKit** on iOS for `UIDevice` battery information.
- **CoreBluetooth** for the experimental nearby iPhone-to-Mac request.
- **Foundation** for notifications, dates, JSON encoding, and shared data types.

## Requirements

- Xcode with iOS 18.5 and macOS 14 SDK support or newer.
- A physical iPhone for real battery readings and Bluetooth testing.
- A Bluetooth Low Energy-capable Mac.
- An Apple Account configured in Xcode for physical-device testing.

Battery information is hardware-specific, so the complete flow must be tested on a physical iPhone rather than relying only on Simulator.

## Running the project

1. Open `stillcharging.xcodeproj` in Xcode.
2. Select the `stillcharging` target and choose your own team under **Signing & Capabilities**.
3. Run the iOS app on a physical iPhone and allow Bluetooth access.
4. Open the installed iPhone app at least once.
5. Select the `StillChargingMac` scheme with **My Mac** as the destination.
6. Run the macOS app and allow Bluetooth access.
7. Open Still Charging from the menu bar and press **Refresh**.

The macOS app is a menu-bar-only app, so it does not display a normal Dock icon or main window.

## Data and privacy

Still Charging currently reads only:

- Battery percentage
- Charging state
- Snapshot update time

The experimental sync sends this small snapshot directly over nearby Bluetooth. The project does not currently include analytics, accounts, advertising, or battery-history storage.

The BLE service and characteristic UUIDs in the source code are protocol identifiers, not passwords or API credentials. However, the current readable characteristic is not authenticated, so app-level device pairing should be added before treating the design as production-ready.

## Roadmap

- Improve Bluetooth reconnection and stale-peripheral recovery.
- Evaluate whether BLE remains the right Mac sync mechanism.
- Add explicit device pairing.
- Add an Apple Watch app and WidgetKit complication using WatchConnectivity.
- Explore charging-threshold notifications while documenting iOS background-execution limits.
- Improve accessibility, tests, and setup documentation.

The goal is to keep the product focused on glanceability rather than battery analytics, history, health graphs, or complex dashboards.

## Project philosophy

This is both a utility and a learning project. The code favors clear names, small platform-specific components, shared models where useful, and explicit handling of unavailable or stale information.
