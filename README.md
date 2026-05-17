# Notchy

A macOS notch utility for Apple-Silicon MacBooks with a hardware notch. Brings **Now Playing**, **file drop tray**, and **AirPods burst** to the notch area.

## Requirements

- macOS 14 Sonoma or later
- Apple-Silicon MacBook with hardware notch (14"/16" Pro, M2+ Air)
- Xcode 16+
- `xcodegen` (`brew install xcodegen`)

## Build & run from source

```bash
git clone https://github.com/OtaruTech/notchy.git
cd notchy
xcodegen generate
open Notchy.xcodeproj
# Xcode → Product → Run (⌘R)
```

First launch will prompt for:
- **Accessibility** (for hover detection — System Settings → Privacy & Security → Accessibility)
- **Bluetooth** (for AirPods battery — first connect after install)

## Install to /Applications (free signing)

1. `xcodegen generate`
2. Open Xcode → Product → Archive
3. Distribute App → Copy App → Save somewhere
4. Drag `Notchy.app` to `/Applications`
5. **First launch:** right-click `Notchy.app` → Open → Open in the warning dialog (bypasses Gatekeeper)
6. Re-grant Accessibility + Bluetooth permissions for the new install location

## Re-signing when the certificate expires

The free Apple ID Personal Team certificate is typically valid for about a year. macOS does not enforce iOS-style 7-day kill-switches; an installed `.app` keeps running. But eventually you'll need to re-issue:

1. Open the project, ensure your Apple ID is selected as the signing team
2. Product → Archive → Distribute App → Copy App
3. Replace `/Applications/Notchy.app` with the freshly-signed copy
4. Right-click open again to bypass Gatekeeper

## Features

- **Now Playing** — hover the notch while Music/Spotify/Safari is playing to see album art, scrubber, and play/pause/prev/next.
- **Drop Tray** — drag a file into the notch and the tray expands. Drag chips back out to Finder or any app, or fire AirDrop / Email / Clear-all.
- **AirPods Burst** — connect AirPods and the notch briefly expands to show device name + left/right/case battery.

## Settings

A 🌒 icon in the menu bar opens **Settings…** for launch-at-login and the hint-pill toggle.

## Why a private API?

Now Playing data isn't available through any public API on macOS. The same dlopen-based hook that NotchNook and SongKit use is concentrated in one file (`Notchy/System/MediaRemoteBridge.swift`). If a future macOS update breaks the symbol names, only that file needs adjustment; the rest of the app keeps working.

This also means Notchy cannot be distributed on the Mac App Store. Local install is the supported path.

## Project structure

- `Notchy/App/` — `NotchyApp.swift`, `AppDelegate.swift`, `NotchWindowController.swift`
- `Notchy/State/` — `NotchState`, `NotchIntent`, `NotchStateMachine`
- `Notchy/System/` — `ScreenGeometry`, `MediaRemoteBridge` (private API), `IOBluetoothBridge`, `DragSession`, `HotZoneMonitor`
- `Notchy/Features/{Media,Drop,AirPods}/` — feature view models + views
- `Notchy/UI/` — `NotchShell`, `NotchExpandedView`, `NotchHint`, `DesignTokens`
- `Notchy/Settings/` — `SettingsView`
- `NotchyTests/` — Swift Testing framework unit tests (state machine, parsers, geometry)
- `NotchySnapshotTests/` — pointfreeco swift-snapshot-testing for SwiftUI views
- `docs/superpowers/{specs,plans}/` — design spec + implementation plan

## Running tests

```bash
xcodebuild -project Notchy.xcodeproj -scheme NotchyTests -destination 'platform=macOS' test
xcodebuild -project Notchy.xcodeproj -scheme NotchySnapshotTests -destination 'platform=macOS' test
```

## License

TBD
