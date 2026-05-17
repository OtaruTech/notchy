# Notchy v2 — Design Spec

**Date:** 2026-05-17
**Author:** zhangjie (designed autonomously with Claude per user delegation)
**Status:** Approved for implementation planning (user pre-approved v2 scope per Claude's recommendation)
**Repo:** https://github.com/OtaruTech/notchy
**Prior spec:** `docs/superpowers/specs/2026-05-17-notchy-design.md` (v1, commit `8a93c82`)

---

## 1. Purpose

Build out the v1 foundation into a more usable daily tool. v2 focus is **depth + polish, not breadth**: a few high-leverage features that take meaningful advantage of the v1 architecture, plus targeted refactors that eliminate v1 shortcuts.

### Non-goals (v2 explicitly defers)

- Notification hijacking (deep private-API territory, fragile)
- Non-notched MacBook simulation overlay (entirely new feature surface)
- Localization (still personal install — English only)
- Sparkle auto-updater (requires paid Developer ID account)
- Full-screen scrubber drag-to-seek (visual polish — v3)
- App Store distribution (still blocked by `MediaRemote` private API)

---

## 2. v2 Feature Scope

Six deliverables, three new user-facing features + three internal improvements:

### User-facing features

| ID | Name | Description |
|---|---|---|
| F4 | **Multi-feature tab switcher** | When the notch is expanded and multiple features have content available, show a tiny tab strip at the bottom of the expanded panel. User can switch between Media / Drop / AirPods / Calendar / Timer without dismissing. |
| F5 | **Calendar widget** | Today's upcoming events from EventKit. Shown either in its own expanded slot (hover with no media) or as a section in the tab switcher. Click an event → opens Calendar.app at that event. |
| F6 | **Timer / pomodoro** | A quick countdown from the menu bar or a slash on the notch. Pomodoro presets (25min/5min/15min). Notch shows progress as a thin ring or progress bar on the bottom edge. Notification on completion. |
| F7 | **System gauge pill** | Subtle status: CPU% + battery% in a tiny pill on the right edge of the notch. Always visible when not expanded. Toggleable in Settings. |

### Polish / refactor

| ID | Name | Description |
|---|---|---|
| P1 | **`withObservationTracking` refactor** | Replace the 100ms busy-loop in `AppDelegate.stateObservation` with proper observation tracking. Removes background CPU and is the right Swift 6 pattern. |
| P2 | **Shared snapshot test helper** | Extract the `host<V: View>(_:width:height:)` helper from `MediaViewSnapshots`, `DropViewSnapshots`, `AirPodsViewSnapshots` into one place (`NotchySnapshotTests/SnapshotHosting.swift`). |
| P3 | **Multi-display robustness** | Lid close/open and external monitor plug/unplug — the panel currently recreates on `didChangeScreenParametersNotification` but doesn't always re-attach the drag session intermediary view. Audit + fix. |

---

## 3. Constraints (unchanged from v1, restated)

| Constraint | Value |
|---|---|
| Minimum macOS | 14.0 (Sonoma) — unchanged |
| Architecture | Apple Silicon only — unchanged |
| Language | Swift 6.2 strict concurrency complete — unchanged |
| UI | SwiftUI + AppKit — unchanged |
| Build | Xcode 16+, xcodegen, SwiftPM — unchanged |
| Signing | Free Personal Team — unchanged |

**New entitlement:** `EventKit` access requires `NSCalendarsUsageDescription` in `Info.plist` + first-launch permission prompt for F5.

---

## 4. Architecture changes from v1

### 4.1 New modules

| Module | Layer | Responsibility |
|---|---|---|
| `CalendarFeature` (`@MainActor @Observable`) | Feature | EventKit subscription, today's events VM |
| `EventKitBridge` (actor) | System | `EKEventStore` async wrappers, permission flow |
| `CalendarView` (SwiftUI) | UI | Today's events list, click-to-open |
| `TimerFeature` (`@MainActor @Observable`) | Feature | Countdown state, pomodoro presets, completion notification |
| `TimerView` (SwiftUI) | UI | Time display, start/pause/reset buttons, preset chips |
| `SystemMonitorFeature` (`@MainActor @Observable`) | Feature | Polls CPU + battery every 2s |
| `SystemMonitorBridge` (actor) | System | `host_processor_info` for CPU; `IOPowerSources` for battery |
| `GaugePill` (SwiftUI) | UI | Tiny right-edge pill always shown in idle |
| `NotchTabBar` (SwiftUI) | UI | Bottom tab strip in expanded view |
| `SnapshotHosting.swift` | Tests | Shared `host<V>(_:width:height:)` helper |

### 4.2 State machine changes

`NotchState` adds `.calendar` and `.timer` cases. `NotchIntent` adds `.calendarAvailabilityChanged(Bool)`, `.timerTicked`, `.timerStarted`, `.timerCompleted`, `.tabSwitchedTo(NotchState)`.

State transitions:
- Hover → if multiple features available (media + calendar), expand to **last-active** feature (default media)
- Hover with **only calendar available** (no media playing) → expand to calendar
- Tab tap → switch active expanded state
- Timer running → background hint + when expanded, can show timer in its own tab

### 4.3 Tab switcher

Bottom strip inside the expanded panel:
- Renders only when ≥ 2 features have content available
- Shows icon-only tabs (no labels) to save space; tooltip on hover
- Active tab highlighted with feature's glow color
- Order: Media, Drop, AirPods, Calendar, Timer (only show ones with content)
- Click sends `.tabSwitchedTo(.foo)` intent

### 4.4 Observation refactor (P1)

Replace AppDelegate.stateObservation Task with:

```swift
func observeStateChanges() {
    withObservationTracking { _ = stateMachine.state } onChange: {
        Task { @MainActor [weak self] in
            self?.handleStateChange()
            self?.observeStateChanges()  // re-subscribe
        }
    }
}
```

`handleStateChange()` triggers the 3s airpods timer when state == .airpods.

---

## 5. v2 Acceptance checklist (in addition to v1's)

- [ ] Tab strip appears at bottom of expanded panel when ≥ 2 features active
- [ ] Tapping a tab switches feature without dismissing
- [ ] Calendar widget shows today's events (no media + hover → calendar shown)
- [ ] Click an event → Calendar.app opens at that event
- [ ] EventKit permission prompt appears on first calendar use
- [ ] Timer can be started from menu bar with presets
- [ ] Timer progress shows as 2pt ring/bar at bottom of notch when idle
- [ ] Timer completion fires `UNUserNotificationCenter` alert
- [ ] System gauge pill (CPU + battery) shows on right edge in idle state
- [ ] Toggling gauge pill in Settings hides/shows it without restart
- [ ] CPU idle < 2% (slight bump from v1's < 1% due to monitoring + EventKit)
- [ ] `withObservationTracking` refactor — no 100ms busy-loop in Activity Monitor
- [ ] Snapshot host helper extracted to single file
- [ ] All v1 acceptance items still pass

---

## 6. Open trade-offs

| Question | Resolution |
|---|---|
| Tab bar icons or text? | **Icons only** (label as tooltip). Space is tight. |
| Calendar = own expanded view or part of media area? | **Own view** when no media; tab-accessible when media playing. |
| Timer notification — banner or alert? | **Banner** + sound (less intrusive). |
| Gauge pill — left or right edge? | **Right edge** (left edge sometimes covers menu-bar items). |

---

## 7. Files to add / modify

### New files
- `Notchy/Features/Calendar/CalendarFeature.swift`
- `Notchy/Features/Calendar/EventVM.swift`
- `Notchy/Features/Calendar/CalendarView.swift`
- `Notchy/Features/Timer/TimerFeature.swift`
- `Notchy/Features/Timer/TimerView.swift`
- `Notchy/Features/SystemMonitor/SystemMonitorFeature.swift`
- `Notchy/Features/SystemMonitor/GaugePill.swift`
- `Notchy/System/EventKitBridge.swift`
- `Notchy/System/SystemMonitorBridge.swift`
- `Notchy/UI/NotchTabBar.swift`
- `NotchySnapshotTests/SnapshotHosting.swift` (P2 extract)
- `NotchySnapshotTests/CalendarViewSnapshots.swift`
- `NotchySnapshotTests/TimerViewSnapshots.swift`
- `NotchySnapshotTests/GaugePillSnapshots.swift`
- `NotchySnapshotTests/NotchTabBarSnapshots.swift`
- `NotchyTests/CalendarFeatureTests.swift`
- `NotchyTests/TimerFeatureTests.swift`
- `NotchyTests/SystemMonitorTests.swift`

### Modified
- `Notchy/State/NotchState.swift` — add `.calendar`, `.timer` cases
- `Notchy/State/NotchIntent.swift` — add new intents
- `Notchy/State/NotchStateMachine.swift` — handle new intents
- `Notchy/UI/NotchExpandedView.swift` — render Calendar/Timer cases; add tab bar at bottom
- `Notchy/UI/NotchShell.swift` — thread Calendar/Timer/SystemMonitor features through
- `Notchy/App/AppDelegate.swift` — instantiate new features, replace busy-loop with `withObservationTracking`
- `Notchy/Settings/SettingsView.swift` — add toggles for gauge pill
- `Notchy/Info.plist` (via `project.yml` properties) — add `NSCalendarsUsageDescription`
- All three existing snapshot files — replace inline `host` helper with import of shared one

---

## 8. Implementation phases (preview — actual plan in plans/2026-05-17-notchy-v2.md)

| Phase | Tasks | Goal |
|---|---|---|
| v2-0 | State + intent extensions | New cases compile, reducer handles them |
| v2-1 | Shared snapshot helper (P2) | Single `host` function, all 3 existing snapshot files refactored |
| v2-2 | Observation refactor (P1) | Busy-loop gone, behavior preserved |
| v2-3 | Tab bar (F4 — UI only) | NotchTabBar component + snapshot |
| v2-4 | Calendar (F5) | EventKitBridge + CalendarFeature + CalendarView + tests + snapshot |
| v2-5 | Timer (F6) | TimerFeature + TimerView + menubar entry + tests + snapshot |
| v2-6 | System monitor (F7) | SystemMonitorFeature + GaugePill + tests + snapshot |
| v2-7 | Integration + tab-bar wire | All features in NotchShell, tab bar gates on availability |
| v2-8 | Multi-display polish (P3) | Audit drag session re-attach on screen change |
| v2-9 | Acceptance | Walk new checklist, verify all v1 items still green |

---

## 9. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| EventKit permission denied | Medium | Calendar feature inert | Show "Grant access" CTA in expanded view; rest of app unaffected |
| `host_processor_info` returns stale data | Low | Misleading CPU% | Compute deltas vs prior sample (standard pattern) |
| Tab bar exceeds notch width with 5 features | Medium | Layout breaks | Cap at 4 visible tabs + overflow menu; drop airpods tab when no AirPods |
| `withObservationTracking` re-subscribe leak | Medium | Slow CPU growth | Test by toggling states 100x and watching Activity Monitor |
| Adding 4 new features blows context window | High | Hard to refactor | Each feature is ≤ 250 lines, split as needed |

---

## 10. Next steps

After this spec, transition to `superpowers:writing-plans` for the v2 implementation plan.
