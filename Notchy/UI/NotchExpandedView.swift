import AppKit
import SwiftUI

struct NotchExpandedView: View {
    let state: NotchState
    let mediaVM: NowPlayingVM?
    let mediaFeature: MediaFeature
    let dropFeature: DropFeature
    let onAirDrop: () -> Void
    let onEmail: () -> Void
    let btFeature: BTFeature
    let calendarFeature: CalendarFeature
    let timerFeature: TimerFeature
    let systemMonitor: SystemMonitorFeature
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
                        .padding(.top, DesignTokens.notchHeight + 6)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                        .opacity(state.isExpanded ? 1 : 0)
                }

            if state == .hint, hintEnabled {
                NotchHint().transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if state.isExpanded, availableTabs.count >= 2 {
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
        state.isExpanded ? DesignTokens.expandedWidth :
        (state == .hint ? DesignTokens.notchWidth + 8 : DesignTokens.notchWidth)
    }

    private var height: CGFloat {
        switch state {
        case .idle, .hint: return DesignTokens.notchHeight + (state == .hint ? 3 : 0)
        case .drop: return DesignTokens.expandedHeightDrop
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
        case .hint, .idle: return .clear
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .dashboard:
            DashboardView(nextEvent: calendarFeature.events.first, snapshot: systemMonitor.snapshot)
        case .media:
            if let vm = mediaVM {
                MediaView(
                    vm: vm,
                    onPlayPause: { mediaFeature.playPause() },
                    onPrev: { mediaFeature.prev() },
                    onNext: { mediaFeature.next() }
                )
            } else {
                Text("No media").foregroundStyle(.white.opacity(0.7))
            }
        case .drop:
            DropView(
                items: dropFeature.items,
                onClear: { dropFeature.clearAll() },
                onAirDrop: onAirDrop,
                onEmail: onEmail
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
                onStart: { timerFeature.start(seconds: $0) },
                onPause: { timerFeature.pause() },
                onResume: { timerFeature.resume() },
                onReset: { timerFeature.reset() }
            )
        default: EmptyView()
        }
    }
}
