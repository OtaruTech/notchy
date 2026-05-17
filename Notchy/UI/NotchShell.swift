import SwiftUI

struct NotchShell: View {
    let stateMachine: NotchStateMachine
    let mediaFeature: MediaFeature
    let dropFeature: DropFeature
    let onAirDrop: () -> Void
    let onEmail: () -> Void
    let btFeature: BTFeature
    let calendarFeature: CalendarFeature
    let timerFeature: TimerFeature
    let systemMonitor: SystemMonitorFeature
    let mirrorFeature: MirrorFeature
    let audioOutput: AudioOutputBridge
    let lyricsFeature: LyricsFeature
    @AppStorage("notchy.gaugeEnabled") private var gaugeEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            NotchExpandedView(
                state: stateMachine.state,
                mediaVM: mediaFeature.current,
                mediaFeature: mediaFeature,
                audioOutput: audioOutput.current,
                dropFeature: dropFeature,
                onAirDrop: onAirDrop,
                onEmail: onEmail,
                btFeature: btFeature,
                calendarFeature: calendarFeature,
                timerFeature: timerFeature,
                systemMonitor: systemMonitor,
                mirrorFeature: mirrorFeature,
                lyricsFeature: lyricsFeature,
                availableTabs: availableTabs,
                onTabSwitch: { stateMachine.send(.tabSwitchedTo($0)) }
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DesignTokens.springExpand, value: stateMachine.state)
    }

    private var availableTabs: [NotchState] {
        // Dashboard is always available so user can navigate back to it from any
        // expanded feature (e.g. away from Now Playing while music keeps playing).
        var tabs: [NotchState] = [.dashboard]
        if mediaFeature.current != nil { tabs.append(.media) }
        if !dropFeature.items.isEmpty { tabs.append(.drop) }
        if btFeature.connected != nil { tabs.append(.airpods) }
        if !calendarFeature.events.isEmpty { tabs.append(.calendar) }
        if timerFeature.state != .idle { tabs.append(.timer) }
        if mirrorFeature.status == .running { tabs.append(.mirror) }
        return tabs
    }
}
