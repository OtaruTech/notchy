import AppKit
import SwiftUI

struct NotchExpandedView: View {
    let state: NotchState
    let mediaVM: NowPlayingVM?
    let mediaFeature: MediaFeature
    let audioOutput: AudioOutput?
    let dropFeature: DropFeature
    let onAirDrop: () -> Void
    let onEmail: () -> Void
    let btFeature: BTFeature
    let calendarFeature: CalendarFeature
    let timerFeature: TimerFeature
    let systemMonitor: SystemMonitorFeature
    let mirrorFeature: MirrorFeature
    let lyricsFeature: LyricsFeature
    let systemStatus: SystemStatusFeature
    let clipboardFeature: ClipboardFeature
    let onClipboardPaste: (ClipboardItem) -> Void
    let onClipboardCopy: (ClipboardItem) -> Void
    let onClipboardDismiss: () -> Void
    let hudFeature: HUDFeature
    let availableTabs: [NotchState]
    let onTabSwitch: (NotchState) -> Void

    @AppStorage("notchy.hintEnabled") private var hintEnabled = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                .fill(.black)
                .shadow(
                    color: glowColor.opacity(state.isExpanded ? DesignTokens.glowOpacity : 0),
                    radius: 40, x: 0, y: 12
                )
                .overlay {
                    content
                        // Use LIVE notch height (queried from NSScreen.safeAreaInsets)
                        // — the hardcoded 32pt constant is too short on 14"/16"
                        // MacBook Pros where the hardware notch is ~38pt, leaving
                        // the top row of clipboard cards visually clipped.
                        .padding(.top, ScreenGeometry.liveNotchHeight() + 8)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                        .opacity(state.isExpanded ? 1 : 0)
                }

            if (state == .hint || state == .idle), shouldShowLiveStrip {
                // Live-activity flanking strip whenever a track is loaded
                // (playing OR paused) OR a timer is running.
                VStack(spacing: 6) {
                    LiveActivityStrip(vm: mediaVM, timerState: timerFeature.state)
                    if lyricsEnabled, let mvm = mediaVM, lyricsFeature.hasAny {
                        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                            LyricsTicker(
                                synced: lyricsFeature.lines,
                                plain: lyricsFeature.plainLines,
                                elapsed: mvm.liveElapsed(at: ctx.date),
                                duration: mvm.duration
                            )
                        }
                    }
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            } else if state == .hint, hintEnabled {
                NotchHint().transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            // Tab bar is suppressed for clipboard so cards have the full panel
            // height (clipboard has its own footer hint row).
            if state.isExpanded, state != .clipboard, availableTabs.count >= 2 {
                NotchTabBar(
                    availableTabs: availableTabs,
                    active: state,
                    onSelect: onTabSwitch
                )
                .padding(.bottom, 8)
            }
        }
        .frame(width: width, height: height)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: DesignTokens.cornerRadius,
                bottomTrailingRadius: DesignTokens.cornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    private var width: CGFloat {
        // HUD overlay needs canvas no matter what state we're in.
        if hudFeature.current != nil {
            if state == .clipboard { return DesignTokens.clipboardWidth }
            if state.isExpanded { return DesignTokens.expandedWidth }
            return 360
        }
        if state == .clipboard { return DesignTokens.clipboardWidth }
        if state.isExpanded { return DesignTokens.expandedWidth }
        let actualNotchW = ScreenGeometry.liveNotchWidth()
        let hasMedia = mediaVM != nil
        let hasTimer = timerFeature.state != .idle
        if hasMedia { return actualNotchW + 2 * 70 }
        if hasTimer { return actualNotchW + 70 }
        return state == .hint ? actualNotchW + 8 : actualNotchW
    }

