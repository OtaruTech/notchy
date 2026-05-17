# Changelog

All notable changes to Notchy. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [0.3.0] — 2026-05-17

### Added
- **Clipboard manager** — Paste.app-style clipboard history, anchored on the notch.
  - Captures text / URL / image / file / colour / code on every system copy.
  - **⌘⇧V** drops the panel out from under the notch — search field + horizontal card row + 1-9 quick-paste slots.
  - Click or Enter pastes back into the previously-focused app and restores the prior clipboard 80 ms later (configurable).
  - Default-excludes 1Password / Bitwarden / Keychain Access / LastPass; respects the `org.nspasteboard.ConcealedType` UTI.
  - SHA-256 hash dedupe — copying the same string twice bumps `updated_at` instead of inserting a duplicate.
  - Retention purge (7 / 30 / 90 / never) runs on launch and once per hour.
  - Storage: local SQLite (no SwiftPM deps; raw `libsqlite3`) at `~/Library/Application Support/tech.otaru.Notchy/clipboard.sqlite`, file mode 0600. Images stored as separate PNGs alongside the DB.
  - Menu bar: "Pause Clipboard Capture" toggle.
- Settings → Clipboard tab: master on/off, retention picker, restore toggle, capture-images toggle, exclusion editor with "Reset to defaults", "Clear all" with confirm, "Reveal data folder" button.

### Changed
- Status-bar menu reorganised: Settings / Welcome / **Pause Clipboard** / Start Timer / Mirror / Quit.

## [0.2.4] — 2026-05-17

### Added
- **Audio output badge** in Now Playing — small pill above the track title showing the current output device (`🎧 AirPods`, `🔊 MacBook Speakers`, etc.) via CoreAudio HAL with AirPods/Beats name detection
- **Live-ticking progress bar** — scrubber + elapsed-time label tick smoothly between sparse `media-control` events; `NowPlayingVM` interpolates from a captured `snapshotDate`
- **Global timer pill** — when a countdown is running, the live-activity strip's right wing shows a red/orange ring + `mm:ss` countdown; remains visible while music continues
- **Synced lyrics** (opt-in, default OFF) — `LyricsBridge` fetches from lrclib.net (exact `get` → loose `search` → plain-text fallback → Apple Music AppleScript). When enabled, a thin black capsule with the current LRC line appears below the notch
- Settings → Now Playing → "Show synced lyrics below notch" toggle

### Changed
- Live-activity strip renders when EITHER media is loaded OR a timer is running (was: media only)
- Plain-text lyrics rendered when synced LRC isn't available (tagged "Plain lyrics (no timing)")

## [0.2.3] — 2026-05-17

### Added
- **Settings UI** redesigned: TabView (General + Advanced) with hover-delay slider (0–500ms), swipe toggle, debug-logging toggle, hotkey master toggle, and reset-preferences button
- **First-launch Welcome screen** — crescent-moon header, 4 feature rows (hover, swipe, drop, mirror), permissions hint, re-accessible via menu bar "Welcome…"
- **Global keyboard shortcuts** (Carbon `RegisterEventHotKey`):
  - `⌘⌥N` toggle dashboard
  - `⌘⌥M` toggle Mirror
  - Master toggle in Settings → General → Keyboard shortcuts

### Changed
- Hover trigger delay now user-configurable via `notchy.hoverDelayMs` (default 120ms) — previously hardcoded
- Two-finger swipe and debug logging gated by individual UserDefault toggles

## [0.2.2] — 2026-05-17

### Added
- App icon — black rounded square with white crescent moon, exact-pixel sizes generated via CoreGraphics
- Menu bar status icon now uses SF Symbol `moonphase.waxing.crescent` (template, adapts to dark/light), replacing 🌒 emoji
- README CI badge + release download badge

## [0.2.1] — 2026-05-17

### Added
- Dashboard tab now persistent — switching to it via tab bar is remembered across hover collapses (`stickyTab`)
- Debug file logging gated behind `notchy.debugLogging` UserDefault (off by default)
- Comprehensive open-source README with screenshots
- MIT LICENSE
- CONTRIBUTING.md guide
- GitHub Actions CI — build + unit + snapshot tests on macos-15 runner
- Camera / audio / Bluetooth / Calendar entitlements (required even with sandbox off + hardened runtime)

### Fixed
- **Critical**: clicks on play/pause/prev/next buttons now actually fire — `DragInterceptView` was silently swallowing all panel clicks via its default hitTest
- Mirror preview now renders — `PreviewView.layout()` syncs `AVCaptureVideoPreviewLayer.frame` with view bounds
- Media controls remain visible while music is paused (so user can re-play without re-summoning)
- Two-finger horizontal swipe now triggers exactly one track-skip per physical gesture (was triggering 3-5 in a row due to no `NSEvent.phase` handling)
- Media `media-control` command names corrected: `next-track` / `previous-track` (were `next` / `previous`)
- Live activity strip now perfectly flush with the physical notch (queries `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` for actual notch dimensions instead of hardcoded 210pt)
- Accessibility prompt no longer pops on every launch — gated behind UserDefaults flag, only prompts once

## [0.2.0] — 2026-05-17

### Added
- NotchNook-style **live activity flanking strip** — album art on left, animated waveform on right, around the physical notch when media plays
- **Bundled `media-control` CLI** inside `Notchy.app/Contents/Resources/MediaControl/` — no `brew install` required
- **Mirror widget** — front-camera preview via AVCaptureSession
- **Two-finger trackpad swipe** over the notch → next/previous track
- **Click album artwork** → bring source app to front
- **Calendar widget** with EventKit integration
- **Timer / Pomodoro** with 5/15/25-minute presets, ring progress, completion notification
- **System gauge** in Dashboard — CPU + battery readouts
- **Tab bar** at bottom of expanded panel when multiple features active
- **Dashboard** default hover view (clock + date + next event + stats)
- Accessibility prompt on first launch
- `ClickableNotchPanel` + `FirstMouseHostingView` so SwiftUI buttons fire inside a nonactivating panel

### Changed
- `mediaAvailable` semantic now means "track loaded" (playing OR paused), not strictly "playing"
- Scroll-wheel swipe threshold tuned to 25pt with `NSEvent.phase`-bounded firing
- Dashboard layout polished — calendar icon, UP NEXT typography, live event badge, color-graded CPU readout

### Fixed
- Now Playing data via `media-control` subprocess (bypasses macOS 15.4+ TCC block on `MediaRemote.framework`)
- Hover keep-alive zone grows to full panel (540×220) when expanded — cursor can move into panel content without collapsing
- Click-through panel: `ignoresMouseEvents` dynamically toggled based on expansion state
- Real album artwork rendering (base64 JPEG → NSImage)
- Multi-display drag-session reattachment on screen-parameter change
- Settings window via `NSHostingController` + `NSWindow` (SwiftUI Settings scene unreliable for `LSUIElement` apps)

## [0.1.0] — 2026-05-17

Initial v1 implementation: panel rendering, hover state machine, Now Playing via private MediaRemote API (later replaced by media-control adapter), Drop tray, AirPods burst.
