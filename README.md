<div align="center">

# 🌒 Notchy

**Turn your MacBook's notch into a delightful interactive surface.**

[![macOS 14+](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Open Source](https://img.shields.io/badge/Open%20Source-❤️-red.svg)](https://github.com/OtaruTech/notchy)

A free, open-source macOS notch utility for Apple-Silicon MacBooks.
NotchNook-style — Now Playing, file drop tray, AirPods burst, calendar, timer, camera mirror, system stats — all from the notch.

<img src="docs/images/01-live-activity.png" width="500" alt="Live Activity strip in the notch">

</div>

---

## ✨ Features

### 🎵 Now Playing

Album art + waveform flank the physical notch while music plays. Hover to expand into a full player with scrubber, play/pause, prev/next.

<img src="docs/images/02-now-playing.png" width="700" alt="Now Playing expanded">

- **Works with any music app** — Apple Music, Spotify, Safari/Chrome video, VLC — via the bundled `media-control` adapter that bypasses macOS 15.4+ restrictions on `MediaRemote`
- **Real album artwork** decoded directly from system Now Playing
- **Click album art** → bring source app to front
- **Two-finger horizontal swipe** over the notch → next / previous track
- **Pause keeps controls visible** so you can re-play without re-summoning

### 🗂 Drop Tray

Drag a file onto the notch — panel expands into a temporary tray with AirDrop, Email, and Clear actions. Drag chips back out to any app.

### 🎧 AirPods Burst

Connect AirPods → notch briefly expands showing device name and **L / R / Case** battery percentages. Auto-dismisses after 3s.

### 📅 Calendar

Today's upcoming events at a glance. Click an event to jump to Calendar.app.

### ⏱ Timer / Pomodoro

Start 5 / 15 / 25-minute timers from the status bar menu. Ring progress shows in the notch. Notification fires on completion.

### 📷 Mirror

Webcam preview in the notch. Useful for last-minute check before video calls.

### 📊 Dashboard

Default hover view when nothing else is happening: big clock, today's date, next calendar event, and live CPU / battery readouts.

### 🎛 Tab Bar

When multiple widgets are active, tabs appear at the bottom of the expanded panel. **Dashboard is always available** so you can navigate back from any feature.

---

## 📦 Install

### Quick install (Release build)

```bash
git clone https://github.com/OtaruTech/notchy.git
cd notchy
xcodegen generate
open Notchy.xcodeproj
# In Xcode: Product → Archive → Distribute App → Copy App
# Drag the resulting Notchy.app to /Applications
# First launch: right-click Notchy.app → Open (to bypass Gatekeeper)
```

### One-shot CLI build (ad-hoc signed)

```bash
xcodegen generate
xcodebuild -project Notchy.xcodeproj -scheme Notchy \
  -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build

cp -R build/Build/Products/Release/Notchy.app /Applications/
xattr -dr com.apple.quarantine /Applications/Notchy.app
open /Applications/Notchy.app
```

### Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 Sonoma or later |
| Hardware | Apple-Silicon MacBook with hardware notch (14"/16" Pro, M2+ Air) |
| Xcode | 16.0 or later |
| `xcodegen` | `brew install xcodegen` |

### Permissions

On first launch you'll be prompted for:

| Permission | Why |
|---|---|
| **Accessibility** | Detect mouse hovering over the notch (global event monitor) |
| **Bluetooth** | Read AirPods battery levels |
| **Calendar** | Show today's events |
| **Camera** | Mirror widget preview |

If a prompt doesn't appear, add Notchy manually in **System Settings → Privacy & Security**.

---

## 🎮 How to use

| Action | Result |
|---|---|
| Hover over the notch (with music playing) | Now Playing expands |
| Hover over the notch (no music) | Dashboard expands |
| Click ▶ / ⏸ / ⏪ / ⏩ | Control playback |
| Click album art | Switch to the source app (Music / Spotify / Safari…) |
| **Two-finger horizontal swipe** over the notch | Next / previous track |
| Drag a file onto the notch | Drop tray expands |
| Connect AirPods | 3s burst with battery |
| Click 🌒 menu bar icon → Settings | Open Settings |
| Click 🌒 → **Start Timer** | Begin 5/15/25-minute timer |
| Click 🌒 → **Mirror** | Open webcam preview |
| `Esc` or click outside | Collapse |

---

## 🧱 Architecture

Notchy is a single-process SwiftUI + AppKit macOS app with a notch-fitting `NSPanel` overlay.

```
┌─────────────────────────────────────────────────────────────┐
│  App Layer        NotchyApp · NotchWindowController         │
├─────────────────────────────────────────────────────────────┤
│  UI Layer         NotchShell · NotchExpandedView · TabBar   │
│                   DashboardView · MediaView · DropView ·    │
│                   AirPodsView · CalendarView · TimerView ·  │
│                   MirrorView · LiveActivityStrip            │
├─────────────────────────────────────────────────────────────┤
│  Feature Layer    @Observable view models — MediaFeature,   │
│                   DropFeature, BTFeature, CalendarFeature,  │
│                   TimerFeature, MirrorFeature, etc.         │
├─────────────────────────────────────────────────────────────┤
│  State            NotchStateMachine · NotchState · Intent   │
├─────────────────────────────────────────────────────────────┤
│  System Bridges   actors — MediaRemoteBridge,               │
│                   IOBluetoothBridge, EventKitBridge,        │
│                   SystemMonitorBridge, DragSession,         │
│                   HotZoneMonitor, ScreenGeometry            │
└─────────────────────────────────────────────────────────────┘
```

**Design principles**

- All system access is wrapped in `actor` bridges, never touched directly from views.
- All UI is `@MainActor`. All view models are `@MainActor @Observable`.
- A single state machine is the source of truth — features push intents, never set state directly.
- Each feature module is independently testable.
- Snapshot tests cover every visual component (`swift-snapshot-testing`).

### How the Now Playing private-API workaround works

macOS 15.4 added entitlement enforcement in `mediaremoted` — third-party apps can no longer call `MRMediaRemoteGetNowPlayingInfo` directly. Notchy bundles [`ungive/mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter) (the `media-control` CLI) inside `Notchy.app/Contents/Resources/MediaControl/`. The adapter spawns `/usr/bin/perl` (whose bundle id `com.apple.perl5` is Apple-signed and entitled) which dynamically loads `MediaRemoteAdapter.framework`. Notchy reads the resulting JSON stream over a pipe. End users don't need to install anything separately.

---

## 🧪 Development

### Build + run

```bash
xcodegen generate
open Notchy.xcodeproj
# ⌘R in Xcode
```

### Run tests

```bash
xcodebuild -project Notchy.xcodeproj -scheme NotchyTests -destination 'platform=macOS' test
xcodebuild -project Notchy.xcodeproj -scheme NotchySnapshotTests -destination 'platform=macOS' test
```

Notchy has ~46 unit tests and ~17 snapshot tests covering the state machine, parsers, geometry, and visual components.

### Project structure

```
Notchy/
├── App/                  — NotchyApp, AppDelegate, NotchWindowController
├── State/                — NotchState, NotchIntent, NotchStateMachine
├── System/               — actor bridges (MediaRemote, Bluetooth, EventKit,
│                          SystemMonitor, DragSession, HotZoneMonitor,
│                          ScreenGeometry)
├── Features/
│   ├── Media/            — Now Playing
│   ├── Drop/             — File tray
│   ├── AirPods/          — Bluetooth burst
│   ├── Calendar/         — Today's events
│   ├── Timer/            — Pomodoro
│   ├── SystemMonitor/    — CPU + battery gauge
│   ├── Mirror/           — Webcam preview
│   └── Dashboard/        — Default hover content
├── UI/                   — NotchShell, NotchExpandedView, NotchTabBar,
│                           NotchHint, LiveActivityStrip, DesignTokens,
│                           TapCatcher
├── Settings/             — SettingsView
└── Resources/MediaControl/ — bundled media-control CLI + adapter
```

### Enable verbose debug logging

```bash
defaults write tech.otaru.Notchy notchy.debugLogging -bool true
# Then watch:
tail -f /tmp/notchy.log
```

---

## 🛣 Roadmap

- [ ] Configurable hover delay
- [ ] Configurable trigger gesture (hover vs click vs swipe)
- [ ] Custom widgets / extension SDK
- [ ] Live volume / brightness HUD replacement
- [ ] System notification hijacking
- [ ] Sparkle auto-updater
- [ ] Mac App Store distribution path (constrained by private-API usage)
- [ ] Localization

See [open issues](https://github.com/OtaruTech/notchy/issues) for the latest.

---

## 🤝 Contributing

Pull requests welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

Quick start:
1. Fork and clone
2. `xcodegen generate && open Notchy.xcodeproj`
3. Create a feature branch (`git checkout -b feat/your-feature`)
4. Make sure tests pass (`xcodebuild ... test`)
5. Open a PR

---

## 🙏 Acknowledgments

- [NotchNook](https://lo.cafe/notchnook) by [lo.cafe / @kinark](https://lo.cafe) — the reference app this clone was modeled after
- [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — the brilliant workaround that brings Now Playing back to third-party apps on macOS 15.4+
- [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — visual regression tests
- [yonaskolb/XcodeGen](https://github.com/yonaskolb/XcodeGen) — declarative `.xcodeproj` generation

---

## 📜 License

Notchy is [MIT licensed](LICENSE).

The bundled `media-control` CLI is BSD-3-Clause licensed; see [its license](Notchy/Resources/MediaControl/README.md).