    private var lyricsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "notchy.lyricsEnabled")
    }

    private var shouldShowLiveStrip: Bool {
        if mediaVM != nil { return true }
        if timerFeature.state != .idle { return true }
        return false
    }

    private var height: CGFloat {
        let actualNotchH = ScreenGeometry.liveNotchHeight()
        switch state {
        case .idle, .hint:
            if hudFeature.current != nil { return actualNotchH + 56 }
            let base = actualNotchH + (state == .hint ? 3 : 0)
            if lyricsEnabled, mediaVM != nil, lyricsFeature.hasAny { return base + 34 }
            return base
        case .drop: return DesignTokens.expandedHeightDrop
        case .clipboard: return DesignTokens.clipboardHeight
        default: return DesignTokens.expandedHeightDefault
        }
    }

    private var glowColor: Color {
        switch state {
        case .media: return DesignTokens.glowMedia
        case .drop: return DesignTokens.glowDrop
        case .airpods: return DesignTokens.glowAirPods
        case .calendar: return Color(red: 0.98, green: 0.65, blue: 0.20)
        case .timer: return Color(red: 0.97, green: 0.38, blue: 0.38)
        case .dashboard: return Color(red: 0.55, green: 0.62, blue: 0.85)
        case .mirror: return Color(red: 0.50, green: 0.85, blue: 1.00)
        case .clipboard: return Color(red: 0.78, green: 0.55, blue: 1.00)
        case .hint, .idle: return .clear
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .dashboard:
            DashboardView(
                nextEvent: calendarFeature.events.first,
                snapshot: systemMonitor.snapshot,
                status: systemStatus,
                pomodoro: PomodoroStats(
                    totalToday: timerFeature.log.count(on: Date()),
                    minutesToday: timerFeature.log.minutes(on: Date()),
                    last7: timerFeature.log.dailyCounts(lastDays: 7),
                    streak: timerFeature.log.streak()
                )
            )
        case .media:
            if let vm = mediaVM {
                MediaView(
                    vm: vm,
                    output: audioOutput,
                    onPlayPause: { mediaFeature.playPause() },
                    onPrev: { mediaFeature.prev() },
                    onNext: { mediaFeature.next() },
                    onArtworkTap: {
                        // Bring the source app (Music, Spotify, Safari…) to the front.
                        guard let bid = vm.sourceBundleId,
                              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
                        else { return }
                        let cfg = NSWorkspace.OpenConfiguration()
                        cfg.activates = true
                        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in }
                    }
                )
            } else {
                Text("No media").foregroundStyle(.white.opacity(0.7))
            }
        case .drop:
            DropView(
                items: dropFeature.items,
                onClear: { dropFeature.clearAll() },
                onAirDrop: onAirDrop,
                onEmail: onEmail,
                onRemove: { id in dropFeature.remove(id) }
            )
        case .airpods:
            if let vm = btFeature.connected {
                AirPodsView(vm: vm)
            } else {
                Text("AirPods").foregroundStyle(.white.opacity(0.7))
            }
        case .calendar:
            CalendarView(events: calendarFeature.events) { ev in
                let url = URL(string: "ical://ekevent/\(ev.id)?method=show&options=more")
                if let url { NSWorkspace.shared.open(url) }
            }
        case .timer:
            TimerView(
                state: timerFeature.state,
                progress: timerFeature.progress,
                stats: PomodoroStats(
                    totalToday: timerFeature.log.count(on: Date()),
                    minutesToday: timerFeature.log.minutes(on: Date()),
                    last7: timerFeature.log.dailyCounts(lastDays: 7),
                    streak: timerFeature.log.streak()
                ),
                onStart: { timerFeature.start(seconds: $0) },
                onPause: { timerFeature.pause() },
                onResume: { timerFeature.resume() },
                onReset: { timerFeature.reset() }
            )
        case .mirror:
            MirrorView(feature: mirrorFeature)
        case .clipboard:
            ClipboardPanel(
                feature: clipboardFeature,
                onPaste: onClipboardPaste,
                onCopy: onClipboardCopy,
                onDismiss: onClipboardDismiss
            )
        default: EmptyView()
        }
    }
}
