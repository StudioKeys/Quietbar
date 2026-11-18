# Quietbar

A macOS menu bar app for controlling your headphones without reaching for your phone.

Quietbar talks to the headphones directly over Bluetooth LE, the same way the manufacturer's phone app does, and
puts the everyday controls one click away in the menu bar.

## Supported headphones

| Headphones | Status |
|---|---|
| JBL Live 770NC | Supported |
| Moto Buds | Planned |

Quietbar is an independent project. It is not affiliated with, endorsed by, or sponsored by JBL, Harman
International, Samsung Electronics, Motorola, Motorola Mobility, Lenovo, Apple or any other headphone or device
maker. All product names, trademarks and registered trademarks belong to their respective owners and are used only
to describe compatibility.

## Features (JBL Live 770NC)

- Noise control: Noise Cancellation, Ambient Aware, Talk-Thru, Off
  - Adaptive ANC and leakage compensation while noise cancellation is on
  - Ambient level while Ambient Aware is on
- EQ presets: Jazz, Vocal, Bass, Club, Studio, Extreme Bass
- Spatial Sound with Music, Movie and Game modes
- Low Volume EQ
- Left/right balance
- Smart Audio & Video (Audio Mode / Video Mode) — the headphones reconnect briefly to apply it
- Auto play & pause
- Battery level, a menu bar icon that follows the noise mode, and automatic reconnection
- Liquid Glass styling that can be turned off in Settings

## Requirements

- macOS 26 or later
- Headphones paired with the Mac

## Install

1. Download `Quietbar.zip` from the [latest release](../../releases/latest) and unzip it.
2. Move `Quietbar.app` to `/Applications`.
3. The release is not notarized, so the first time, Control-click the app and choose **Open**.
4. Allow Bluetooth access when macOS asks.

Only one app can control the headphones at a time. Close the manufacturer's phone app, or choose **Disconnect** in
Quietbar to hand control back to the phone. Quietbar remembers that choice until you click **Connect**.

## Build from source

```sh
Scripts/bundle.sh            # builds .build/Quietbar.app (ad-hoc signed)
open .build/Quietbar.app
```

Set `QUIETBAR_SIGN_IDENTITY` to a code-signing identity to keep the Bluetooth permission across rebuilds.

```sh
swift test                   # unit tests (Swift Testing)
Scripts/coverage.sh          # line coverage gate, 80% minimum
Scripts/make-icon.sh         # regenerates Resources/AppIcon.icns
```

## How it is built

| Module | Responsibility |
|---|---|
| `HeadphoneKit` | Device-neutral settings model, driver contract, connection session and reconnect policy |
| `JBLProtocol` | JBL frame encoding and decoding |
| `JBLDriver` | Maps JBL Live 770NC settings to frames |
| `BluetoothLE` | CoreBluetooth transport configured by each driver's GATT profile |
| `Quietbar` | SwiftUI menu bar app |

Adding headphones means writing a driver: describe the settings the device has and translate setting changes to
and from bytes. The menu renders whatever the driver describes.

Quietbar only uses each device's control service. It never sends firmware-update commands.

## How it was made

Quietbar was built with the help of an AI coding assistant. The Bluetooth protocols were worked out by observing how
the official companion apps talk to the headphones, for interoperability. No vendor code, firmware or assets are
included in this repository.

## License

[MIT](LICENSE)
