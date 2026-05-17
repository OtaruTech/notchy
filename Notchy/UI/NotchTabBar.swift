import SwiftUI

struct NotchTabBar: View {
    let availableTabs: [NotchState]
    let active: NotchState
    let onSelect: (NotchState) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(availableTabs, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Image(systemName: icon(for: tab))
                        .font(.system(size: 11))
                        .frame(width: 22, height: 22)
                        .foregroundStyle(tab == active ? glow(for: tab) : .white.opacity(0.35))
                        .background(
                            Circle()
                                .fill(tab == active ? glow(for: tab).opacity(0.18) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help(name(for: tab))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 99)
                .fill(.white.opacity(0.05))
        )
    }

    private func icon(for state: NotchState) -> String {
        switch state {
        case .media: return "music.note"
        case .drop: return "tray.full"
        case .airpods: return "airpods"
        case .calendar: return "calendar"
        case .timer: return "timer"
        case .mirror: return "video.fill"
        case .dashboard: return "square.grid.2x2.fill"
        default: return "questionmark"
        }
    }

    private func name(for state: NotchState) -> String {
        switch state {
        case .media: return "Now Playing"
        case .drop: return "Drop"
        case .airpods: return "AirPods"
        case .calendar: return "Calendar"
        case .timer: return "Timer"
        case .mirror: return "Mirror"
        case .dashboard: return "Dashboard"
        default: return ""
        }
    }

    private func glow(for state: NotchState) -> Color {
        switch state {
        case .media: return DesignTokens.glowMedia
        case .drop: return DesignTokens.glowDrop
        case .airpods: return DesignTokens.glowAirPods
        case .calendar: return Color(red: 0.98, green: 0.65, blue: 0.20)
        case .timer: return Color(red: 0.97, green: 0.38, blue: 0.38)
        case .mirror: return Color(red: 0.50, green: 0.85, blue: 1.00)
        case .dashboard: return Color(red: 0.55, green: 0.62, blue: 0.85)
        default: return .white
        }
    }
}
