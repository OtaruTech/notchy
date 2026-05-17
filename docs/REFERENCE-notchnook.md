# NotchNook Behavioral Reference (Source-of-Truth for Notchy)

> Captured from public sources on **2026-05-17** for **NotchNook 1.5.5** (latest
> released as of this snapshot, per Setapp listing). Update when NotchNook ships
> major changes.
>
> **Vendor:** lo.cafe / lowtechguys (developer @kinark / Pedro Patricio). NotchNook
> is **not** a Sindre Sorhus product — the original task prompt misattributed it.
> Sindre Sorhus's notch utility is a separate project ("Notchmeister", a free
> playful demo). All findings below refer to lo.cafe's NotchNook only.
>
> **Sources cited inline as `[Sn]`:**
> - [S1] Official product page — https://lo.cafe/notchnook
> - [S2] MacStories review — https://www.macstories.net/reviews/notchnook-and-mediamate-two-apps-to-add-a-dynamic-island-to-the-mac/
> - [S3] MacSources review — https://macsources.com/notchnook-mac-app-review/
> - [S4] iMore "better than ever" — https://www.imore.com/apps/mac-apps/notchnook-app-that-turns-macbook-notch-into-a-dynamic-island-is-now-better-than-ever
> - [S5] iMore "$25 app" — https://www.imore.com/apps/mac-apps/this-dollar25-app-gives-my-macbook-pro-a-dynamic-island-and-it-was-worth-every-penny
> - [S6] Macworld — https://www.macworld.com/article/2406934/notfhnook-macbook-dynamic-island-widgets-files-tray.html
> - [S7] Digital Trends — https://www.digitaltrends.com/computing/app-turns-macbook-notch-into-dynamic-island/
> - [S8] HowToGeek — https://www.howtogeek.com/these-apps-turn-your-macbook-notch-into-a-dynamic-island/
> - [S9] iDownloadBlog announcement — https://www.idownloadblog.com/2024/07/22/nooknotch-mac-app-announcement/
> - [S10] BGR — https://www.bgr.com/tech/this-app-transforms-your-macbook-notch-into-a-useful-dynamic-island/
> - [S11] XDA — https://www.xda-developers.com/i-tried-dynamic-island-on-macbook-how/
> - [S12] Setapp listing — https://setapp.com/apps/notchnook
> - [S13] MacUpdater version history — https://macupdater.net/app_updates/appinfo/lo.cafe.NotchNook/index.html
> - [S14] v1.2 changelog — https://feedback.notchnook.cafe/changelog/v12-released
> - [S15] tsamoudakis.com review — https://www.tsamoudakis.com/give-your-macbooks-notch-the-dynamic-island-treatment-with-notchnook-2/
> - [S16] MacRumors thread — https://forums.macrumors.com/threads/notchnook.2463695/
> - [S17] Multi-monitor performance feedback — https://feedback.notchnook.cafe/p/performance-issues-with-vibration-style-effect-on-multi-monitor-setup
> - [S18] External monitor handler bug — https://feedback.notchnook.cafe/p/notchbook-display-issue-on-external-monitor-with-minimum-handler-height
> - [S19] raphaeljourney comparison — https://raphaeljourney.com/blogs/best-notch-apps-macbook
> - [S20] absolutegeeks summary — https://www.absolutegeeks.com/article/tech-news/notchnook-transforms-the-macbook-notch-into-a-dynamic-island-like-experience/
>
> Where a behavior is **inferred** rather than directly cited, it is marked
> `(inferred)`. Treat inferred items as hypotheses requiring confirmation with a
> live install.

---

## A. Idle state (no interaction)

**A.1 Default appearance.**
"When you're not using it, the NotchNook looks exactly like you'd expect it to —
just the notch and nothing else." [S7] The app does not paint anything around
the notch in the absence of media, drag, AirPods connect, or HUD events.

**A.2 Always-on widgets.**
None by default. Reviewers describe the idle notch as visually inert. No clock,
no CPU pill, no battery — these would be Notchy v2 additions, not NotchNook
parity. (NotchNook does not expose a system-gauge pill in any reviewed version
through 1.5.5.)

**A.3 Live-activity flanking when media plays.**
While media is playing, NotchNook "displays the album artwork and a waveform on
each side of the notch" [S2]. HowToGeek echoes: "a 'Now Playing' animation on
either side of the notch" with album art [S8]. The notch is therefore visually
"slightly wider" during playback, which can be disabled via the *Enable live
activities* setting. [S8]

**A.4 Hint pill / breathing glow.**
No documented breathing or glow when truly idle. The only ambient affordance is
the live-activity strip that appears when media is active.

**A.5 Hidden-notch / full-screen behavior.**
"Notch now shows on hover" even when normally hidden in fullscreen mode (added
in v1.4.4) [S13]. Prior to that, NotchNook could be obscured behind fullscreen
apps. The Now Playing preview, however, "is always visible on top of fullscreen
apps, including fullscreen videos" [S2] — a known UX issue.

**A.6 External (notchless) display behavior.**
"On notchless screens, [NotchNook] transforms into a nice handler with the
exact same functions" [S1] — a "half-sized notch in the middle of the top of
the screen" [S6]. The simulated handler is "visually jarring" on hardware that
has no real notch, per MacStories [S2].

---

## B. Hover behavior

**B.1 Trigger.**
"Common actions are just a hover-and-click away" [S8]. The trigger is
**configurable**: "basic behavior like how the app should open (with a click,
with a hover, with a swipe)" can be selected in Settings. [S8]

**B.2 Hover delay.**
Not explicitly documented. Reviews describe the response as immediate
("reacts" when hovered) [S20]. (inferred: ≤150 ms; matches iPhone Dynamic
Island timing).

**B.3 Animation curve & motion language.**
v1.2 added "Enhanced swipe animations with squeezing when closing" and "more
performant transitions" [S14]. The motion is a spring expand/squeeze, not a
linear slide. Exact damping not published.

