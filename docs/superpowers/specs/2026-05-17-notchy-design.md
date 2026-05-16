# Notchy — Design Spec

**Date:** 2026-05-17
**Author:** zhangjie (with Claude)
**Status:** Approved for implementation planning
**Repo:** https://github.com/OtaruTech/notchy

---

## 1. Purpose

A macOS menu-bar-resident utility that turns the MacBook's hardware notch into an interactive, animated surface — inspired by NotchNook. For personal install on the author's MacBook (Apple Silicon, hardware-notched), distributed via local developer signing.

### Non-goals (v1)
- App Store distribution (uses private framework `MediaRemote` — not allowed)
- Non-notched MacBook support (no simulated notch overlay)
- Intel Mac support
- Localization (English UI only)
- Custom widgets / extensions / plugin SDK

---

## 2. v1 Feature Scope

Three互斥 features, all gated by a single state machine:

| ID | Name | Trigger | Display |
|---|---|---|---|
| F1 | **Now Playing** | Hover over notch hot zone while media is active | Album art, title/artist, scrubber, play/pause + prev/next |
| F2 | **Drop Tray** | Drag a file into notch hot zone | File chips + AirDrop / Email / Clear actions |
| F3 | **AirPods Burst** | Bluetooth ACL connect event for known AirPods | Device name + L/R/Case battery; auto-dismiss after 3s |

Features explicitly deferred to v2: calendar/weather widgets, system notification hijacking, timer/pomodoro, CPU/network monitor, multi-feature tab switcher.

---

## 3. Constraints

| Constraint | Value |
|---|---|
| Minimum macOS | 14.0 (Sonoma) |
| Architecture | Apple Silicon only (arm64) |
| Hardware target | MacBooks with hardware notch |
| Language | Swift 6.2 (strict concurrency: complete) |
| UI | SwiftUI + AppKit interop (`NSPanel`) |
| Build | Xcode 16+, SwiftPM (no CocoaPods) |
| Signing | Personal Team (free) — re-sign when certificate expires (~annually) |
| Distribution | Manual `.app` drag to `/Applications` |
| External deps | `swift-snapshot-testing` (tests only). No runtime third-party deps in v1. |

---

## 4. Architecture

### 4.1 Layer diagram

```
┌─────────────────────────────────────────────────────────────┐
│  App Layer        NotchyApp · NotchWindowController         │
├─────────────────────────────────────────────────────────────┤
│  UI Layer         NotchShell · NotchExpandedView            │
│                   FeatureSlot { media | drop | airpods }    │
├─────────────────────────────────────────────────────────────┤
│  Feature Layer    MediaFeature · DropFeature · BTFeature    │
│                   NotchStateMachine                         │
├─────────────────────────────────────────────────────────────┤
│  System Layer     MediaRemoteBridge · IOBluetoothBridge ·   │
│                   DragSession · ScreenGeometry              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Module boundaries

Each module has one clear job and is reachable through a well-defined interface only:

| Module | Responsibility | Public surface |
|---|---|---|
| `NotchyApp` | SwiftUI `@main` entry, lifecycle, login-item registration | — (entry) |
| `NotchWindowController` | Creates/positions/destroys the borderless `NSPanel` over the notch, owns screen-change observers | `show()`, `hide()`, `frame(for: NSScreen)` |
| `NotchStateMachine` | Single source of truth for what the notch shows. Receives intents, emits `NotchState` | `send(_ intent: Intent)`, `state: AsyncStream<NotchState>` |
| `NotchShell` (View) | Animates between collapsed / expanded; routes to active `FeatureSlot` | bound to `state` |
| `MediaFeature` (@Observable) | Subscribes to `MediaRemoteBridge`; transforms raw "now playing" into view model | `nowPlaying: NowPlayingVM?`, `playPause()`, `prev()`, `next()` |
| `DropFeature` (@Observable) | Owns the in-flight + persisted tray (in-memory, cleared on quit) | `items: [DropItem]`, `add(_:)`, `remove(_:)`, `clearAll()` |
| `BTFeature` (@Observable) | Listens to `IOBluetoothBridge` for connect/disconnect; reads battery | `connectedDevice: BTDeviceVM?` |
| `MediaRemoteBridge` (actor) | `dlopen` private `MediaRemote.framework`, expose typed API. **Only place private symbols touch the codebase.** | `nowPlayingInfo() async -> RawInfo?`, `sendCommand(_:)`, `subscribeChanges() -> AsyncStream<RawInfo>` |
| `IOBluetoothBridge` (actor) | `IOBluetooth` callbacks → Swift async stream; IORegistry battery reads | `connectionEvents() -> AsyncStream<BTEvent>`, `battery(for:) -> BatteryReading?` |
| `DragSession` | NSDraggingDestination glue → `DropFeature` | `attach(to:)` |
| `ScreenGeometry` | Computes notch rect from `NSScreen.safeAreaInsets`; handles multi-display, notch-on-secondary edge cases | `notchRect(on:) -> CGRect?`, `hotZone(on:) -> CGRect` |

Every system bridge is an `actor`. Every UI thing is `@MainActor`. State machine is `@MainActor` (cheap, all on the hop).

### 4.3 State machine

```
              hover (with media playing)
        ┌──────────────────────────────┐
        │                              ▼
   ┌─────────┐   drag-enter        ┌─────────┐
   │  Idle   │ ─────────────────► │  Drop   │
   │ (Hint?) │                    └────┬────┘
   └────┬────┘ ◄────────── leave/drop ──┘
        │
        │  hover (no media playing) → no-op
        │
        │  bt-connect
        ▼
   ┌─────────┐
   │ AirPods │ ── 3s timer ──► back to prev (or Idle)
   └─────────┘
