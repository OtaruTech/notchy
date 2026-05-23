# Changelog

All notable changes to Notchy. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased] — v0.7

### Changed — Clipboard interaction model

- **Click a card → copies only**, panel stays open. The hard "paste & dismiss" path now lives exclusively on the keyboard (`↩` and `1`–`9`). Rationale: clicks were ambiguous — sometimes you just want the item on the clipboard to paste manually elsewhere, not blindly into the previously-focused app. Mouse and keyboard now serve two distinct, predictable workflows.
- A transient green **"✓ Copied"** badge flashes on the card after a click so the action is acknowledged without a modal or focus shift.
- Footer hint row now starts with `click  copy` to surface the new behavior alongside the existing `↩ paste · 1–9 quick paste · ← → select · esc close`.

### Added — External notification inbox

- Notchy now watches `~/Library/Application Support/tech.otaru.Notchy/inbox/` for JSON files dropped by external producers and renders them as pills below the notch.
- Five notification kinds (`info` / `inputNeeded` / `toolApproval` / `complete` / `error`) drive color, icon, and default sticky/TTL behaviour. Click a pill to dismiss and (if a `cwd` was attached) focus the originating terminal at that directory.
- First integration: a **Claude Code Notification hook** bridge that surfaces "Claude is waiting for your input" / tool-approval / errors as pills under the notch instead of (or alongside) system notifications. Hook script lives in the `everything-claude-code` repo; users register it in `~/.claude/settings.json`.
- The inbox is producer-agnostic — any CLI, cron job, or build watcher can drop a JSON file and Notchy will render it.

## [0.6.0] — 2026-05-18

### Added — Daily polish

- **🍅 Pomodoro stats** — every completed focus session (≥ 3 min) is logged to `~/Library/Application Support/tech.otaru.Notchy/pomodoro-log.json`. TimerView's idle state shows a stats footer with today's count, total minutes, current streak, and a 7-day heat-map of dot indicators. Dashboard gets a `🍅 N today · Mm` row + `🔥 streak` chip when streak ≥ 2.
- **🔔 Lark / 飞书 unread badge** — Dock's accessibility tree is polled every 5s to find the Lark / 飞书 tile and parse its badge value. Dashboard shows `🔔 飞书 <N>` row when there are unread messages; clicking activates Lark.
- **⌨️ Customisable global hotkeys** — every shortcut (`toggleDashboard`, `toggleMirror`, `toggleClipboard`, `toggleCaffeine`) can be remapped from Settings → General. Click the binding chip → press a new chord → applies instantly with `HotKeyCenter.reloadBindings()`. Each row has a one-click "reset to default" button, and a `Reset all to defaults` action in the section footer. Rejects empty modifiers and known system reservations (⌘Q, ⌘W, ⌘Tab, ⌘Space).

### Added — Settings → System → Daily polish

- `notchy.indicatorLarkEnabled` (default true)
- `notchy.indicatorPomodoroEnabled` (default true)
- Per-action hotkey bindings under `notchy.hotkey.<action>` (`{keyCode, modifiers}` dict, Carbon flags)

## [0.5.0] — 2026-05-18

### Added — Workflow copilot

- **🗓 Meeting copilot** — calendar events get a "Starts in N min" countdown and a one-click **Join** button in the dashboard. Auto-detects Zoom / Google Meet / Lark (飞书) / Microsoft Teams / 腾讯会议 / Webex URLs in event.location, event.notes, and event.url.
  - Countdown switches to yellow within 5 min, orange within 1 min, red while in progress.
  - URL opens with the system handler — Lark/Feishu deep links route to the desktop app, others open in the browser.
- **💻 IDE context** — when VSCode / Cursor / Xcode / Windsurf is frontmost, dashboard shows the project name + git branch (`projectName · main`). Project parsed from window title via Accessibility; git branch read from `<projectPath>/.git/HEAD` after walking common project roots (`~/workspace`, `~/Code`, `~/Developer`, `~/Projects`, `~/Documents`, `~`). 30-second branch cache.
- **🔒 SSH session indicator** — periodic `ps -axo pid,etime,command` scan finds active `ssh` / `mosh` processes. Dashboard shows the target hostname + duration as a pill (e.g., `example.com · 2h`). Hostname matching the danger regex (default `prod|production|live`) renders in red. Up to 3 sessions shown; more get `+N` overflow badge.

### Added — Settings → System → Workflow

- `notchy.indicatorIDEContextEnabled` (default true)
- `notchy.indicatorSSHEnabled` (default true)
- `notchy.indicatorSSHDangerPattern` (default `prod|production|live`, user-editable regex)

## [0.4.0] — 2026-05-18