**B.4 Default expanded content (no media, no AirPods, no tray content).**
The expanded "nook" hosts whatever widgets the user has configured. Per iMore:
"When you hover the mouse over the notch, the Dynamic Island appears and will
show today's Calendar entries, a Now Playing widget, and the Mirror toggle."
[S4] In other words: the **idle expanded view shows the user's widget layout**;
there is no "empty" expanded state.

**B.5 Expanded dimensions.**
v1.2 introduced "Auto width for the Nook": "No more trying to find more space
to add more widgets, just add them all and watch the nook grow!" [S14]. Width
is therefore data-driven, not fixed. Height fine-tuning was added in v1.4 [S13].

**B.6 Two-finger swipe trigger.**
"click the notch or do a two-finger swipe downward and the notch expands
further, revealing a black box (the 'nook')" [S19]. Scroll-swipe gestures
"works deliciously" [S1].

**B.7 Dismissal.**
Not explicitly documented. (inferred: mouse leaves expanded panel + N ms grace,
or Esc.)

---

## C. Media playback (Now Playing)

**C.1 Trigger.**
**Automatic live activity:** when any compatible app starts playing media, the
flanking album-art + waveform appears around the idle notch [S8][S2]. **Tap to
expand:** clicking/hovering the notch promotes the live activity into the full
"nook" view with larger artwork and full transport controls [S8].

**C.2 Visual treatment when collapsed.**
"Album art and a small wavy line to indicate it's playing" [S10] flanking the
notch. The wave is described variously as "waveform" [S2] and "subtle animated
waveform" [S8].

**C.3 Visual treatment when expanded.**
"Larger album artwork" plus "full playback controls" [S8]. Includes
play/pause/skip controls. Whether a scrubber/progress bar is shown is not
explicitly documented in any reviewed source (inferred: yes, but unconfirmed —
Notchy already implements a scrubber and that matches Dynamic Island parity).

**C.4 Supported apps.**
- **Apple Music** — confirmed [S6][S10]
- **Spotify** — confirmed [S6][S10][S15]
- **YouTube in Safari** — confirmed [S10]
- **VLC Player** — confirmed [S10]
- **SoundCloud** — confirmed [S10]
- **Podcasts on Spotify** — confirmed [S10]
- **Apple Podcasts / QuickTime Player** — explicitly **not** supported in 1.x
  reviews [S6]
- **"Universal media"** — restored in v1.5.1: "Universal media is back! You can
  now see and control media from any app" [S13]. This implies any app that
  registers with `MediaRemote` / `MPNowPlayingInfoCenter`.

**C.5 Global media controlling.**
"Global Media controlling" listed as a v1.2 feature [S14]. Interpretation: the
nook controls whichever app currently owns the Now Playing session, not just a
hard-coded list.

