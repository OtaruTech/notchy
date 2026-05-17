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
    @AppStorage("notchy.gaugeEnabled") private var gaugeEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            NotchExpandedView(
                state: stateMachine.state,
                mediaVM: mediaFeature.current,
                mediaFeature: mediaFeature,
                dropFeature: dropFeature,
                onAirDrop: onAirDrop,
                onEmail: onEmail,
                btFeature: btFeature,
                calendarFeature: calendarFeature,
                timerFeature: timerFeature,
                availableTabs: availableTabs,
                onTabSwitch: { stateMachine.send(.tabSwitchedTo($0)) }
            )
            Spacer(minLength: 0)
        }
        .overlay(alignment: .topTrailing) {
            if gaugeEnabled, stateMachine.state == .idle || stateMachine.state == .hint {
                GaugePill(snapshot: systemMonitor.snapshot)
                    .padding(.top, DesignTokens.notchHeight + 4)
                    .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DesignTokens.springExpand, value: stateMachine.state)
    }

    private var availableTabs: [NotchState] {
        var tabs: [NotchState] = []
        if mediaFeature.current != nil { tabs.append(.media) }
        if !dropFeature.items.isEmpty { tabs.append(.drop) }
        if btFeature.connected != nil { tabs.append(.airpods) }
        if !calendarFeature.events.isEmpty { tabs.append(.calendar) }
        if timerFeature.state != .idle { tabs.append(.timer) }
        return tabs
    }
}