### Added — HUD takeover (signature feature)
- **Volume HUD** — F10/F11/F12 (or any system volume change) drops a pill with the new level out from under the notch. CoreAudio listener on `kAudioDevicePropertyVolumeScalar` covers all output devices including Bluetooth headphones with per-channel scalars.
- **Brightness HUD** — F1/F2 trigger via NSEvent.systemDefined media-key monitor; level read through CoreDisplay's private `CoreDisplay_Display_GetUserBrightness` (dlopen-loaded, no hard dep).
- **Keyboard backlight HUD** — F5/F6; level probed from `AppleHIDKeyboardEventDriverV2` IORegistry service.
- Dedicated transparent `NSPanel` above the main notch panel hosts the HUD, so it shows regardless of the notch's current state (clipboard / dashboard / mirror etc).
- Auto-dismiss timer with proper `Task.isCancelled` handling — multi-listener races no longer wipe the HUD prematurely.

### Added — System status indicators (5×)
- **⚡ Charging wattage** — `IOPSCopyPowerSourcesInfo` + `AdapterDetails.Watts`; adaptive 1s/5s polling. Pill shows "67W · PD fast" classification.
- **🔴 Privacy indicators** — orange mic dot + green camera dot beside the dashboard clock. CoreAudio listener on default input device + AVCaptureDevice `isInUseByAnotherApplication` poll.
- **☕ Caffeine** — spawns `caffeinate -d -i -m` subprocess; toggled by ⌘⌥K global hotkey or dashboard. Survives the panel being closed.
- **📡 Network speed** — `getifaddrs` sampler at 2s cadence, aggregates en* + utun* + bridge* interfaces. Hide-when-idle threshold of 50 KB/s.
- **🔋 BT multi-device battery** — `IOBluetoothDevice.pairedDevices()` filtered by `isConnected`; reads `BatteryPercent` / `BatteryPercentLeft` / `BatteryPercentRight` / `BatteryPercentCase` from IORegistry by `DeviceAddress` match. Auto-classifies airpods / mouse / keyboard / watch / headphones / generic. 30s cadence + immediate refresh on connect/disconnect notifications.

### Added — Settings → System tab
Per-feature toggles for everything above:
- `notchy.hudVolumeEnabled`, `notchy.hudBrightnessEnabled`, `notchy.hudKeyboardEnabled`, `notchy.hudDuration`
- `notchy.indicatorChargingEnabled`, `notchy.indicatorPrivacyEnabled`, `notchy.indicatorCaffeineEnabled`, `notchy.indicatorNetworkEnabled` (+ `notchy.indicatorNetworkHideIdle`), `notchy.indicatorBTDevicesEnabled`

### Fixed
- **Two-finger swipe** no longer skips tracks when interacting with any expanded panel other than `.media` (dashboard / clipboard / mirror / etc). Previously the swipe handler only checked "media loaded" → switching cards in the clipboard panel accidentally skipped the song playing in the background.

## [0.3.1] — 2026-05-18

### Fixed
- **True click-through** outside the notch panel — desktop / menu bar / app windows underneath the notch area now receive clicks normally. Two-window architecture: main panel uses `ignoresMouseEvents` toggling for full transparency, a separate tiny invisible panel sits only over the hardware notch to detect dragged files.
- **Drag-and-drop** detection restored — previously broken because `ignoresMouseEvents = true` was disabling drag events too. The new dedicated drag-target panel solves this without sacrificing click-through.
- **Drop tray no longer auto-dismisses** when cursor leaves the area. Stays open until you press Esc, click outside, or hit Clear all.
- **Per-file delete (×)** button on each drop chip (hover to reveal). One-click removal of a single file without "Clear all".
- **Real Finder icons** on drop chips instead of generic gray placeholders.
- **Clipboard panel** kind-filter chips: All / Text / Links / Images / Files / Colors / Code / Rich with live counts. Click a chip to scope the card row.
- **Clipboard panel** widened to 880×320 with bigger 152×180pt cards and accent-coloured stripes per kind.
- **Clipboard panel** hover-leave no longer collapses the panel mid-interaction (matches Paste.app behaviour).
- **Clipboard panel** correct top padding via `ScreenGeometry.liveNotchHeight()` — search field no longer hides behind the notch.
- **Clipboard 1-9 / Enter / Esc** now reliably trigger paste; root cause was Notchy not being frontmost. Now temporarily becomes a regular activation-policy app while the panel is open.
- **Tab bar suppressed** when the clipboard panel is the active state (it has its own footer hint row).

### Added
- **Phase-A CloudKit prep** — SQLite schema v1 → v2 with `cloud_record_id`, `cloud_modified_at`, `needs_sync` columns. `SyncEngine` protocol + `NoopSyncEngine` (active) + dormant `CloudKitSyncEngine` stub + `CloudKitMapping` for `CKRecord` ↔ `ClipboardItem`. Activation is a one-line swap in AppDelegate once a paid Apple Developer account is provisioned.
- **GitHub Pages landing site** at [`otarutech.github.io/notchy`](https://otarutech.github.io/notchy/) — hero, 8-card feature grid, three spotlight sections, trust strip, download with Gatekeeper bypass tip.
- **Custom og-image** (1200×630) for social sharing — crescent moon + notch shape + Notchy wordmark.
- **Favicon set** (32 / 180 / 512px).
- **README**: clearer first-launch Gatekeeper bypass instructions for users downloading the release zip.

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