**C.6 Click behavior on the mini player.**
Not explicitly documented. (inferred: click flanking artwork expands the nook;
click larger artwork in expanded view brings the source app forward — "Windows
focus restoring" was added in v1.2 [S14], which strongly suggests this.)

**C.7 Live-activity toggle.**
"You can disable it by turning off Enable live activities in the app settings"
[S8]. The collapsed flanking display is opt-out.

---

## D. File Tray / Drag-and-drop

**D.1 Trigger.**
"When dragging a file to the notch, NotchNook will expand to let you send it
via AirDrop or temporarily store it in the Tray" [S1 paraphrase via search].
"Drag any file on your Mac onto the notch" [S2]. The expansion is
drag-triggered, not hover-triggered, while a drag session is in flight.

**D.2 Visual on drag-enter.**
Tray opens to reveal two drop zones: the **Tray** (storage) and the **AirDrop**
zone [S6][S15]. The expanded panel may be larger than the hover-default view
to accommodate the drop targets.

**D.3 Drag a file out.**
Files "remain in the tray" when dragged to another app; the file is **copied**
to the destination, not moved out: "Files copied without deletion from
original location" [S6]. Macworld: "drag these files to NotchNook to the
'Tray', and once you return to Safari… it's a simple matter of dragging and
dropping the files from the notch and onto a web page." [S4]

**D.4 Multi-file selection.**
v1.5 improved this dramatically: "improved handling for keyboard shortcuts in
the tray including Shift + arrows for selecting, arrow navigation, and Cmd + A
for selecting all files" [S13]. Prior to that, "you can't select more than one
file and move them to a location — you must move them out of the Tray one by
one" [S6].

**D.5 Persistence.**
Files in the tray persist across app focus changes and Spaces. Not documented
whether they persist across reboot. (inferred: yes — described as "short-term
file storage" [S1] but with no auto-expiry mentioned.)

**D.6 AirDrop integration.**
"Drag a file to NotchNook, drop it in the AirDrop box" → triggers the standard
macOS AirDrop sheet [S6][S9]. v1.3 added "AirDrop options" to the file tray
removal/right-click menu [S13]. v1.5 added an explicit "send items from the
tray through AirDrop in the right-click menu" [S13].

**D.7 File preview.**
Not explicitly documented as a Quick Look–style preview. Files appear as chips
with icon + name. (inferred — no review describes a hover-to-preview behavior.)

**D.8 Planned drop-action expansion ("Pipelines").**
The biggest in-flight feature is **Pipelines**: "custom drop actions that run
terminal commands, enabling file interactions like zip/unzip, creating public
links, and resizing files." [S6] Not shipped as of 1.5.5.

---

## E. AirPods / Bluetooth

**E.1 Connect-event behavior.**
NotchNook **does not** ship a dedicated AirPods burst expansion in any
reviewed version. The only AirPods-related behavior documented is in the **HUD
replacement** layer: "The app replicates the volume and brightness indicators
found on iOS and iPadOS, displaying specific icons when using AirPods, AirPods
Max, or Beats headphones." [S1 paraphrase via search results]

That is, when you change volume *and AirPods are the active audio output*, the
HUD that appears at the notch uses the AirPods icon. There is no documented
"AirPods just connected → show L/R/Case battery" Dynamic-Island-style burst in
NotchNook's reviewed feature set.

> **⚠ Notchy divergence:** Notchy v1 ships an explicit "AirPods burst"
> feature (F3) that NotchNook does not appear to have. Notchy is *ahead* on
> this specific feature relative to the reference product.

**E.2 Battery display.**
Not surfaced in reviewed NotchNook documentation. No battery widget, no
percentage on connect.

**E.3 Disconnect animation.**
Not documented.

**E.4 Other Bluetooth audio devices.**
AirPods, AirPods Max, Beats — confirmed icon recognition [S1 paraphrase]. No
generic BT audio device branding documented.

---

## F. Calendar widget

**F.1 Location.**
Inside the expanded nook. When multiple widgets are configured, "the Dynamic
Island will automatically adjust, allowing you to scroll across to Calendar,
music controls, and more" [S10]. Calendar can also appear as a live activity:
"NotchNook displays your calendar events right in the notch and supports live
activities" [S12].

**F.2 Content.**
"Today's Calendar entries" [S4]. "Upcoming events" [S15]. Format is a compact
list. v1.4.3 added "calendar selection settings" — user can pick which calendars
to surface [S13].

**F.3 Click behavior.**
Not explicitly documented. (inferred: opens Calendar.app at the event.)

**F.4 Bug history (informative for testing).**
v1.2 fixed: "Calendar issues resolved across different timezones",
"Calendar repeating meetings now display properly" [S14]. v1.5.1: "Calendar
improvements including event filtering and better formatting" [S13]. Timezones
and recurrence are known sharp edges.

---

## G. Timer / Pomodoro

**G.1 Status.**
**Not shipped.** No reviewed version through 1.5.5 ships a timer or pomodoro
widget. There is no mention in any feature list, MacStories, Setapp, MacUpdater
changelog, or v1.2 changelog.

**G.2 Roadmap.**
Not visible on the public roadmap excerpt. To-dos are listed as "Coming soon"
[S3][S5], but a discrete timer is not promised.

> **⚠ Notchy divergence:** Notchy v2 plans a Timer feature (F6) that NotchNook
> does not have. Notchy will *exceed* NotchNook parity here, not match it.

---

## H. Other widgets

The complete widget inventory in NotchNook 1.5.5:

| Widget | Status | Source |
|---|---|---|
| Media Player | Shipping | [S4][S5] |
| Calendar | Shipping | [S4][S5][S12] |
| Mirror (FaceTime camera preview) | Shipping | [S4][S5][S6] |
| Shortcuts (macOS Shortcuts.app triggers) | Shipping | [S4][S5][S6] |
| Notes | Shipped in v1.4 ("New notes widget") | [S13] |
| Custom GIF widget (user-supplied animated GIF) | Shipped in v1.4.4 | [S13] |
| Apple Notes integration | "Coming soon" | [S4] |
| Quick App launcher | "Coming soon" | [S3][S4] |
| To-dos | "Coming soon" | [S3][S4] |
| Weather | **Not shipped** and not on roadmap | — |
| Stocks | **Not shipped** | — |
| 3rd-party widget SDK | **Not shipped**; Pipelines (drop actions) is the closest thing | [S6] |

**H.1 Mirror specifics.**
"Switches on your Mac's FaceTime camera so you can give yourself a glow-up
before you jump into a video call" [S4]. v1.3 added "Multiple mirror source
support" — pick which camera to mirror [S13]. v1.4 fixed "Camera closure
fixes" [S13]. Known limitation in earlier versions: "doesn't work with my
external camera" [S2].

**H.2 Shortcuts specifics.**
Surface macOS Shortcuts.app triggers. Users can "add a ChatGPT shortcut" [S4]
to the nook for one-click execution.

**H.3 GIF widget.**
"Custom GIF selection for notch display" [S13] — user picks any local GIF as
ambient decoration.

---

## I. Settings / Preferences

**I.1 Entry point.**
Menu-bar icon → opens preferences window. (Standard SwiftUI app pattern;
NotchNook is "built with Swift and SwiftUI" [S3].)

**I.2 Configurable items (consolidated across sources).**

- **Activation gesture** — click / hover / swipe [S8]
- **Notch styling** — "blend, hide, or accentuate the notch" [S3]
- **Space allocation** — overall nook width/height fine-tune [S8][S13]
- **Widget padding** — gap between widgets [S8]
- **Transparency** — material transparency of the panel [S8]
- **HUD replacement** — moves brightness + volume HUDs into the notch [S8]
- **Live activities on/off** [S8]
- **Live-activity bar height (non-notch displays)** — added in v1.3 [S13]
- **HUD indicator display options** — added in v1.4.3 [S13]
- **Calendar selection** — pick which calendars surface — added in v1.4.3 [S13]
- **Custom GIF** — pick a local GIF — added in v1.4.4 [S13]
- **Menu-bar management** — "reorganize and declutter your menu bar" [S1]
- **Multiple Spaces support** — per-Space widget configurations [S3]
- **Rounded button option** — v1.4 [S13]
- **Language** — 29 supported, via Crowdin contributions [S12][S14]

**I.3 Themes.**
No explicit named themes in the conventional sense; styling is via notch-blend
mode + transparency + colors. "Dark/light mode support that integrates with
macOS themes." [S3 paraphrase via search]

**I.4 Account & licensing controls.**
License recovery, 15-day refund window, device-reset email flow [S1]. License
is 2-device for subscription, 5-device for one-time purchase [S1][S5].

---

## J. Trigger gestures (per official feature page + reviews)

| Gesture | Behavior | Source |
|---|---|---|
| Hover (default if enabled) | Reacts; can expand to nook | [S20][S8] |
| Click | Expands to nook | [S5][S19] |
| Two-finger swipe down on notch | Expands the nook | [S19] |
| Scroll-swipe (horizontal) inside notch | Switches between widgets / paginates | [S1][S8] |
| Two-finger horizontal swipe inside notch | Track skip — "move forward or back a track when the cursor is inside the notch" | [S6] |
| File drag into notch | Force-opens tray | [S2][S6] |
| Esc / outside click | Dismiss expanded view | (inferred — standard macOS pattern) |
| Keyboard shortcuts in tray | Arrows nav, Shift+arrows multi-select, Cmd+A select all | [S13] (v1.5) |
| Global keyboard shortcut to summon notch | **Not documented** | — |

**J.1 No global hotkey.**
No reviewed source describes a user-bindable keyboard shortcut to summon the
nook. This is a gap (and an opportunity for Notchy to differentiate).

---

## K. Multi-display behavior

**K.1 Notched-MacBook + external monitor.**
"NotchNook always looks like a notch — even on an external display" [S2]. The
software paints a notch shape on monitors that lack one, which MacStories
calls "visually jarring."

**K.2 Notchless Mac (Mac mini / Mac Studio / iMac) with external display.**
The nook simulates a "half-sized notch in the middle of the top of the screen"
[S6]. Same feature set; just a black floating handle instead of a hardware
notch overlay.

**K.3 Multi-monitor support.**
"NotchNook supports multiple monitors, and having NotchNook available across
all screens is described as a blessing for users with multi-monitor setups."
[S9 paraphrase] All screens get a NotchNook surface.

**K.4 Known bug: handler height on external monitor.**
"When using Notchbook on an external display connected to a Mac Mini, setting
the handler height to the minimum results in the top part of the app being
cut off" [S18].

**K.5 Known bug: vibration-effect lag on multi-monitor.**
"Three-monitor setup, … enabling the 'vibration style effect' while music is
playing causes significant lag in the NotchNook app, … becomes almost unusable
during playback with the vibration effect enabled." [S17]

**K.6 Multi-screen drag fix.**
v1.4.3 added "Performance improvements and fixes for dragging and multi-screen
support" [S13].

**K.7 Lid close / external reconnect.**
Not explicitly documented as a known-good flow. (inferred: NotchNook reacts to
`NSApplication.didChangeScreenParametersNotification` — but no review confirms
clean lid-close behavior.)

---

## L. Performance characteristics (user-reported)

**L.1 Idle CPU.**
Generally low, but **regression in 1.5.x** is the dominant user complaint.
MacRumors thread: "huge CPU usage and/or battery draining too fast" reported
in 1.5.x [S16]. Developer acknowledged: "Improvements were in fact made in the
previous version (1.5.2), but with reports of the issue not being fully solved
for a bunch of people, we'll be investigating it further to fix everything for
once." [S16] Recommended workaround: roll back to 1.4.6 [S16].

**L.2 Memory footprint.**
Setapp lists install size as **59.8 MB** [S12]. Runtime RSS not published.

**L.3 Battery impact.**
v1.4 changelog included "memory/CPU leak corrections" [S13], confirming a
historical pattern of leaks. 1.5.x users still report battery drain [S16].

**L.4 Performance budget targets (inferred for Notchy parity).**
- Idle CPU: **<1%** on Apple Silicon (Notchy v1 acceptance criterion).
- Steady RSS: target **<80 MB** with media + tray + airpods all active.
- No 100 ms polling loops (Notchy v2 P1 refactor — Notchy is *cleaner* than
  NotchNook on this dimension by design).

**L.5 Background runtime model.**
Menu-bar resident, no Dock icon (inferred from "menu bar management" feature
and screenshots — NotchNook is a menu-bar app).

---

## M. System requirements & distribution

- **Minimum macOS:** 14.6 (Sonoma) [S1][S12]. (Earlier versions required 14.0
  [S9].) Notchy v1 currently targets 14.0 which is *more permissive*; consider
  aligning to 14.6 for matching test surface.
- **Architecture:** Apple Silicon and Intel both supported by NotchNook
  ("Intel-based and Apple silicon Macs, notched or not") [S9]. Notchy is
  Apple Silicon only — a deliberate divergence.
- **Languages:** 29 [S12].
- **Distribution channels:** lo.cafe direct, Setapp [S12]. **Not on the Mac
  App Store** [S3], same reason as Notchy: private `MediaRemote` API.
- **Pricing:** $3/mo (2 devices) or $25 one-time (5 devices), 48-hour to
  15-day trial window depending on source [S1][S5][S6].

---

# Acceptance Test Plan for Notchy

Each test gives Given / When / Then / How to verify / Priority. Priorities:
P0 = blocker for v1 ship, P1 = must-have for parity, P2 = polish.

## A. Idle state

### Test A-1
- **Given:** Notchy launched on a hardware-notched MacBook, no media playing,
  no AirPods connecting, no drag in flight.
- **When:** User looks at the screen without interacting.
- **Then:** Notch area is visually identical to the bare macOS notch — no
  glow, no breathing, no pill, no overlay paint.
- **How to verify:** Manual visual inspection + snapshot test of the idle
  panel rendering an empty state.
- **Priority:** P0

### Test A-2
- **Given:** Notchy is running and Apple Music starts playing a track.
- **When:** Track playback begins.
- **Then:** A live-activity strip appears flanking the notch (album art + a
  subtle waveform). Notch otherwise remains collapsed.
- **How to verify:** Manual, with `osascript -e 'tell application "Music" to play'`
  + screenshot diff.
- **Priority:** P1 *(NotchNook ships this; Notchy v1 lists Now Playing but
  does not call out a passive flanking pill — gap to plan.)*

### Test A-3
- **Given:** App in fullscreen (e.g., a YouTube video in fullscreen Safari)
  while music is playing in the background.
- **When:** User moves cursor to the top of the screen.
- **Then:** Notch surface shows on hover even in fullscreen (matches
  NotchNook v1.4.4 behavior).
- **How to verify:** Manual.
- **Priority:** P1

### Test A-4
- **Given:** Notchy running.
- **When:** Cursor is anywhere outside the notch hot zone.
- **Then:** CPU usage attributable to Notchy stays under 1% averaged over 60s.
- **How to verify:** Activity Monitor sample + automated test driven by
  `host_processor_info`.
- **Priority:** P0

### Test A-5
- **Given:** User has disabled live activities in Settings.
- **When:** Apple Music starts playing.
- **Then:** No flanking strip appears; notch remains exactly as bare-macOS.
- **How to verify:** Manual.
- **Priority:** P2 (Notchy doesn't currently expose a live-activities toggle —
  add to Settings to match NotchNook.)

## B. Hover behavior

### Test B-1
- **Given:** Media is playing, hover gesture enabled.
- **When:** Cursor enters notch hot zone (notch rect + 4pt buffer).
- **Then:** Panel expands to Now Playing within 120-150 ms; spring animation
  visible.
- **How to verify:** XCUITest measuring elapsed time from cursor-enter to
  panel-shown.
- **Priority:** P0

### Test B-2
- **Given:** No media playing, no AirPods burst, no drag.
- **When:** Cursor enters notch hot zone.
- **Then:** **Notchy v1 behavior:** no-op (per current design). **Parity
  behavior:** expand to user's configured widget layout (calendar etc.).
- **How to verify:** Manual + snapshot.
- **Priority:** P1 — diverges from NotchNook; Notchy currently has nothing to
  show. Action: either ship a "default widget" or document the gap.

### Test B-3
- **Given:** Panel expanded via hover.
- **When:** Cursor leaves the expanded panel and stays out for ≥250 ms.
- **Then:** Panel collapses with spring animation; no flicker on quick
  re-entry within grace window.
- **How to verify:** XCUITest with timed leave/re-enter.
- **Priority:** P0

### Test B-4
- **Given:** Panel expanded.
- **When:** User presses Esc.
- **Then:** Panel collapses immediately.
- **How to verify:** XCUITest.
- **Priority:** P0

### Test B-5
- **Given:** Settings configured to require click (not hover).
- **When:** Cursor enters notch.
- **Then:** No expansion until click.
- **How to verify:** Manual. *Notchy v1 does not yet expose this toggle —
  add to Settings.*
- **Priority:** P1

## C. Media playback

### Test C-1
- **Given:** Apple Music playing a track with embedded artwork.
- **When:** Hover the notch.
- **Then:** Expanded view shows large album art, track title, artist,
  scrubber with current position, and play/pause/prev/next buttons.
- **How to verify:** Snapshot test (existing `MediaViewSnapshots` covers this)
  + manual.
- **Priority:** P0

### Test C-2
- **Given:** Media playing in Spotify, then user switches to a YouTube video
  in Safari.
- **When:** Spotify pauses and YouTube takes the Now Playing session.
- **Then:** Notchy's Now Playing reflects the YouTube video within 1s; album
  art is YouTube thumbnail or fallback icon.
- **How to verify:** Manual end-to-end.
- **Priority:** P1

### Test C-3
- **Given:** Now Playing panel expanded, music playing.
- **When:** User clicks Pause.
- **Then:** Source app pauses within 100 ms; play icon swaps to play glyph.
- **How to verify:** Manual + log inspection of `MediaRemoteBridge.sendCommand(.pause)`.
- **Priority:** P0

### Test C-4
- **Given:** Now Playing expanded.
- **When:** User clicks Next.
- **Then:** Source app skips to next track; artwork and metadata update
  within 500 ms.
- **How to verify:** Manual.
- **Priority:** P0

### Test C-5
- **Given:** Now Playing expanded with scrubber visible.
- **When:** User drags the scrubber thumb to 50% position.
- **Then:** Source app seeks to that position; scrubber settles at drop point.
- **How to verify:** Manual. *Notchy v1 spec lists scrubber drag-to-seek;
  v2 explicitly defers full-screen drag-to-seek polish.*
- **Priority:** P1

### Test C-6
- **Given:** Music playing; user kills the source app.
- **When:** Source app process terminates.
- **Then:** Now Playing view exits cleanly within 2 s; no stale artwork
  persists.
- **How to verify:** Manual.
- **Priority:** P1

### Test C-7
- **Given:** Track without embedded artwork (e.g., a podcast episode that
  exposes no image).
- **When:** Hover.
- **Then:** Placeholder artwork is shown (gradient or app icon); no crash.
- **How to verify:** Snapshot test with `missing artwork` variant.
- **Priority:** P1

## D. File tray / drag-and-drop

### Test D-1
- **Given:** Notchy idle.
- **When:** User drags a single file from Finder over the notch hot zone.
- **Then:** Drop tray expands within 100 ms revealing two drop targets:
  the tray area and the AirDrop area.
- **How to verify:** XCUITest with simulated drag.
- **Priority:** P0

### Test D-2
- **Given:** Tray contains 3 file chips.
- **When:** User drags one chip out of the tray into a Finder window.
- **Then:** The chip remains in the tray; Finder receives a **copy** of the
  file.
- **How to verify:** Manual + file inode check.
- **Priority:** P0

### Test D-3
- **Given:** Tray contains files.
- **When:** User invokes "Clear all".
- **Then:** Tray empties immediately; chips animate out.
- **How to verify:** Manual + state inspection.
- **Priority:** P0

### Test D-4
- **Given:** Tray contains 2 files.
- **When:** User drags a file onto the AirDrop sub-zone.
- **Then:** macOS AirDrop sheet opens with the file pre-selected.
- **How to verify:** Manual.
- **Priority:** P0

### Test D-5
- **Given:** Tray contains 5 files; focus is inside the tray.
- **When:** User presses Cmd+A.
- **Then:** All 5 chips highlight as selected; subsequent drag drags all 5.
- **How to verify:** Manual. *Matches NotchNook v1.5 keyboard behavior.*
- **Priority:** P1

### Test D-6
- **Given:** Tray contains files; user right-clicks a chip.
- **When:** Context menu opens.
- **Then:** "Send via AirDrop" appears as an option (matches NotchNook v1.5).
- **How to verify:** Manual.
- **Priority:** P1

### Test D-7
- **Given:** Drag in flight over notch, then user drags off-screen and
  releases without dropping on the tray.
- **When:** Drop cancels.
- **Then:** Tray closes after 5s grace (matches Notchy spec) with no
  half-added items.
- **How to verify:** Manual.
- **Priority:** P0

## E. AirPods / Bluetooth

### Test E-1
- **Given:** AirPods Pro 2 not connected; Notchy running.
- **When:** User puts AirPods in ear → BT ACL connect.
- **Then:** Notch expands with device name + L/R/Case battery percentages;
  auto-dismiss after 3 s.
- **How to verify:** Manual with real hardware.
- **Priority:** P0 *(Notchy-only feature; NotchNook does not ship this.
  Verify it works as Notchy's differentiator.)*

### Test E-2
- **Given:** AirPods Max connected; volume HUD enabled.
- **When:** User changes system volume.
- **Then:** HUD shows AirPods Max icon (not generic speaker).
- **How to verify:** Manual. *Matches NotchNook icon-recognition behavior.*
- **Priority:** P1 — Notchy does not yet ship HUD replacement; this is a
  parity gap.

### Test E-3
- **Given:** Beats Solo Pro connected.
- **When:** User changes volume.
- **Then:** HUD recognises Beats icon.
- **How to verify:** Manual.
- **Priority:** P2

### Test E-4
- **Given:** AirPods battery reading unavailable.
- **When:** AirPods burst fires.
- **Then:** Battery values render as "—" placeholder; no crash, no missing
  view.
- **How to verify:** Snapshot test with `missing battery` variant.
- **Priority:** P1

### Test E-5
- **Given:** Bluetooth permission denied at first launch.
- **When:** User opens Settings.
- **Then:** AirPods feature shown disabled with "Re-request permission" CTA.
- **How to verify:** Manual + integration test.
- **Priority:** P0

## F. Calendar widget (v2)

### Test F-1
- **Given:** EventKit access granted; user has 3 events today.
- **When:** Hover notch with no media playing.
- **Then:** Expanded view shows today's events in a compact list with start
  time + title.
- **How to verify:** Snapshot test + manual.
- **Priority:** P1 (v2 only)

### Test F-2
- **Given:** Event with recurring meeting.
- **When:** Calendar view renders.
- **Then:** Recurring meeting appears at correct time (no off-by-day in
  timezones — matches NotchNook v1.2 fix).
- **How to verify:** Unit test on EventVM transform.
- **Priority:** P1

### Test F-3
- **Given:** Calendar view shown.
- **When:** User clicks an event.
- **Then:** Calendar.app opens at that event.
- **How to verify:** Manual + log inspection of `NSWorkspace.open` call.
- **Priority:** P1

### Test F-4
- **Given:** EventKit access denied.
- **When:** Calendar widget would render.
- **Then:** Empty state with "Grant Calendar access" CTA appears.
- **How to verify:** Manual.
- **Priority:** P1

### Test F-5
- **Given:** Settings → "Calendars" → user unchecks "Work" calendar.
- **When:** Calendar view refreshes.
- **Then:** "Work" events no longer appear.
- **How to verify:** Manual.
- **Priority:** P2 *(Matches NotchNook v1.4.3 feature.)*

## G. Timer / Pomodoro (v2 only — Notchy exceeds NotchNook here)

### Test G-1
- **Given:** Menu-bar entry for Timer.
- **When:** User picks 25-minute pomodoro preset.
- **Then:** Timer starts; 2pt ring/bar appears at bottom edge of notch
  showing progress.
- **How to verify:** Manual + snapshot.
- **Priority:** P1

### Test G-2
- **Given:** Timer running.
- **When:** Notch is hovered with no other feature active.
- **Then:** Expanded view shows time remaining + pause/reset buttons.
- **How to verify:** Snapshot.
- **Priority:** P1

### Test G-3
- **Given:** Timer reaches 0.
- **When:** Final tick.
- **Then:** UNUserNotificationCenter banner fires with sound; ring resets.
- **How to verify:** Manual + log.
- **Priority:** P1

### Test G-4
- **Given:** Timer running, system sleeps for 5 min, wakes.
- **When:** Sleep/wake cycle.
- **Then:** Timer accounts for elapsed wall-clock time; doesn't pause silently.
- **How to verify:** Manual.
- **Priority:** P2

## H. Other widgets

### Test H-1 (Mirror)
- **Given:** Mac with built-in FaceTime camera and an external USB camera.
- **When:** User activates Mirror; in Settings picks external source.
- **Then:** External camera feed shown. *Matches NotchNook v1.3 multi-source.*
- **How to verify:** Manual.
- **Priority:** P2 (not in Notchy v1 or v2 scope; planning candidate.)

### Test H-2 (Shortcuts)
- **Given:** User has macOS Shortcut named "Open ChatGPT".
- **When:** Shortcuts widget rendered and user clicks the tile.
- **Then:** Shortcut runs; ChatGPT opens.
- **How to verify:** Manual.
- **Priority:** P2

### Test H-3 (GIF)
- **Given:** User picks a local 200KB GIF in Settings.
- **When:** Idle notch displays.
- **Then:** GIF plays at hardware-notch edge; CPU impact <0.5%.
- **How to verify:** Manual + Activity Monitor.
- **Priority:** P2

## I. Settings / Preferences

### Test I-1
- **Given:** Notchy launched.
- **When:** User clicks menu-bar icon.
- **Then:** Menu opens with at least: Settings… / Quit. Settings opens a
  proper preferences window (SwiftUI Settings scene).
- **How to verify:** Manual.
- **Priority:** P0

### Test I-2
- **Given:** Settings open.
- **When:** User toggles "Launch at Login".
- **Then:** State persists across app restart; `SMAppService.mainApp.status`
  reports `enabled`.
- **How to verify:** Manual + unit test against `SMAppService` stub.
- **Priority:** P0

### Test I-3
- **Given:** Settings open.
- **When:** User toggles the hint-pill (Notchy-specific).
- **Then:** Hint pill toggles immediately; no app restart needed.
- **How to verify:** Manual.
- **Priority:** P1

### Test I-4 (parity)
- **Given:** Settings.
- **When:** User picks "Activation gesture: click | hover | swipe".
- **Then:** Behavior changes immediately. *Notchy currently does not expose
  this — gap.*
- **How to verify:** Manual.
- **Priority:** P1

### Test I-5 (parity)
- **Given:** Settings → HUD Replacement enabled.
- **When:** User changes volume.
- **Then:** macOS volume HUD is suppressed; equivalent HUD renders at the
  notch instead. *Notchy does not ship HUD replacement.*
- **How to verify:** Manual + screen recording diff.
- **Priority:** P2 — explicit divergence; consider scope.

## J. Trigger gestures

### Test J-1
- **Given:** Hover-trigger enabled.
- **When:** Cursor enters hot zone.
- **Then:** Expand (see B-1).
- **Priority:** P0

### Test J-2
- **Given:** Click-trigger enabled.
- **When:** User clicks notch.
- **Then:** Expand. *(Notchy parity gap — add a click-only mode.)*
- **Priority:** P1

### Test J-3
- **Given:** Cursor inside expanded media view.
- **When:** User two-finger horizontal swipes left.
- **Then:** Media skips to previous track (matches NotchNook).
- **How to verify:** Manual on trackpad. *Notchy does not yet ship swipe-skip.*
- **Priority:** P1

### Test J-4
- **Given:** Notch hot zone.
- **When:** User two-finger swipe down.
- **Then:** Nook expands. *Matches raphaeljourney description; Notchy gap.*
- **Priority:** P2

### Test J-5
- **Given:** Notchy bound to a global hotkey (e.g., ⌃⌥Space).
- **When:** Key chord pressed.
- **Then:** Notch expands regardless of cursor position. *NotchNook
  apparently lacks this; Notchy can lead.*
- **Priority:** P2 — out of v1/v2 scope but cheap differentiation.

## K. Multi-display

### Test K-1
- **Given:** MacBook Pro (notched) + external 4K display.
- **When:** User moves cursor to notch on the built-in display.
- **Then:** Nook expands on built-in display only; external display unchanged.
- **How to verify:** Manual.
- **Priority:** P0

### Test K-2
- **Given:** Notchy running; user closes lid (clamshell mode) with external
  display attached.
- **When:** Lid closes.
- **Then:** Notch panel hides (no notched screen present). On lid-open, panel
  recreates on built-in display.
- **How to verify:** Manual.
- **Priority:** P0

### Test K-3
- **Given:** Notchy running.
- **When:** External display unplugged mid-session.
- **Then:** Panel reattaches to the remaining notched screen; no orphaned
  black bar.
- **How to verify:** Manual.
- **Priority:** P0

### Test K-4
- **Given:** Drag session active over notch.
- **When:** External monitor plugged in mid-drag.
- **Then:** Drag session continues without losing files; tray re-attaches to
  the correct screen. *Matches Notchy v2 P3.*
- **How to verify:** Manual.
- **Priority:** P1

### Test K-5
- **Given:** Notchless external display attached.
- **When:** User hovers top-center of external display.
- **Then:** Notchy explicitly **does not** paint a simulated notch (per
  Notchy v1 non-goal). Document this as a deliberate divergence from
  NotchNook in user docs.
- **How to verify:** Manual.
- **Priority:** P1

## L. Performance

### Test L-1
- **Given:** Notchy launched, idle.
- **When:** 60 s of idle observed.
- **Then:** CPU usage <1% average.
- **How to verify:** Activity Monitor script.
- **Priority:** P0

### Test L-2
- **Given:** All v2 features active (calendar, timer, system monitor).
- **When:** 60 s observed.
- **Then:** CPU <2% average.
- **How to verify:** Activity Monitor script.
- **Priority:** P1

### Test L-3
- **Given:** App running 24h with media + drag + airpods events triggered.
- **When:** RSS measured at end.
- **Then:** Memory growth <10 MB above starting baseline (no leaks).
- **How to verify:** `leaks` tool + manual.
- **Priority:** P1

### Test L-4
- **Given:** Notchy running.
- **When:** State toggled 100 times rapidly via test harness.
- **Then:** No `withObservationTracking` re-subscribe leak; CPU returns to
  baseline. *Matches v2 risk register.*
- **How to verify:** Automated stress test.
- **Priority:** P1

### Test L-5
- **Given:** Notchy v1 (no HUD replacement) vs v2.
- **When:** Benchmark cold-launch time.
- **Then:** Cold launch ≤500 ms.
- **How to verify:** `time` wrapper around app launch.
- **Priority:** P2

## M. Distribution & install

### Test M-1
- **Given:** Fresh macOS install.
- **When:** User drags Notchy.app to /Applications and right-click-Opens.
- **Then:** Gatekeeper bypass succeeds; app launches.
- **How to verify:** Manual on clean VM.
- **Priority:** P0

### Test M-2
- **Given:** Personal Team certificate expires.
- **When:** App relaunched after cert expiry.
- **Then:** App keeps running until restart; documented re-sign path works.
- **How to verify:** Manual / documented procedure.
- **Priority:** P1

---

# Gap Analysis: Notchy v0.2.0 vs NotchNook 1.5.5

Read against `/Users/zhangjie/workspace/notchy/docs/superpowers/specs/2026-05-17-notchy-design.md`
(v1) and `…-v2-design.md` (v2 plan).

Legend: ✅ implemented · ⚠ partial · ❌ missing · ❓ different design choice

| NotchNook feature | Notchy status | Notes |
|---|---|---|
| Idle: bare notch | ✅ | Matches. |
| Idle: live-activity flanking strip while media plays | ❌ | Notchy spec mentions a "hint pill" (3pt high) but no flanking album-art strip. **Add to v1.1.** |
| Hover to expand (configurable to click/swipe) | ⚠ | Notchy hardcodes hover at 120 ms; no click-only or swipe-only mode. |
| Auto-grow expanded width based on widget count | ⚠ | Notchy uses fixed 540×180 (and 540×220 for drop). NotchNook 1.2 auto-grows. Acceptable difference at v1 scale. |
| Two-finger swipe-down to expand | ❌ | Not implemented. |
| Two-finger horizontal swipe = track skip | ❌ | Not implemented. |
| Now Playing — Apple Music | ✅ | Via `MediaRemoteBridge`. |
| Now Playing — Spotify | ✅ | Same bridge. |
| Now Playing — Safari HTML5 / YouTube | ✅ | Same bridge. |
| Now Playing — VLC, SoundCloud | ⚠ | Bridge covers them; needs explicit test coverage. |
| Now Playing scrubber drag-to-seek | ⚠ | v1 lists it; v2 spec defers full-screen polish. |
| Click expanded artwork → foreground source app | ❌ | NotchNook ships ("Windows focus restoring" in v1.2). |
| Drop tray expand on drag-enter | ✅ | Matches. |
| Drop tray persistence across focus changes | ✅ | In-memory; matches. |
| Drag-out copies file (not moves) | ✅ | Spec calls out `NSFilePromiseProvider` copy. |
| Multi-file selection in tray (Cmd+A, Shift+arrows) | ❌ | NotchNook v1.5; add to v1.2 backlog. |
| Tray right-click → AirDrop | ⚠ | Notchy has AirDrop button at panel level, not per-chip context menu. |
| AirDrop sheet integration | ✅ | Matches. |
| Pipelines (custom drop actions running terminal commands) | ❌ | NotchNook itself hasn't shipped this yet. Out of scope for Notchy. |
| AirPods burst on connect (L/R/Case battery) | ❓ | Notchy ships this; **NotchNook does not**. Notchy leads. |
| AirPods icon recognition in volume HUD | ❌ | Notchy has no HUD replacement. |
| Volume / brightness HUD replacement | ❌ | Major NotchNook differentiator since v1.2. Notchy v2 does not include. **Strong candidate for v3.** |
| Lock indicator | ❌ | NotchNook v1.2 feature. |
| Calendar widget | ⚠ | Notchy v2 plans it (F5). |
| Mirror (camera preview) widget | ❌ | Out of scope. |
| Shortcuts widget | ❌ | Out of scope. |
| Notes widget | ❌ | NotchNook v1.4. Out of scope. |
| Custom GIF widget | ❌ | NotchNook v1.4.4. Out of scope. |
| Timer / Pomodoro | ❓ | Notchy v2 ships (F6); **NotchNook does not have one**. Notchy leads. |
| System gauge pill (CPU + battery on right edge) | ❓ | Notchy v2 ships (F7); **NotchNook does not**. Notchy leads. |
| Tab switcher between active features | ❓ | Notchy v2 ships (F4); NotchNook scrolls/paginates widgets instead. Different design. |
| Multi-monitor support | ⚠ | Notchy attaches to the notched screen only and explicitly does not paint a fake notch on notchless externals (documented divergence). |
| Notchless-Mac simulated handler | ❓ | Notchy explicit non-goal; NotchNook ships this. |
| Per-Space widget configurations | ❌ | NotchNook feature. Out of v2 scope. |
| Settings: activation gesture, padding, transparency, HUD replacement, live-activity toggle | ❌ | Notchy Settings currently has only launch-at-login + hint-pill. Large parity gap. |
| Settings: menu-bar management | ❌ | Out of scope. |
| Localization (29 languages) | ❌ | Notchy is English-only by design (non-goal). |
| Distribution: Setapp / lo.cafe direct | ❓ | Notchy is private install only. |
| App Store | ❌ for both | Same reason (private `MediaRemote`). |
| Apple Silicon + Intel support | ❓ | NotchNook supports both; Notchy is Apple Silicon only (deliberate). |
| Performance: <1% idle CPU | ✅ | Notchy v1 acceptance criterion already in place; better than current NotchNook 1.5.x regressions. |

## Prioritized "next 5 things Notchy should fix/add to match NotchNook better"

1. **Idle flanking live-activity strip when media plays.** NotchNook's
   signature visual. Today Notchy shows nothing until you hover; users will
   perceive Notchy as "off" by comparison. Implementation: extend `NotchState`
   with an `.idleWithMediaHint` mini-state, render album-art + a 1pt waveform
   to either side of the physical notch. ETA: 1 sprint. **Priority: P1.**

2. **Configurable activation gesture (Settings: hover | click | swipe).**
   This is a top NotchNook customization and removes the biggest "feels
   intrusive" complaint from users who prefer click-only. Implementation:
   add `ActivationMode` enum, gate `HotZoneMonitor` event handler on it.
   ETA: 1-2 days. **Priority: P1.**

3. **Two-finger horizontal swipe in expanded media = prev/next track.** This
   matches NotchNook's documented behavior [S6] and is a delightful gesture
   that ties the nook to muscle memory from iPhone. Implementation:
   `NSEvent.scrollWheel` listener inside `NotchExpandedView` while media
   feature active. ETA: 2 days. **Priority: P1.**

4. **Click larger album artwork → foreground source app ("Windows focus
   restoring").** NotchNook v1.2 ships this; it's the natural "send me to
   the music" affordance. Implementation: `NSRunningApplication.activate(...)`
   on the source bundle ID exposed by `MediaRemoteBridge`. ETA: 1 day.
   **Priority: P1.**

5. **Multi-file keyboard handling in drop tray (Cmd+A, Shift+arrows, arrow
   navigation).** NotchNook v1.5 baseline. Crucial for power users who use
   the tray as a staging area. Implementation: focusable chip grid in
   `DropView`, add keyboard handlers, multi-select drag via
   `NSItemProvider` collection. ETA: 1 sprint. **Priority: P2** (impactful
   for tray-heavy users, but not a "first impression" feature).

### Honorable mentions for v3+ planning

- **HUD replacement for volume/brightness.** Highest-leverage NotchNook
  differentiator we are missing; touches private system overlays, so it's
  more work than the items above. Worth a separate spike.
- **Per-Space widget profiles.** Power-user only; low priority unless we
  build out widget configurability.
- **Notchless-display simulated handler.** Explicit Notchy non-goal today.
  Reopen the decision if user demand emerges.
