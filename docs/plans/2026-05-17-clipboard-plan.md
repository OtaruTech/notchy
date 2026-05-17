# Implementation plan — Clipboard manager (v0.3)

**PRD:** [clipboard-prd.md](../specs/2026-05-17-clipboard-prd.md)
**Target ship:** v0.3.0
**Owner:** Notchy

---

## Phasing

| Phase | Scope | Build target |
|-------|-------|--------------|
| **0** | Foundation: storage, models, capture engine | green build, can read items via lldb |
| **1** | Hotkey + panel UI shell (no real data) | ⌘⇧V opens an empty panel with search |
| **2** | Wire capture → panel; navigation + click paste | end-to-end MVP working |
| **3** | App exclusions, retention, pause toggle | settings polish |
| **4** | Settings tab, snapshot tests, polish | ready for release |

Each phase ends with a commit. Phase 4 ends with a v0.3.0 tag.

---

## File layout

```
Notchy/
├── Features/
│   └── Clipboard/
│       ├── ClipboardItem.swift            # the model + Kind enum
│       ├── ClipboardStore.swift           # SQLite layer (actor)
│       ├── ClipboardCapturer.swift        # NSPasteboard polling
│       ├── ClipboardFeature.swift         # @Observable orchestrator
│       ├── PasteEngine.swift              # write to NSPaste + synth ⌘V + restore
│       ├── ItemKindDetector.swift         # heuristics: image / file / color / url / code / text
│       ├── ClipboardPanel.swift           # SwiftUI panel (search + cards + nav)
│       ├── ItemCard.swift                 # one card view (kind-aware preview)
│       └── ClipboardSettingsView.swift    # settings tab body
└── App/
    └── AppDelegate.swift                  # wire feature + hotkey
```

Tests under `NotchyTests/Clipboard*` (unit) and `NotchySnapshotTests/ClipboardPanel*` (visual).

---

## Phase 0 — Foundation (no UI)

### 0.1 Model

`ClipboardItem.swift`
```swift
struct ClipboardItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: Kind
    let contentHash: String
    let payloadText: String?
    let payloadPath: URL?
    let preview: String
    let sourceBundle: String?
    let sourceName: String?
    let byteSize: Int
    let createdAt: Date
    let updatedAt: Date
    let pinned: Bool

    enum Kind: String, Sendable, CaseIterable {
        case text, richtext, url, image, file, color, code
    }
}
```

### 0.2 Storage

`ClipboardStore.swift` — `actor`, wraps `sqlite3` via `import SQLite3`.

```swift
actor ClipboardStore {
    func open(at url: URL) throws
    func insert(_ item: ClipboardItem) throws
    func update(id: UUID, updatedAt: Date) throws
    func softDelete(id: UUID) throws
    func recent(limit: Int, kindsFilter: Set<ClipboardItem.Kind>?) throws -> [ClipboardItem]
    func search(_ query: String, limit: Int) throws -> [ClipboardItem]
    func purgeOlderThan(days: Int) throws -> Int
    func clearAll() throws
    func count() throws -> Int
}
```

Schema migration: single `schema_version` table, start at 1.

DB location: `~/Library/Application Support/tech.otaru.Notchy/clipboard.sqlite`.
Image files: same dir under `images/<uuid>.png`.

### 0.3 Capture

`ClipboardCapturer.swift` — `actor`, owns a `Timer`-driven loop.

```swift
actor ClipboardCapturer {
    func start(store: ClipboardStore, exclusions: Set<String>)
    func stop()
    func setPaused(_ paused: Bool)
}
```

Polling: every 500 ms, read `NSPasteboard.general.changeCount`. If changed:
- Read frontmost app bundle ID; check exclusions; check `ConcealedType` UTI
- Detect kind via `ItemKindDetector`
- Hash content → if matches most-recent item, just bump `updatedAt`
- Else `store.insert(item)`

### 0.4 Kind detection

`ItemKindDetector.swift` — pure functions. Priority order described in PRD §5.3.

### 0.5 Feature orchestrator (no UI yet)

`ClipboardFeature.swift` — `@MainActor @Observable`. Holds `recent: [ClipboardItem]`. Reloads when notified by capturer.

