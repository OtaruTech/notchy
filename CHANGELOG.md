# Changelog

All notable changes to Notchy. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Dashboard tab now persistent — switching to it via tab bar is remembered across hover collapses (`stickyTab`)
- Debug file logging gated behind `notchy.debugLogging` UserDefault (off by default)
- Comprehensive open-source README with screenshots
- MIT LICENSE
- CONTRIBUTING.md guide

### Fixed
- **Critical**: clicks on play/pause/prev/next buttons now actually fire — `DragInterceptView` was silently swallowing all panel clicks via its default hitTest
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
