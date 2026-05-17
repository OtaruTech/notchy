# Contributing to Notchy

Thanks for your interest! Notchy is a young project and contributions of all sizes are welcome.

## Quick start

```bash
git clone https://github.com/OtaruTech/notchy.git
cd notchy
brew install xcodegen          # if you don't have it
xcodegen generate
open Notchy.xcodeproj
# In Xcode press ⌘R
```

## Before you start

- **For bug fixes:** open an issue first so we can confirm the bug, or jump straight to a PR with a reproducer.
- **For features:** open an issue describing the use case first — Notchy aims to stay small and focused.

## Code style

Notchy follows standard Swift 6 conventions with strict concurrency:

- All UI is `@MainActor`. All view models are `@MainActor @Observable`.
- All system access (private APIs, Bluetooth, Calendar, etc.) is wrapped in `actor` bridges.
- A single state machine (`NotchStateMachine`) is the source of truth — push intents, never mutate state from views.
- Each feature lives in `Notchy/Features/<Feature>/` and is independently testable.
- Snapshot tests under `NotchySnapshotTests/` cover every visual component.

## Tests

Every PR should pass:

```bash
xcodebuild -project Notchy.xcodeproj -scheme NotchyTests \
  -destination 'platform=macOS' test

xcodebuild -project Notchy.xcodeproj -scheme NotchySnapshotTests \
  -destination 'platform=macOS' test
```

New features should come with at least:
- A unit test for any pure-Swift logic (state transitions, parsers)
- A snapshot test if the feature has a visible component

## Commit messages

Conventional Commits style preferred:

```
feat(media): bundle media-control inside .app
fix(hover): keep-alive zone grows with state
refactor(ui): extract shared snapshotHost helper
docs: add README screenshots
test(airpods): cover battery parser edge cases
```

## Adding a new feature

The standard pattern is:

1. Add a new case to `NotchState.swift` and `NotchIntent.swift`
2. Add a system bridge actor under `Notchy/System/` if external state is involved
3. Add a feature view model under `Notchy/Features/<Name>/`
4. Add the SwiftUI view next to it
5. Register the new case in `NotchTabBar.swift` (icon, name, glow color)
6. Render the view in `NotchExpandedView.swift`
7. Wire instantiation + observation in `AppDelegate.swift` and `NotchShell.swift`
8. Add unit tests + snapshot tests

## Working on private-API code

The `MediaRemoteBridge` is the only place in the codebase that touches private framework boundaries (via the bundled `media-control` CLI subprocess). If you're adding similar functionality, please:

- Isolate ALL private-API access in a single actor file
- Provide a graceful fallback if the API fails
- Document the workaround clearly

## Debugging

Enable verbose file logging:

```bash
defaults write tech.otaru.Notchy notchy.debugLogging -bool true
tail -f /tmp/notchy.log
```

Disable when done:

```bash
defaults delete tech.otaru.Notchy notchy.debugLogging
```

## License

By contributing you agree that your contributions will be licensed under the MIT License.