**Phase 0 acceptance:** unit tests pass; app launches; copying things populates the SQLite file (verified via `sqlite3 clipboard.sqlite "SELECT count(*) FROM items;"`).

**Commit message:**
> feat(clipboard): storage + capture engine (no UI yet)

---

## Phase 1 — Panel shell + hotkey

### 1.1 Wire hotkey

Extend `HotKeyCenter` with a new action:

```swift
enum Action: UInt32 {
    case toggleDashboard = 1
    case toggleMirror    = 2
    case toggleClipboard = 3  // NEW — ⌘⇧V
}
```

Register `kVK_ANSI_V` + `cmdKey|shiftKey` → `.toggleClipboard`.

In `AppDelegate.HotKeyCenter.onAction`:
- If clipboard panel state is open → close
- Else → snapshot `NSWorkspace.shared.frontmostApplication`, then send `.clipboardRequested` intent

### 1.2 State machine

Add `case clipboard` to `NotchState`, `case clipboardRequested` to `NotchIntent`, and a clipboard reducer branch that sets `state = .clipboard`.

`isExpanded` returns true for `.clipboard`.

### 1.3 Panel UI

`ClipboardPanel.swift` — SwiftUI view. Top bar:
```swift
HStack {
    Image(systemName: "magnifyingglass")
    TextField("Search clipboard…", text: $query)
    Spacer()
    Text("\(feature.recent.count) items")
}
```

Body: empty state for now (`Text("No items yet — copy something.")`).

Add to `NotchExpandedView.content` switch:
```swift
case .clipboard:
    ClipboardPanel(feature: clipboardFeature, query: $query)
```

`NotchTabBar` gains a clipboard tab (`doc.on.clipboard` SF Symbol) when `feature.recent.count > 0`.

**Phase 1 acceptance:** ⌘⇧V opens an empty Clipboard panel; ⌘⇧V again closes it.

**Commit:**
> feat(clipboard): ⌘⇧V hotkey + empty notch panel shell

---

## Phase 2 — Panel data + paste

### 2.1 Render real cards

Horizontal `ScrollView(.horizontal)` of `ItemCard` instances. Each card 120×160pt.

`ItemCard.swift` switches on `item.kind` to render the preview:
- `.color` → swatch fills top half
- `.image` → `NSImage` from `payloadPath`
- `.url` → favicon (lazy) + URL host
- `.file` → `NSWorkspace.shared.icon(forFile:)` + filename
- `.code` → monospaced first 5 lines, truncated
- `.text` / `.richtext` → 4-line text preview

### 2.2 Keyboard navigation

Track `@State var selectedIndex: Int = 0`. Use `.onKeyPress`:
- `.leftArrow` / `.rightArrow` → move selection
- `.return` → `paste(items[selectedIndex])`
- `.escape` → `dismiss()`
- numeric `1`–`9` → `paste(items[i-1])` (if exists)

Number-key shortcut uses `Character` matching in `.onKeyPress`.

### 2.3 Paste engine

`PasteEngine.swift`:
```swift
@MainActor
enum PasteEngine {
    static func paste(item: ClipboardItem, to app: NSRunningApplication?, restorePrevious: Bool)
}
```

Steps:
1. Snapshot current pasteboard content (for restore)
2. Write `item` to `NSPasteboard.general` (use appropriate type for kind)
3. Activate the target app (if non-nil)
4. Wait 30 ms, synth Cmd-V via `CGEvent.keyboardEvent(keyCode: 9, keyDown: true/false)` with `.maskCommand` flag, post to `.cghidEventTap`
5. If `restorePrevious` true, wait 50 ms, restore prior content

### 2.4 Search

When `query` is non-empty, debounce 100 ms then call `store.search(query)`. Otherwise show `feature.recent`.

**Phase 2 acceptance:** end-to-end loop works — copy → ⌘⇧V → click an item → it pastes into the previously-focused app.

**Commit:**
> feat(clipboard): card rendering, keyboard nav, paste with restoration

---

## Phase 3 — Exclusions, retention, pause

### 3.1 Exclusion list

