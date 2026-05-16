# Notchy

A macOS notch utility for Apple-Silicon MacBooks with a hardware notch. Brings Now Playing, file drop tray, and AirPods burst to the notch area.

> **Status:** Early development. See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design and implementation roadmap.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon MacBook with hardware notch
- Xcode 16+
- `xcodegen` (`brew install xcodegen`)

## Build

```bash
xcodegen generate
open Notchy.xcodeproj
# In Xcode: Product → Run (⌘R)
```

## Install (local, free signing)

```bash
xcodegen generate
# Xcode → Product → Archive → Distribute App → Copy App
# Drag Notchy.app to /Applications
# First launch: right-click → Open to bypass Gatekeeper
```

The free Personal Team certificate is valid for about a year. When it expires, re-Archive and replace `/Applications/Notchy.app`.

## License

TBD
