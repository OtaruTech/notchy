---
name: Bug report
about: Something isn't working as expected
title: '[bug] '
labels: bug
---

## What happened

<!-- One or two sentences. -->

## What you expected

<!-- One or two sentences. -->

## Steps to reproduce

1.
2.
3.

## Environment

- Notchy version: <!-- e.g. v0.2.0, or commit SHA -->
- macOS version: <!-- e.g. 15.4.1 -->
- MacBook model: <!-- e.g. MacBook Pro 14" M3 -->

## Logs

Enable verbose logging and paste the last ~30 lines:

```bash
defaults write tech.otaru.Notchy notchy.debugLogging -bool true
# reproduce the bug
tail -30 /tmp/notchy.log
defaults delete tech.otaru.Notchy notchy.debugLogging
```

```
<paste here>
```

## Screenshots / screen recording

<!-- If applicable. -->