```

`Idle` may include a **hint pill** (3pt high) under the physical notch while media plays — purely cosmetic affordance, not an expanded state. Esc and outside-click force back to `Idle`. Re-trigger of the active feature resets the dismiss timer.

### 4.4 Visual language

"Liquid Dark": pure black panel (`#000000`), 28pt rounded bottom corners, no top corners (flush with hardware notch). Glow shadow color matches active feature (purple media / cyan drop / green airpods). Spring animation `response: 0.42, dampingFraction: 0.78` for all expand/collapse and content transitions. SF Pro Display / SF Mono for typography. No translucency / vibrancy — solid black.

Expanded panel base size: **540 × 180 pt**. Drop tray can grow to **540 × 220** when 4+ files.

### 4.5 Data flow

```
[System events]  →  [Bridge actor]  →  [Feature @Observable]  →  [SwiftUI View binding]
                                            │
                                            └─►  [StateMachine intent: .featureRequest]
```

User intents (hover / drag / Esc / click) flow:
```
[NSPanel event monitors] → [StateMachine.send] → [state] → [NotchShell renders]
```

State machine is the only writer to `NotchState`. Features push *availability* updates (e.g. "media just started", "AirPods connected") as intents — they do not control what's currently shown.

---

## 5. Interaction Spec

| Trigger | Action | Delay | Dismiss |
|---|---|---|---|
| Mouse enters notch hot zone (notch rect + 4pt buffer) | Expand to current available feature (Media if playing, else no-op) | 120ms | Mouse leaves for 250ms |
| File drag enters hot zone | Force `Drop` state, expand tray | 0ms | Drag exits + 5s, or drop completed |
| Bluetooth connect event for AirPods | Force `AirPods` state | 0ms | 3s auto-timer |
| Media starts playing | Show hint pill below notch (no expansion) | 0ms | Media stops |
| Esc / outside click | Collapse to Idle | 0ms | — |
| Re-trigger active feature | Reset dismiss timer | — | — |

Hot zone is the physical notch rect plus 4pt below it. Hot zone is not "the entire menu bar" — to avoid hijacking other menu-bar interactions.

---

## 6. Private API & Permissions

| Resource | API | Risk | Mitigation |
|---|---|---|---|
| Now Playing data | `MediaRemote.framework` (private) | macOS major version may change symbols | All private calls isolated in `MediaRemoteBridge.swift`. Failure mode = Media feature disabled, others unaffected. Fallback to `MPNowPlayingInfoCenter` (incomplete but functional). |
| AirPods battery & connection | `IOBluetooth` + IORegistry | Public APIs but battery key format is undocumented | Parse defensively, treat missing keys as nil. |
| Bluetooth scanning | `CoreBluetooth` | Requires `NSBluetoothAlwaysUsageDescription` user consent | First-launch prompt; AirPods feature gracefully disabled if denied. |
| File drag | `NSDraggingDestination` | None | — |
| Login item | `SMAppService` (macOS 13+) | None | — |

**Accepted risk:** Private API usage means no App Store. Acceptable per project scope.

---

## 7. Error Handling