UserDefault: `notchy.clipboardExcludedBundleIDs` (CSV string).
Default value: `com.1password.macos, com.agilebits.onepassword*, com.bitwarden.desktop, com.apple.keychainaccess, com.lastpass.LastPass`.

Wildcard matching: simple prefix match if ends with `*`.

Capturer checks the frontmost bundle ID at sample time.

### 3.2 Concealed-type respect

In capturer, check `NSPasteboard.general.types` for `org.nspasteboard.ConcealedType` or `org.nspasteboard.TransientType` UTI before reading content. Skip if present.

### 3.3 Retention purge

On app launch and once per hour, call `store.purgeOlderThan(days: UserDefaults...retentionDays)`.

### 3.4 Pause toggle

UserDefault: `notchy.clipboardPaused` (bool). Capturer reads on each tick.

Menu bar: add `"Pause Clipboard"` toggle item next to `Settings…`.

Menu-bar icon: when paused, render a small ⏸ overlay on the moon SF Symbol.

**Phase 3 acceptance:**
- Copying from 1Password produces no item
- Toggling pause from menu stops capture within 1 s
- Items > retention age disappear on next purge tick

**Commit:**
> feat(clipboard): app exclusions, retention purge, pause toggle

---

## Phase 4 — Settings UI, polish, release

### 4.1 Settings tab

Add a third tab to `SettingsView`: "Clipboard"

```swift
.tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
```

Body:
- Master toggle (`clipboardEnabled`)
- Hotkey (display-only for v0.3, settable later)
- Retention picker: Never / 7 days / 30 days / 90 days
- Restore-previous toggle
- Capture images toggle
- Exclusion list editor (multi-line text field, one bundle ID per line)
- `Button("Clear all clipboard history") { ... }` (red, with confirm)
- `Button("Reveal data folder…")` (opens Finder)

### 4.2 Snapshot tests

`NotchySnapshotTests/ClipboardPanelSnapshotTests.swift`:
- Empty state
- 1 item (text)
- 7+ mixed items
- With search query active (no matches)

### 4.3 README + CHANGELOG

- README: new "Clipboard manager" section with screenshot
- CHANGELOG: `## [0.3.0]` section listing every requirement above
- v0.3 release notes
- Bump `MARKETING_VERSION` to `0.3.0`

### 4.4 Tag and release

```
git tag -a v0.3.0 -m "v0.3.0 — Clipboard manager"
git push origin v0.3.0
gh release create v0.3.0 release-build/Notchy-v0.3.0.zip --notes-file ...
```

**Phase 4 acceptance:** all PRD acceptance criteria pass.

**Commit chain:**
> feat(clipboard): settings tab + polish
> chore: bump version to 0.3.0

---

## Dependencies & libraries

- **Zero new SwiftPM deps.** Use `import SQLite3` (libsqlite3 is always available on macOS).
- Existing: SwiftUI, AppKit, Carbon (hotkey), NSPasteboard, NSWorkspace.

---

## Risks called out from PRD §11 & how the plan addresses them

| Risk | Plan response |
|------|---------------|
| RK1 polling CPU | 500 ms tick; only read full content on changeCount diff; capturer is an actor (no main-thread blocking) |
| RK2 image bloat | Phase 0 — separate image files keyed by row; LRU eviction in `store.insert()` when count exceeds cap |
| RK3 password leakage | Phase 3 — default exclusion list + ConcealedType UTI check |
| RK4 synth ⌘V failure | Phase 2 — `paste()` returns success bool; on failure show toast (Phase 4) |
| RK5 hotkey conflict | Phase 4 hint — for v0.3 ship with ⌘⇧V hardcoded but document the override path |
| RK6 cold SQLite | Open DB lazily on first hotkey; reuse prepared statements |

---

## Definition of done (Phase 4 exit)

- [ ] All PRD acceptance criteria (§15) verified live on the dev machine
- [ ] `xcodebuild test` green
- [ ] Snapshot tests committed
- [ ] CHANGELOG entry + README section + screenshot
- [ ] `v0.3.0` tag pushed
- [ ] GitHub release published with signed zip
