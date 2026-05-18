import SwiftUI

struct TimerView: View {
    let state: TimerFeature.State
    let progress: Double
    var stats: PomodoroStats? = nil
    var onStart: (TimeInterval) -> Void = { _ in }
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}
    var onReset: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        mainRow
        if isIdle, let stats, stats.totalToday > 0 || stats.streak > 0 {
            statsFooter(stats: stats)
        }
        }
    }

    private var mainRow: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.red, .orange],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                Text(timeText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                if isIdle {
                    HStack(spacing: 6) {
                        presetChip("25m", 1500)
                        presetChip("15m", 900)
                        presetChip("5m", 300)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button(isRunning ? "Pause" : "Resume") {
                            isRunning ? onPause() : onResume()
                        }
                        Button("Reset", action: onReset)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.white)
                }
            }
            Spacer()
        }
    }

    private var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    private var timeText: String {
        let secs: TimeInterval
        switch state {
        case .idle: secs = 0
        case .running(let r, _), .paused(let r, _): secs = r
        }
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Footer beneath the timer row showing today's count + 7-day mini heatmap.
    /// Only rendered when the timer is idle (otherwise the user is focused on
    /// the countdown).
    @ViewBuilder
    private func statsFooter(stats: PomodoroStats) -> some View {
        HStack(spacing: 12) {
            statPill(label: "Today", value: "\(stats.totalToday)")
            statPill(label: "Minutes", value: "\(stats.minutesToday)")
            statPill(label: "Streak", value: "\(stats.streak)d")
            Spacer(minLength: 6)
            HStack(spacing: 3) {
                ForEach(stats.last7.indices, id: \.self) { idx in
                    let count = stats.last7[idx]
                    Circle()
                        .fill(heatColor(count: count))
                        .frame(width: 6, height: 6)
                }
            }
            .help("Last 7 days · today on right")
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.6)
        }
    }

    private func heatColor(count: Int) -> Color {
        switch count {
        case 0:    return .white.opacity(0.10)
        case 1...2: return .red.opacity(0.55)
        case 3...4: return .orange
        default:   return .yellow
        }
    }

    @ViewBuilder
    private func presetChip(_ label: String, _ seconds: TimeInterval) -> some View {
        Button {
            onStart(seconds)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