- **Private API failure** — `MediaRemoteBridge` catches and emits a `.unavailable` reading; `MediaFeature` shows "Media unavailable" tile but doesn't crash. Other features unaffected.
- **Bluetooth permission denied** — `BTFeature` enters disabled state; settings panel offers "Re-request permission".
- **NSPanel creation failure or screen reconfiguration** — `NotchWindowController` observes `NSApplication.didChangeScreenParametersNotification`, recreates panel on the active notched screen (main screen with `safeAreaInsets.top > 0`). If no notched screen present, panel hides until one returns.
- **Crash / signal** — register `SIGTERM`/`SIGABRT` handlers that force-hide the panel before exit, so no black bar is left lingering.
- **Multi-display** — panel attaches to whichever screen has the notch. If user mirrors or unplugs, recompute and reattach.

---

## 8. Testing Strategy

| Layer | Tool | Goal |
|---|---|---|
| Unit | Swift `Testing` framework | `NotchStateMachine` transitions, `MediaRemoteBridge` parsers, `BatteryReading` parser, `ScreenGeometry.notchRect` math |
| Snapshot | `swift-snapshot-testing` | Three expanded states × {short text, long text, missing artwork} × {appearance variations if any} |
| Integration | XCUITest + real hardware hover | Hover-to-expand timing, drag a file into tray, AirPods burst on real connect |
| Manual | Checklist (§10) | All features end-to-end |

**Coverage target:** business logic layer (state machine, bridges' pure-Swift portions, parsers) ≥ 80%. View code covered by snapshots — line coverage not enforced.

---

## 9. Packaging & Install

1. Xcode `Product → Archive`
2. `Distribute App → Copy App`
3. Drag `Notchy.app` → `/Applications`
4. First launch: right-click → Open (bypass Gatekeeper warning)
5. Settings → enable "Launch at Login" (uses `SMAppService.mainApp.register()`)

**Re-sign cycle:** Free Personal Team development certificates are typically valid for ~1 year. macOS does not enforce the iOS-style 7-day local-run kill switch — a signed `.app` keeps running, but the certificate underneath will eventually expire and need re-issue (just re-Archive). The 7-day / 90-day numbers some sources cite apply to iOS sideloading, not macOS. Document the re-sign procedure (open Xcode → Archive → Copy App → replace `/Applications/Notchy.app`) in `README.md`.

**Optional v2:** Sparkle auto-updater + Developer ID signing if user upgrades to paid account.

---

## 10. v1 Acceptance Checklist

- [ ] App launches with no UI other than the (invisible) notch overlay
- [ ] Hover notch with no media playing → no expansion
- [ ] Hover notch with Music.app (Apple Music) playing → Now Playing panel expands
- [ ] Same with Spotify, Safari video (HTML5), VLC
- [ ] Play/Pause/Prev/Next buttons work
- [ ] Scrubber displays current position; drag to seek works
- [ ] Drag a file from Finder onto notch → Drop tray expands
- [ ] Drag a file *out* of tray to Finder → file remains in tray (chip not consumed) and Finder gets a copy
- [ ] AirDrop quick action opens AirDrop sheet with tray items pre-selected
- [ ] Clear all empties tray immediately
- [ ] AirPods Pro 2 connect → panel auto-expands; battery L/R/Case shown; auto-dismisses after 3s
- [ ] Esc dismisses any expanded state immediately
- [ ] Outside-click dismisses
- [ ] CPU usage with notch idle < 1% on M-series
- [ ] No leaked NSPanel after screen-config changes (lid close/open, external monitor plug/unplug)
- [ ] Login-at-startup toggle works and persists
- [ ] Right-click-open Gatekeeper bypass succeeds on a fresh install

---

## 11. Open Questions (resolve during planning)

- Drag-out behavior: copy or move? (Default copy via `NSFilePromiseProvider`)
- Hint pill: opt-out toggle in settings?
- Settings UI: prefer SwiftUI `Settings` scene vs a custom popover from the notch?
- Sparkle integration timing — v1 or v2?

These are deliberately left for the implementation plan to settle; they don't change architecture.

---

## 12. Risks & Open Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| macOS 15/16 breaks `MediaRemote` | Medium | High (Media feature down) | Bridge isolation; fallback path; CI snapshot test on new macOS betas. |
| AirPods battery key format changes | Low | Medium | Defensive parse; show "—" when unreadable. |
| Personal Team certificate expires (~1y) → next install/update fails to sign | Medium | Low (re-Archive) | README install instructions; cert renewal is annual, document the steps. |
| Notch hot zone conflicts with menu-bar apps | Low | Medium | Hot zone strictly notch rect + 4pt buffer; doesn't extend into menu-bar items. |

---

## 13. Next Steps

After this spec is approved by the user, transition to the **superpowers:writing-plans** skill to produce a phased implementation plan (sprint breakdown, file-level TODOs, test-first sequencing).
